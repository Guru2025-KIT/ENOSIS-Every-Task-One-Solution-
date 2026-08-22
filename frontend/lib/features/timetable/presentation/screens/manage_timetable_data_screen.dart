import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/timetable_repository.dart';

/// Manage Timetable Data Screen
/// Allows managing:
/// 1. Classrooms / Labs (Add, Edit, Delete)
/// 2. Courses / Subjects (Theory, Lab, Tutorial, Weekly hours, Edit, Delete)
/// 3. Divisions / Batches (Add, Edit, Delete)
/// 4. Faculty Mappings / Assignments (Faculty -> Subject -> Division, List, Delete)
class ManageTimetableDataScreen extends StatefulWidget {
  const ManageTimetableDataScreen({super.key});

  @override
  State<ManageTimetableDataScreen> createState() => _ManageTimetableDataScreenState();
}

class _ManageTimetableDataScreenState extends State<ManageTimetableDataScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repository = TimetableRepository();
  bool _isLoading = false;

  final _classroomsKey = GlobalKey<ClassroomsTabState>();
  final _subjectsKey = GlobalKey<SubjectsTabState>();
  final _divisionsKey = GlobalKey<DivisionsTabState>();
  final _assignmentsKey = GlobalKey<AssignmentsTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _importExcelTemplate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() => _isLoading = true);

        final response = await _repository.uploadExcel(
          filePath: file.path,
          fileBytes: file.bytes,
          fileName: file.name,
        );

        // Refresh all tabs
        _classroomsKey.currentState?._refresh();
        _subjectsKey.currentState?._refresh();
        _divisionsKey.currentState?._refresh();
        _assignmentsKey.currentState?._loadAll();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel imported: ${response['divisions_created'] ?? 0} divisions, ${response['fixed_courses_created'] ?? 0} fixed courses, ${response['shared_courses_created'] ?? 0} shared courses created!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excel Upload Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Courses & Faculty Mappings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.white),
            tooltip: 'Import Excel Template',
            onPressed: _isLoading ? null : _importExcelTemplate,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.secondary,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.meeting_room_outlined, size: 18), text: 'Classrooms'),
            Tab(icon: Icon(Icons.menu_book_outlined, size: 18), text: 'Courses / Subjects'),
            Tab(icon: Icon(Icons.groups_outlined, size: 18), text: 'Divisions / Batches'),
            Tab(icon: Icon(Icons.assignment_ind_outlined, size: 18), text: 'Faculty Mappings'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              ClassroomsTab(key: _classroomsKey),
              SubjectsTab(key: _subjectsKey),
              DivisionsTab(key: _divisionsKey),
              AssignmentsTab(key: _assignmentsKey),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Classrooms (Rooms) Tab
// ---------------------------------------------------------------------------

class ClassroomsTab extends StatefulWidget {
  const ClassroomsTab({super.key});

  @override
  State<ClassroomsTab> createState() => ClassroomsTabState();
}

class ClassroomsTabState extends State<ClassroomsTab> {
  final _repository = TimetableRepository();
  late Future<List<RoomModel>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = _repository.fetchRooms();
    });
  }

  Future<void> _openAddOrEditSheet({RoomModel? existingRoom}) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _RoomFormSheet(existingRoom: existingRoom),
    );
    if (updated == true) _refresh();
  }

  Future<void> _deleteRoom(RoomModel room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Classroom'),
        content: Text('Are you sure you want to delete ${room.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteRoom(room.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${room.name} deleted.')));
          _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting room: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEditSheet(),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Classroom'),
      ),
      body: _ListOrEmpty<RoomModel>(
        future: _future,
        onRetry: _refresh,
        emptyIcon: Icons.meeting_room_outlined,
        emptyTitle: 'No classrooms configured',
        emptyMessage: 'Tap "Add Classroom" or upload an Excel sheet to register lecture halls or laboratories.',
        itemBuilder: (room) => AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: room.type == 'lab' ? Colors.purple.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  room.type == 'lab' ? Icons.science_outlined : Icons.meeting_room_outlined,
                  color: room.type == 'lab' ? Colors.purple : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            room.type.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Capacity: ${room.capacity} students', style: AppTypography.caption),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                tooltip: 'Edit',
                onPressed: () => _openAddOrEditSheet(existingRoom: room),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                tooltip: 'Delete',
                onPressed: () => _deleteRoom(room),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomFormSheet extends StatefulWidget {
  final RoomModel? existingRoom;
  const _RoomFormSheet({this.existingRoom});

  @override
  State<_RoomFormSheet> createState() => _RoomFormSheetState();
}

class _RoomFormSheetState extends State<_RoomFormSheet> {
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController(text: '60');
  final _repository = TimetableRepository();
  String _type = 'lecture';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingRoom != null) {
      _nameController.text = widget.existingRoom!.name;
      _capacityController.text = widget.existingRoom!.capacity.toString();
      _type = widget.existingRoom!.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      if (widget.existingRoom != null) {
        await _repository.updateRoom(
          widget.existingRoom!.id,
          name: name,
          type: _type,
          capacity: int.tryParse(_capacityController.text) ?? 60,
        );
      } else {
        await _repository.createRoom(
          name: name,
          type: _type,
          capacity: int.tryParse(_capacityController.text) ?? 60,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TimetableException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRoom != null;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(isEditing ? Icons.edit : Icons.add_business, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(isEditing ? 'Edit Classroom' : 'Add Classroom / Lab', style: AppTypography.h3),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: !isEditing,
              decoration: const InputDecoration(labelText: 'Room Name / Number', hintText: 'e.g. Room 204 or CC Lab 2'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Room Type'),
                    items: const [
                      DropdownMenuItem(value: 'lecture', child: Text('Classroom / Lecture')),
                      DropdownMenuItem(value: 'lab', child: Text('Computer Lab / Laboratory')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'lecture'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Capacity (Seats)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: isEditing ? 'Save Changes' : 'Create Classroom',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Courses / Subjects Tab
// ---------------------------------------------------------------------------

class SubjectsTab extends StatefulWidget {
  const SubjectsTab({super.key});

  @override
  State<SubjectsTab> createState() => SubjectsTabState();
}

class SubjectsTabState extends State<SubjectsTab> {
  final _repository = TimetableRepository();
  late Future<List<SubjectModel>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = _repository.fetchSubjects();
    });
  }

  Future<void> _openAddOrEditSheet({SubjectModel? existingSubject}) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SubjectFormSheet(existingSubject: existingSubject),
    );
    if (updated == true) _refresh();
  }

  Future<void> _deleteSubject(SubjectModel subject) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course / Subject'),
        content: Text('Are you sure you want to delete ${subject.name}? This will remove its faculty mappings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteSubject(subject.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${subject.name} deleted.')));
          _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting subject: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEditSheet(),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Course / Subject'),
      ),
      body: _ListOrEmpty<SubjectModel>(
        future: _future,
        onRetry: _refresh,
        emptyIcon: Icons.menu_book_outlined,
        emptyTitle: 'No subjects configured',
        emptyMessage: 'Tap "Add Course / Subject" or upload an Excel sheet to configure courses, lecture counts, and practicals.',
        itemBuilder: (subject) {
          final isLab = subject.isLab;
          final isTheory = subject.weeklyLectures > 0;
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isLab ? Colors.orange.shade50 : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isLab ? Icons.biotech_outlined : Icons.menu_book_outlined,
                    color: isLab ? Colors.deepOrange : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(subject.name, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                          if (subject.code != null && subject.code!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                subject.code!,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (isTheory)
                            _Badge(
                              label: '${subject.weeklyLectures} Theory lecs/wk',
                              color: Colors.blue,
                            ),
                          if (isLab)
                            _Badge(
                              label: '${subject.labSessionsPerWeek} Lab sessions/wk (${subject.labBlockSize} hrs each)',
                              color: Colors.deepOrange,
                            ),
                          if (!isTheory && !isLab)
                            const _Badge(label: 'Tutorial / Seminar', color: Colors.teal),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                  tooltip: 'Edit',
                  onPressed: () => _openAddOrEditSheet(existingSubject: subject),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  tooltip: 'Delete',
                  onPressed: () => _deleteSubject(subject),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final MaterialColor color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade200),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.shade800)),
    );
  }
}

