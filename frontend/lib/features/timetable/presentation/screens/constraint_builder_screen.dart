import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/auth/auth_session.dart';
import '../../data/constraint_repository.dart';
import '../../data/timetable_repository.dart';

class ConstraintBuilderScreen extends StatefulWidget {
  const ConstraintBuilderScreen({super.key});

  @override
  State<ConstraintBuilderScreen> createState() => _ConstraintBuilderScreenState();
}

class _ConstraintBuilderScreenState extends State<ConstraintBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _timetableRepository = TimetableRepository();
  final _constraintRepository = ConstraintRepository();

  // Selected constraint type key mapping to solver constraint types
  String _selectedType = 'faculty_unavailability';

  // Selection states
  FacultyOption? _selectedFaculty;
  RoomModel? _selectedRoom;
  DivisionModel? _selectedDivision;
  SubjectModel? _selectedSubject;

  int _selectedDay = 0; // Mon = 0
  int _selectedSlot = 0; // Slot 1 = 0
  String _priority = 'hard'; // 'hard' or 'soft'

  // Lists populated from database
  List<FacultyOption> _facultyList = [];
  List<RoomModel> _roomList = [];
  List<DivisionModel> _divisionList = [];
  List<SubjectModel> _subjectList = [];

  bool _isLoading = false;
  bool _isSaving = false;
  final _noteController = TextEditingController();

  final List<String> _dayLabels = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _loadAllDropdownData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAllDropdownData() async {
    setState(() => _isLoading = true);
    try {
      final facs = await _timetableRepository.fetchFacultyList();
      final rooms = await _timetableRepository.fetchRooms();
      final divs = await _timetableRepository.fetchDivisions();
      final subs = await _timetableRepository.fetchSubjects();

      if (mounted) {
        setState(() {
          _facultyList = facs;
          if (facs.isNotEmpty) {
            _selectedFaculty = facs.first;
            // If user is a faculty but not admin/hod, lock selection to themselves
            if (!AuthSession.canAccessTimetableGeneration) {
              final loggedName = AuthSession.fullName ?? '';
              final match = facs.cast<FacultyOption?>().firstWhere(
                (f) => f != null && f.fullName.toLowerCase() == loggedName.toLowerCase(),
                orElse: () => null,
              );
              if (match != null) {
                _selectedFaculty = match;
              }
            }
          }

          _roomList = rooms;
          if (rooms.isNotEmpty) _selectedRoom = rooms.first;

          _divisionList = divs;
          if (divs.isNotEmpty) _selectedDivision = divs.first;

          _subjectList = subs;
          if (subs.isNotEmpty) _selectedSubject = subs.first;
        });
      }
    } catch (e) {
      _showError('Failed to load configuration dropdowns: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedType = 'faculty_unavailability';
      _priority = 'hard';
      if (_facultyList.isNotEmpty) _selectedFaculty = _facultyList.first;
      if (_roomList.isNotEmpty) _selectedRoom = _roomList.first;
      if (_divisionList.isNotEmpty) _selectedDivision = _divisionList.first;
      if (_subjectList.isNotEmpty) _selectedSubject = _subjectList.first;
      _selectedDay = 0;
      _selectedSlot = 0;
      _noteController.clear();
    });
  }

  Future<void> _saveConstraint() async {
    if (!_formKey.currentState!.validate()) return;

    Map<String, dynamic> payload = {};
    String description = '';

    // Dynamically build payload + priority + description based on constraint type
    switch (_selectedType) {
      case 'faculty_unavailability':
        if (_selectedFaculty == null) return _showError('Please select a faculty member.');
        _priority = 'hard';
        payload = {
          'faculty_id': _selectedFaculty!.id,
          'day': _selectedDay,
          'slot': _selectedSlot,
        };
        description = 'Hard Unavailability: ${_selectedFaculty!.fullName} unavailable on ${_dayLabels[_selectedDay]} Slot ${_selectedSlot + 1}';
        break;

      case 'avoid_first_period':
        if (_selectedFaculty == null) return _showError('Please select a faculty member.');
        _priority = 'soft';
        payload = {'faculty_id': _selectedFaculty!.id};
        description = 'Soft Preference: Avoid Slot 1 for ${_selectedFaculty!.fullName}';
        break;

      case 'avoid_last_period':
        if (_selectedFaculty == null) return _showError('Please select a faculty member.');
        _priority = 'soft';
        payload = {'faculty_id': _selectedFaculty!.id};
        description = 'Soft Preference: Avoid last slot for ${_selectedFaculty!.fullName}';
        break;

      case 'prefer_morning':
        if (_selectedFaculty == null) return _showError('Please select a faculty member.');
        _priority = 'soft';
        payload = {'faculty_id': _selectedFaculty!.id};
        description = 'Soft Preference: Prefer morning sessions for ${_selectedFaculty!.fullName}';
        break;

      case 'preferred_room':
        if (_selectedSubject == null || _selectedRoom == null) {
          return _showError('Please select both a subject and preferred room.');
        }
        _priority = 'soft';
        payload = {
          'subject_id': _selectedSubject!.id,
          'room_id': _selectedRoom!.id,
        };
        description = 'Soft Preference: Prefer room ${_selectedRoom!.name} for subject ${_selectedSubject!.name}';
        break;

      case 'preferred_slot':
        if (_selectedSubject == null) return _showError('Please select a subject.');
        _priority = 'soft';
        payload = {
          'subject_id': _selectedSubject!.id,
          'day': _selectedDay,
          'slot': _selectedSlot,
        };
        description = 'Soft Preference: Prefer ${_selectedSubject!.name} on ${_dayLabels[_selectedDay]} Slot ${_selectedSlot + 1}';
        break;

      case 'avoid_consecutive_same':
        if (_selectedDivision == null || _selectedSubject == null) {
          return _showError('Please select both a division and subject.');
        }
        _priority = 'soft';
        payload = {
          'division_id': _selectedDivision!.id,
          'subject_id': _selectedSubject!.id,
        };
        description = 'Soft Preference: Avoid back-to-back lectures of ${_selectedSubject!.name} for division ${_selectedDivision!.name}';
        break;
    }

    // Append user note if present
    final note = _noteController.text.trim();
    if (note.isNotEmpty) {
      description += ' (Note: $note)';
    }

    setState(() => _isSaving = true);
    try {
      await _constraintRepository.addConstraint(
        type: _selectedType,
        priority: _priority,
        payload: payload,
        description: description,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Constraint saved successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true); // Return true to trigger refresh on previous page
      }
    } catch (e) {
      _showError('Failed to save constraint: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFacultyLocked = !AuthSession.canAccessTimetableGeneration;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Solver Constraint'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: ResponsiveCenter(
                  maxWidth: Responsive.maxContentWidth,
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Configure Solver Rules', style: AppTypography.h2),
                        const SizedBox(height: 6),
                        Text(
                          'Select a constraint type below. Rules are converted directly into Google OR-Tools model parameters.',
                          style: AppTypography.bodySecondary,
                        ),
                        const SizedBox(height: 24),

                        // Constraint Type Selector
                        DropdownButtonFormField<String>(
                          initialValue: _selectedType,
                          decoration: const InputDecoration(labelText: 'Constraint Type'),
                          items: const [
                            DropdownMenuItem(value: 'faculty_unavailability', child: Text('🔴 Faculty Unavailability (Hard)')),
                            DropdownMenuItem(value: 'avoid_first_period', child: Text('🟡 Avoid First Period (Soft)')),
                            DropdownMenuItem(value: 'avoid_last_period', child: Text('🟡 Avoid Last Period (Soft)')),
                            DropdownMenuItem(value: 'prefer_morning', child: Text('🟡 Prefer Morning Slots (Soft)')),
                            DropdownMenuItem(value: 'preferred_room', child: Text('🟢 Preferred Room (Soft)')),
                            DropdownMenuItem(value: 'preferred_slot', child: Text('🟢 Preferred Slot (Soft)')),
                            DropdownMenuItem(value: 'avoid_consecutive_same', child: Text('🟢 Avoid Consecutive Lectures (Soft)')),
                          ],
                          onChanged: (val) => setState(() {
                            _selectedType = val ?? _selectedType;
                          }),
                        ),
                        const SizedBox(height: 20),

                        // ─── DYNAMIC SUB-FIELDS BASED ON CHOSEN TYPE ───────────

                        // Faculty Selector (for faculty_unavailability, avoid_first, avoid_last, prefer_morning)
                        if (_selectedType == 'faculty_unavailability' ||
                            _selectedType == 'avoid_first_period' ||
                            _selectedType == 'avoid_last_period' ||
                            _selectedType == 'prefer_morning') ...[
                          if (isFacultyLocked)
                            InputDecorator(
                              decoration: const InputDecoration(labelText: 'Faculty Member'),
                              child: Text(
                                _selectedFaculty?.fullName ?? AuthSession.fullName ?? '',
                                style: AppTypography.bodyMedium,
                              ),
                            )
                          else
                            DropdownButtonFormField<FacultyOption>(
                              initialValue: _selectedFaculty,
                              decoration: const InputDecoration(labelText: 'Select Faculty'),
                              items: _facultyList
                                  .map((f) => DropdownMenuItem(value: f, child: Text(f.fullName)))
                                  .toList(),
                              onChanged: (val) => setState(() => _selectedFaculty = val),
                            ),
                          const SizedBox(height: 20),
                        ],

                        // Room Selector (for preferred_room)
                        if (_selectedType == 'preferred_room') ...[
                          DropdownButtonFormField<RoomModel>(
                            initialValue: _selectedRoom,
                            decoration: const InputDecoration(labelText: 'Preferred Classroom/Lab'),
                            items: _roomList
                                  .map((r) => DropdownMenuItem(value: r, child: Text('${r.name} (${r.type})')))
                                  .toList(),
                            onChanged: (val) => setState(() => _selectedRoom = val),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Subject Selector (for preferred_room, preferred_slot, avoid_consecutive_same)
                        if (_selectedType == 'preferred_room' ||
                            _selectedType == 'preferred_slot' ||
                            _selectedType == 'avoid_consecutive_same') ...[
                          DropdownButtonFormField<SubjectModel>(
                            initialValue: _selectedSubject,
                            decoration: const InputDecoration(labelText: 'Select Subject'),
                            items: _subjectList
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                                  .toList(),
                            onChanged: (val) => setState(() => _selectedSubject = val),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Division Selector (for avoid_consecutive_same)
                        if (_selectedType == 'avoid_consecutive_same') ...[
                          DropdownButtonFormField<DivisionModel>(
                            initialValue: _selectedDivision,
                            decoration: const InputDecoration(labelText: 'Select Division'),
                            items: _divisionList
                                  .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                                  .toList(),
                            onChanged: (val) => setState(() => _selectedDivision = val),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Day & Slot selectors (for faculty_unavailability, preferred_slot)
                        if (_selectedType == 'faculty_unavailability' ||
                            _selectedType == 'preferred_slot') ...[
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _selectedDay,
                                  decoration: const InputDecoration(labelText: 'Day'),
                                  items: List.generate(_dayLabels.length, (idx) {
                                    return DropdownMenuItem(
                                      value: idx,
                                      child: Text(_dayLabels[idx]),
                                    );
                                  }),
                                  onChanged: (val) => setState(() => _selectedDay = val ?? _selectedDay),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _selectedSlot,
                                  decoration: const InputDecoration(labelText: 'Period Slot'),
                                  items: List.generate(8, (idx) {
                                    return DropdownMenuItem(
                                      value: idx,
                                      child: Text('Period ${idx + 1}'),
                                    );
                                  }),
                                  onChanged: (val) => setState(() => _selectedSlot = val ?? _selectedSlot),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Note text field
                        TextField(
                          controller: _noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Optional Comment / Rationale',
                            hintText: 'e.g. Required due to guest lectures or physical constraints...',
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Actions row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _resetForm,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 52),
                                ),
                                child: const Text('Reset Form'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PrimaryButton(
                                label: 'Save Rule',
                                isLoading: _isSaving,
                                onPressed: _saveConstraint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
