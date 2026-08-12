import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/timetable_repository.dart';

/// Where a timetable coordinator (admin or delegated faculty) uploads the
/// raw data the solver needs: Classrooms (Rooms), Subjects, and Teaching
/// Assignments (who teaches what, to which division). This is the
/// "provision for creating the timetable" — previously this data could
/// only be entered via the backend's /docs page; now it's a real in-app
/// workflow, reachable from the same place as Generate Timetable.
///
/// Divisions (Year/Division setup) are created from GenerateTimetableScreen
/// itself via the Year/Division picker area — kept there since that's
/// where an admin naturally thinks "which Year/Division am I working
/// with," rather than duplicating that concept here.
class ManageTimetableDataScreen extends StatefulWidget {
  const ManageTimetableDataScreen({super.key});

  @override
  State<ManageTimetableDataScreen> createState() => _ManageTimetableDataScreenState();
}

class _ManageTimetableDataScreenState extends State<ManageTimetableDataScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Timetable Data'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Classrooms'),
            Tab(text: 'Subjects'),
            Tab(text: 'Assignments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ClassroomsTab(),
          _SubjectsTab(),
          _AssignmentsTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Classrooms (Rooms)
// ---------------------------------------------------------------------------

class _ClassroomsTab extends StatefulWidget {
  const _ClassroomsTab();

  @override
  State<_ClassroomsTab> createState() => _ClassroomsTabState();
}

class _ClassroomsTabState extends State<_ClassroomsTab> {
  final _repository = TimetableRepository();
  late Future<List<RoomModel>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = _repository.fetchRooms());

  Future<void> _openAddSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _AddRoomSheet(),
    );
    if (added == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _ListOrEmpty<RoomModel>(
        future: _future,
        onRetry: _refresh,
        emptyIcon: Icons.meeting_room_outlined,
        emptyTitle: 'No classrooms yet',
        emptyMessage: 'Tap + to add a lecture room or lab.',
        itemBuilder: (room) => AppCard(
          child: Row(
            children: [
              Icon(room.type == 'lab' ? Icons.science_outlined : Icons.meeting_room_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, style: AppTypography.body),
                    Text('${room.type == 'lab' ? 'Lab' : 'Lecture Room'} · Capacity ${room.capacity}', style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddRoomSheet extends StatefulWidget {
  const _AddRoomSheet();

  @override
  State<_AddRoomSheet> createState() => _AddRoomSheetState();
}

class _AddRoomSheetState extends State<_AddRoomSheet> {
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController(text: '60');
  final _repository = TimetableRepository();
  String _type = 'lecture';
  bool _isSaving = false;

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
      await _repository.createRoom(
        name: name,
        type: _type,
        capacity: int.tryParse(_capacityController.text) ?? 60,
      );
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
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Classroom', style: AppTypography.h3),
            const SizedBox(height: 16),
            TextField(controller: _nameController, autofocus: true, decoration: const InputDecoration(hintText: 'Room name, e.g. Room 301')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'lecture', child: Text('Lecture Room')),
                      DropdownMenuItem(value: 'lab', child: Text('Lab')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'lecture'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Capacity'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Add Classroom', isLoading: _isSaving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subjects
// ---------------------------------------------------------------------------

class _SubjectsTab extends StatefulWidget {
  const _SubjectsTab();

  @override
  State<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<_SubjectsTab> {
  final _repository = TimetableRepository();
  late Future<List<SubjectModel>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = _repository.fetchSubjects());

  Future<void> _openAddSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _AddSubjectSheet(),
    );
    if (added == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _ListOrEmpty<SubjectModel>(
        future: _future,
        onRetry: _refresh,
        emptyIcon: Icons.menu_book_outlined,
        emptyTitle: 'No subjects yet',
        emptyMessage: 'Tap + to add a subject and how many times/week it meets.',
        itemBuilder: (subject) => AppCard(
          child: Row(
            children: [
              const Icon(Icons.menu_book_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name, style: AppTypography.body),
                    Text(
                      [
                        if (subject.weeklyLectures > 0) '${subject.weeklyLectures} lectures/week',
                        if (subject.isLab) '${subject.labSessionsPerWeek} lab session(s)/week',
                      ].join(' · '),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddSubjectSheet extends StatefulWidget {
  const _AddSubjectSheet();

  @override
  State<_AddSubjectSheet> createState() => _AddSubjectSheetState();
}

class _AddSubjectSheetState extends State<_AddSubjectSheet> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _weeklyLecturesController = TextEditingController(text: '3');
  final _repository = TimetableRepository();
  bool _isLab = false;
  int _labSessions = 1;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _weeklyLecturesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _repository.createSubject(
        name: name,
        code: _codeController.text.trim(),
        weeklyLectures: int.tryParse(_weeklyLecturesController.text) ?? 0,
        isLab: _isLab,
        labSessionsPerWeek: _isLab ? _labSessions : 0,
      );
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
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Subject', style: AppTypography.h3),
            const SizedBox(height: 16),
            TextField(controller: _nameController, autofocus: true, decoration: const InputDecoration(hintText: 'Subject name, e.g. DAA')),
            const SizedBox(height: 12),
            TextField(controller: _codeController, decoration: const InputDecoration(hintText: 'Code, e.g. CS301 (optional)')),
            const SizedBox(height: 12),
            TextField(
              controller: _weeklyLecturesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Lectures per week'),
            ),
            const SizedBox(height: 4),
            Text(
              'Each lecture is automatically spread across a different day — '
              'the solver will never stack multiple sessions of the same '
              'subject on one day.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Has a lab component', style: AppTypography.body),
              value: _isLab,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setState(() => _isLab = v),
            ),
            if (_isLab)
              Row(
                children: [
                  Text('Lab sessions/week:', style: AppTypography.bodySecondary),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _labSessions,
                    items: const [1, 2].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                    onChanged: (v) => setState(() => _labSessions = v ?? 1),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Add Subject', isLoading: _isSaving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Assignments (who teaches what, to which division)
// ---------------------------------------------------------------------------

class _AssignmentsTab extends StatefulWidget {
  const _AssignmentsTab();

  @override
  State<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<_AssignmentsTab> {
  final _repository = TimetableRepository();

  late Future<(List<FacultyOption>, List<SubjectModel>, List<DivisionModel>)> _future;

  FacultyOption? _selectedFaculty;
  SubjectModel? _selectedSubject;
  DivisionModel? _selectedDivision;
  bool _isSaving = false;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  void _loadOptions() {
    setState(() {
      _future = _loadAll();
    });
  }

  Future<(List<FacultyOption>, List<SubjectModel>, List<DivisionModel>)> _loadAll() async {
    final faculty = await _repository.fetchFacultyList();
    final subjects = await _repository.fetchSubjects();
    final divisions = await _repository.fetchDivisions();
    return (faculty, subjects, divisions);
  }

  Future<void> _save() async {
    if (_selectedFaculty == null || _selectedSubject == null || _selectedDivision == null) return;

    setState(() {
      _isSaving = true;
      _successMessage = null;
    });
    try {
      await _repository.createAssignment(
        facultyId: _selectedFaculty!.id,
        subjectId: _selectedSubject!.id,
        divisionId: _selectedDivision!.id,
      );
      if (!mounted) return;
      setState(() {
        _successMessage = '${_selectedFaculty!.fullName} is now assigned to teach '
            '${_selectedSubject!.name} for ${_selectedDivision!.displayLabel}.';
      });
    } on TimetableException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<FacultyOption>, List<SubjectModel>, List<DivisionModel>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final message = snapshot.error is TimetableException
              ? (snapshot.error as TimetableException).message
              : 'Something went wrong.';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, style: AppTypography.bodySecondary, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _loadOptions, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final (faculty, subjects, divisions) = snapshot.data!;

        if (faculty.isEmpty || subjects.isEmpty || divisions.isEmpty) {
          return EmptyState(
            icon: Icons.link_outlined,
            title: 'Add subjects and classrooms first',
            message: 'You need at least one subject and one division set up '
                'before creating assignments.'
                '${divisions.isEmpty ? ' Add a division from the Generate Timetable screen.' : ''}',
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign a faculty member to teach a subject for a division.',
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<FacultyOption>(
                value: _selectedFaculty,
                decoration: const InputDecoration(labelText: 'Faculty'),
                items: faculty.map((f) => DropdownMenuItem(value: f, child: Text(f.fullName))).toList(),
                onChanged: (v) => setState(() => _selectedFaculty = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SubjectModel>(
                value: _selectedSubject,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() => _selectedSubject = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DivisionModel>(
                value: _selectedDivision,
                decoration: const InputDecoration(labelText: 'Division'),
                items: divisions.map((d) => DropdownMenuItem(value: d, child: Text(d.displayLabel))).toList(),
                onChanged: (v) => setState(() => _selectedDivision = v),
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Create Assignment', isLoading: _isSaving, onPressed: _save),
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_successMessage!, style: AppTypography.bodySecondary)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared list/empty/error state widget
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
              : 'Something went wrong.';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, style: AppTypography.bodySecondary, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
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
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => itemBuilder(items[index]),
          ),
        );
      },
    );
  }
}