class _SubjectFormSheet extends StatefulWidget {
  final SubjectModel? existingSubject;
  const _SubjectFormSheet({this.existingSubject});

  @override
  State<_SubjectFormSheet> createState() => _SubjectFormSheetState();
}

class _SubjectFormSheetState extends State<_SubjectFormSheet> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _weeklyLecturesController = TextEditingController(text: '3');
  final _labSessionsController = TextEditingController(text: '1');
  final _labBlockSizeController = TextEditingController(text: '2');
  final _repository = TimetableRepository();
  bool _isLab = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingSubject != null) {
      final s = widget.existingSubject!;
      _nameController.text = s.name;
      _codeController.text = s.code ?? '';
      _weeklyLecturesController.text = s.weeklyLectures.toString();
      _isLab = s.isLab;
      _labSessionsController.text = s.labSessionsPerWeek.toString();
      _labBlockSizeController.text = s.labBlockSize.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _weeklyLecturesController.dispose();
    _labSessionsController.dispose();
    _labBlockSizeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final code = _codeController.text.trim();
      final weekly = int.tryParse(_weeklyLecturesController.text) ?? 0;
      final labSessions = int.tryParse(_labSessionsController.text) ?? 0;
      final labBlockSize = int.tryParse(_labBlockSizeController.text) ?? 2;

      if (widget.existingSubject != null) {
        await _repository.updateSubject(
          widget.existingSubject!.id,
          name: name,
          code: code.isEmpty ? null : code,
          weeklyLectures: weekly,
          isLab: _isLab,
          labSessionsPerWeek: _isLab ? labSessions : 0,
          labBlockSize: labBlockSize,
        );
      } else {
        await _repository.createSubject(
          name: name,
          code: code.isEmpty ? null : code,
          weeklyLectures: weekly,
          isLab: _isLab,
          labSessionsPerWeek: _isLab ? labSessions : 0,
          labBlockSize: labBlockSize,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TimetableException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSubject != null;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(isEditing ? Icons.edit_note : Icons.add_box, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(isEditing ? 'Edit Subject' : 'Add New Subject', style: AppTypography.h3),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: !isEditing,
              decoration: const InputDecoration(labelText: 'Subject Name', hintText: 'e.g. Database Management Systems'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Course Code (Optional)', hintText: 'e.g. CS301'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weeklyLecturesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Theory Lectures per Week',
                helperText: 'Number of 1-period theory classes spread across the week',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Includes Practical / Lab Component', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Requires continuous periods in a dedicated laboratory'),
              value: _isLab,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _isLab = v),
            ),
            if (_isLab) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _labSessionsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Lab Sessions / Week'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _labBlockSizeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Continuous Hours (Block Size)'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: isEditing ? 'Save Changes' : 'Add Subject',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Divisions / Batches Tab
// ---------------------------------------------------------------------------

class DivisionsTab extends StatefulWidget {
  const DivisionsTab({super.key});

  @override
  State<DivisionsTab> createState() => DivisionsTabState();
}

class DivisionsTabState extends State<DivisionsTab> {
  final _repository = TimetableRepository();
  late Future<List<DivisionModel>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = _repository.fetchDivisions();
    });
  }

  Future<void> _openAddOrEditSheet({DivisionModel? existingDivision}) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _DivisionFormSheet(existingDivision: existingDivision),
    );
    if (updated == true) _refresh();
  }

  Future<void> _deleteDivision(DivisionModel division) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Division'),
        content: Text('Are you sure you want to delete ${division.displayLabel}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteDivision(division.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${division.name} deleted.')));
          _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting division: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEditSheet(),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Division'),
      ),
      body: _ListOrEmpty<DivisionModel>(
        future: _future,
        onRetry: _refresh,
        emptyIcon: Icons.groups_outlined,
        emptyTitle: 'No divisions configured',
        emptyMessage: 'Tap "Add Division" or upload an Excel sheet to set up academic sections (e.g. Year 2 - Div A).',
        itemBuilder: (division) => AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.groups_outlined, color: Colors.teal, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(division.name, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      'Year ${division.year} · Division ${division.divisionCode} · Strength: ${division.strength} students',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                tooltip: 'Edit',
                onPressed: () => _openAddOrEditSheet(existingDivision: division),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                tooltip: 'Delete',
                onPressed: () => _deleteDivision(division),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DivisionFormSheet extends StatefulWidget {
  final DivisionModel? existingDivision;
  const _DivisionFormSheet({this.existingDivision});

  @override
  State<_DivisionFormSheet> createState() => _DivisionFormSheetState();
}

class _DivisionFormSheetState extends State<_DivisionFormSheet> {
  final _nameController = TextEditingController();
  final _divCodeController = TextEditingController(text: 'A');
  final _strengthController = TextEditingController(text: '60');
  int _year = 2;
  final _repository = TimetableRepository();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingDivision != null) {
      final d = widget.existingDivision!;
      _nameController.text = d.name;
      _divCodeController.text = d.divisionCode;
      _strengthController.text = d.strength.toString();
      _year = d.year;
    } else {
      _nameController.text = 'SY CSE - Div A';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _divCodeController.dispose();
    _strengthController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final divCode = _divCodeController.text.trim().toUpperCase();
    if (name.isEmpty || divCode.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final strength = int.tryParse(_strengthController.text) ?? 60;
      if (widget.existingDivision != null) {
        await _repository.updateDivision(
          widget.existingDivision!.id,
          name: name,
          year: _year,
          divisionCode: divCode,
          strength: strength,
        );
      } else {
        await _repository.createDivision(
          name: name,
          year: _year,
          divisionCode: divCode,
          strength: strength,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TimetableException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingDivision != null;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(isEditing ? Icons.edit : Icons.group_add, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(isEditing ? 'Edit Division' : 'Add New Division', style: AppTypography.h3),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Display Name', hintText: 'e.g. SY-CSE Div A'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _year,
                    decoration: const InputDecoration(labelText: 'Academic Year'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Year 1 (FE)')),
                      DropdownMenuItem(value: 2, child: Text('Year 2 (SE)')),
                      DropdownMenuItem(value: 3, child: Text('Year 3 (TE)')),
                      DropdownMenuItem(value: 4, child: Text('Year 4 (BE)')),
                    ],
                    onChanged: (v) => setState(() {
                      _year = v ?? 2;
                      if (!isEditing) {
                        final yName = ['FE', 'SE', 'TE', 'BE'][_year - 1];
                        _nameController.text = '$yName CSE - Div ${_divCodeController.text}';
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _divCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Division Code', hintText: 'A, B, C...'),
                    onChanged: (val) {
                      if (!isEditing && val.isNotEmpty) {
                        final yName = ['FE', 'SE', 'TE', 'BE'][_year - 1];
                        _nameController.text = '$yName CSE - Div ${val.toUpperCase()}';
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _strengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Class Strength (Students)'),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: isEditing ? 'Save Changes' : 'Create Division',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Faculty Mappings (Assignments) Tab
// ---------------------------------------------------------------------------

class AssignmentsTab extends StatefulWidget {
  const AssignmentsTab({super.key});

  @override
  State<AssignmentsTab> createState() => AssignmentsTabState();
}

class AssignmentsTabState extends State<AssignmentsTab> {
  final _repository = TimetableRepository();

  List<FacultyOption> _facultyList = [];
  List<SubjectModel> _subjectList = [];
  List<DivisionModel> _divisionList = [];
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;

  String? _selectedFacultyId;
  String? _selectedSubjectId;
  String? _selectedDivisionId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final faculty = await _repository.fetchFacultyList();
      final subjects = await _repository.fetchSubjects();
      final divisions = await _repository.fetchDivisions();
      final assigns = await _repository.fetchAssignmentsDetailed();

      if (mounted) {
        setState(() {
          _facultyList = faculty;
          _subjectList = subjects;
          _divisionList = divisions;
          _assignments = assigns;
          _isLoading = false;

          // Clear selection IDs if they are no longer in the updated items lists
          if (_selectedFacultyId != null && !faculty.any((f) => f.id == _selectedFacultyId)) {
            _selectedFacultyId = null;
          }
          if (_selectedSubjectId != null && !subjects.any((s) => s.id == _selectedSubjectId)) {
            _selectedSubjectId = null;
          }
          if (_selectedDivisionId != null && !divisions.any((d) => d.id == _selectedDivisionId)) {
            _selectedDivisionId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading mappings: $e')),
        );
      }
    }
  }

  Future<void> _createAssignment() async {
    if (_selectedFacultyId == null || _selectedSubjectId == null || _selectedDivisionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Faculty, Subject, and Division.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _repository.createAssignment(
        facultyId: _selectedFacultyId!,
        subjectId: _selectedSubjectId!,
        divisionId: _selectedDivisionId!,
      );
      if (mounted) {
        final fac = _facultyList.firstWhere((f) => f.id == _selectedFacultyId);
        final sub = _subjectList.firstWhere((s) => s.id == _selectedSubjectId);
        final div = _divisionList.firstWhere((d) => d.id == _selectedDivisionId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${fac.fullName} assigned to ${sub.name} (${div.displayLabel})'),
          ),
        );
        _loadAll();
      }
    } on TimetableException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAssignment(String assignmentId, String facultyName, String subjectName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Mapping'),
        content: Text('Remove assignment of $facultyName for $subjectName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteAssignment(assignmentId);
        _loadAll();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing mapping: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mapping Creator Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.link, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Create Faculty → Course Mapping', style: AppTypography.h3),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Link who teaches which course to which division. The CP-SAT solver uses this to avoid scheduling overlapping faculty sessions.',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedFacultyId,
                  decoration: const InputDecoration(labelText: 'Faculty Member'),
                  items: _facultyList.map((f) => DropdownMenuItem(value: f.id, child: Text(f.fullName))).toList(),
                  onChanged: (v) => setState(() => _selectedFacultyId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSubjectId,
                        decoration: const InputDecoration(labelText: 'Course / Subject'),
                        items: _subjectList.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                        onChanged: (v) => setState(() => _selectedSubjectId = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDivisionId,
                        decoration: const InputDecoration(labelText: 'Target Division'),
                        items: _divisionList.map((d) => DropdownMenuItem(value: d.id, child: Text(d.displayLabel))).toList(),
                        onChanged: (v) => setState(() => _selectedDivisionId = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Link Faculty to Subject',
                  isLoading: _isSaving,
                  onPressed: _createAssignment,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Existing Mappings List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current Teaching Mappings (${_assignments.length})', style: AppTypography.h3),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadAll,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_assignments.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.assignment_late_outlined, size: 36, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text('No faculty mappings created yet.', style: AppTypography.bodySecondary),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _assignments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final a = _assignments[index];
                final id = a['id'] as String;
                final facName = a['faculty_name'] as String? ?? 'Faculty';
                final subName = a['subject_name'] as String? ?? 'Subject';
                final divName = a['division_name'] as String? ?? 'Division';

                return AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          facName.isNotEmpty ? facName[0].toUpperCase() : 'F',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(facName, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('$subName · $divName', style: AppTypography.caption),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: 'Remove mapping',
                        onPressed: () => _deleteAssignment(id, facName, subName),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared list / empty helper widget
// ---------------------------------------------------------------------------

class _ListOrEmpty<T> extends StatelessWidget {
  final Future<List<T>> future;
  final VoidCallback onRetry;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final Widget Function(T item) itemBuilder;

  const _ListOrEmpty({
    required this.future,
    required this.onRetry,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final message = snapshot.error is TimetableException
              ? (snapshot.error as TimetableException).message
              : 'Failed to connect to backend service.';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(message, style: AppTypography.bodySecondary, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return EmptyState(icon: emptyIcon, title: emptyTitle, message: emptyMessage);
        }

        return RefreshIndicator(
          onRefresh: () async => onRetry(),
          child: ListView.separated(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => itemBuilder(items[index]),
          ),
        );
      },
    );
  }
}
