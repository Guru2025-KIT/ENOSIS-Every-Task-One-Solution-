import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../copo/presentation/screens/copo_workbench_screen.dart';
import '../../../timetable/presentation/screens/timetable_hub_screen.dart';
import '../../data/admin_repository.dart';
import '../widgets/faculty_upload_dialog.dart';

// ─── ADMIN DASHBOARD SCREEN ──────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final AdminRepository _repository = AdminRepository();

  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  AdminDashboardStats? _stats;
  List<FacultyModel> _facultyList = [];
  List<SubjectAllocationModel> _subjectAllocations = [];
  List<GovernanceRequestModel> _requests = [];

  // Filters
  String _facultySearchQuery = '';
  String _selectedDeptFilter = 'All';
  String _allocYearFilter = 'S.Y. B.Tech';
  String _allocSemFilter = 'Semester IV';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statsFuture = _repository.getDashboardStats();
      final facultyFuture = _repository.getFacultyList();
      final allocationsFuture = _repository.getSubjectAllocations();
      final requestsFuture = _repository.getGovernanceRequests();

      final results = await Future.wait([
        statsFuture,
        facultyFuture,
        allocationsFuture,
        requestsFuture,
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as AdminDashboardStats;
          _facultyList = results[1] as List<FacultyModel>;
          _subjectAllocations = results[2] as List<SubjectAllocationModel>;
          _requests = results[3] as List<GovernanceRequestModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleRequestAction(String id, bool approve) async {
    try {
      await _repository.processGovernanceAction(
        requestId: id,
        action: approve ? 'APPROVE' : 'REJECT',
      );
      await _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Request approved successfully.' : 'Request rejected.'),
            backgroundColor: approve ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ─── FACULTY UPLOAD DIALOG ─────────────────────────────────────────────────

  void _openUploadFacultyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FacultyUploadDialog(
        onImportSuccess: _loadDashboardData,
      ),
    );
  }

  // ─── FACULTY CRUD ACTIONS ──────────────────────────────────────────────────

  void _openAddFacultyDialog() {
    final nameCtrl = TextEditingController();
    final empCtrl = TextEditingController(text: 'KIT-AIML-1${_facultyList.length + 1}');
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+91 98220 99001');
    String dept = 'CSE (AI & ML)';
    String desig = 'Assistant Professor';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.person_add_alt_1, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('Add New Faculty Member', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Full Name (e.g., Dr. Ramesh Kulkarni)', prefixIcon: Icon(Icons.badge_outlined)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: empCtrl,
                              decoration: const InputDecoration(labelText: 'Employee ID', prefixIcon: Icon(Icons.numbers)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: phoneCtrl,
                              decoration: const InputDecoration(labelText: 'Contact Phone', prefixIcon: Icon(Icons.phone_outlined)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: 'Official Email', prefixIcon: Icon(Icons.email_outlined)),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: dept,
                        decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.apartment)),
                        items: ['CSE (AI & ML)', 'Computer Science', 'Electronics & Telecom', 'Basic Sciences', 'Mechanical Engineering']
                            .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setDialogState(() => dept = v!),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: desig,
                        decoration: const InputDecoration(labelText: 'Designation', prefixIcon: Icon(Icons.workspace_premium_outlined)),
                        items: ['Professor & HOD', 'Professor', 'Associate Professor', 'Assistant Professor', 'Adjunct Faculty']
                            .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setDialogState(() => desig = v!),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final email = emailCtrl.text.trim().isNotEmpty
                        ? emailCtrl.text.trim()
                        : '${nameCtrl.text.trim().toLowerCase().replaceAll(' ', '.')}@enosis.edu.in';
                    try {
                      await _repository.createFaculty(
                        name: nameCtrl.text.trim(),
                        email: email,
                        employeeId: empCtrl.text.trim(),
                        department: dept,
                        designation: desig,
                        phone: phoneCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      await _loadDashboardData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Faculty ${nameCtrl.text.trim()} added successfully!'), backgroundColor: AppColors.success),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to add faculty: $e'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  child: const Text('Add Faculty'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openEditFacultyDialog(FacultyModel faculty) {
    final nameCtrl = TextEditingController(text: faculty.name);
    final emailCtrl = TextEditingController(text: faculty.email);
    final phoneCtrl = TextEditingController(text: faculty.phone);
    String dept = faculty.department.isNotEmpty ? faculty.department : 'CSE (AI & ML)';
    String desig = faculty.designation.isNotEmpty ? faculty.designation : 'Assistant Professor';
    bool canManage = faculty.canManageTimetable;

    final depts = ['CSE (AI & ML)', 'Computer Science', 'Electronics & Telecom', 'Basic Sciences', 'Mechanical Engineering'];
    if (!depts.contains(dept)) depts.add(dept);

    final desigs = ['Professor & HOD', 'Professor', 'Associate Professor', 'Assistant Professor', 'Adjunct Faculty'];
    if (!desigs.contains(desig)) desigs.add(desig);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text('Edit Faculty: ${faculty.employeeId}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                      const SizedBox(height: 12),
                      TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 12),
                      TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: dept,
                        decoration: const InputDecoration(labelText: 'Department'),
                        items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setDialogState(() => dept = v!),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: desig,
                        decoration: const InputDecoration(labelText: 'Designation'),
                        items: desigs.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setDialogState(() => desig = v!),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Timetable Manager Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Allow this faculty member to build and solve timetables', style: TextStyle(fontSize: 11)),
                        value: canManage,
                        onChanged: (val) => setDialogState(() => canManage = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
                  onPressed: () async {
                    try {
                      await _repository.updateFaculty(
                        id: faculty.id,
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        department: dept,
                        designation: desig,
                        canManageTimetable: canManage,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      await _loadDashboardData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Updated ${nameCtrl.text.trim()}!'), backgroundColor: AppColors.success),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── SUBJECT ALLOCATION REASSIGNMENT ────────────────────────────────────────

  void _openReassignSubjectDialog(SubjectAllocationModel allocation) {
    if (_facultyList.isEmpty) return;
    String selectedFacId = allocation.facultyId.isNotEmpty ? allocation.facultyId : _facultyList.first.id;
    String coFacName = allocation.coFacultyName;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.assignment_ind, color: AppColors.secondary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reallocate Subject Faculty', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('${allocation.courseCode}: ${allocation.courseName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Primary Faculty In-Charge:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _facultyList.any((f) => f.id == selectedFacId) ? selectedFacId : _facultyList.first.id,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.school_outlined)),
                      items: _facultyList.map((f) {
                        return DropdownMenuItem(
                          value: f.id,
                          child: Text('${f.name} (${f.designation}, ${f.department})', style: const TextStyle(fontSize: 12.5)),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selectedFacId = v!),
                    ),
                    const SizedBox(height: 16),
                    const Text('Co-Faculty / Lab Assistant:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: coFacName,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.group_outlined)),
                      items: ['None', ..._facultyList.map((f) => f.name)].map((name) {
                        return DropdownMenuItem(
                          value: name,
                          child: Text(name, style: const TextStyle(fontSize: 12.5)),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => coFacName = v!),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reassigning updates the teacher in the CO-PO Attainment Workbench and Timetable automatically.',
                              style: TextStyle(fontSize: 11.5, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
                  onPressed: () async {
                    try {
                      await _repository.reassignSubjectAllocation(
                        allocationId: allocation.id,
                        facultyId: selectedFacId,
                        coFacultyName: coFacName,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      await _loadDashboardData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reallocated ${allocation.courseCode} successfully!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reallocation failed: $e'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  child: const Text('Confirm Allocation'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openAddNewSubjectDialog() {
    if (_facultyList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one faculty member first.')),
      );
      return;
    }

    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    int credits = 3;
    String year = _allocYearFilter;
    String sem = _allocSemFilter;
    String dept = 'CSE (AI & ML)';
    String facId = _facultyList.first.id;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text('Add New Course / Subject', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(labelText: 'Course Code (e.g., UAMPC0405)', prefixIcon: Icon(Icons.code)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Course Title (e.g., Cloud Computing)', prefixIcon: Icon(Icons.menu_book)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: year,
                              decoration: const InputDecoration(labelText: 'Year'),
                              items: ['F.Y. B.Tech', 'S.Y. B.Tech', 'T.Y. B.Tech', 'Final Year B.Tech']
                                  .map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 12))))
                                  .toList(),
                              onChanged: (v) => setDialogState(() => year = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: sem,
                              decoration: const InputDecoration(labelText: 'Semester'),
                              items: ['Semester I', 'Semester II', 'Semester III', 'Semester IV', 'Semester V', 'Semester VI', 'Semester VII', 'Semester VIII']
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                                  .toList(),
                              onChanged: (v) => setDialogState(() => sem = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: facId,
                        decoration: const InputDecoration(labelText: 'Assign Faculty In-Charge'),
                        items: _facultyList.map((f) => DropdownMenuItem(value: f.id, child: Text('${f.name} (${f.department})', style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (v) => setDialogState(() => facId = v!),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
                    try {
                      await _repository.createSubjectAllocation(
                        courseCode: codeCtrl.text.trim().toUpperCase(),
                        courseName: nameCtrl.text.trim(),
                        department: dept,
                        year: year,
                        semester: sem,
                        credits: credits,
                        facultyId: facId,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      await _loadDashboardData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Course ${codeCtrl.text.trim()} created!'), backgroundColor: AppColors.success),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to create course: $e'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  child: const Text('Add Course'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── MAIN BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KIT Admin Portal & Governance Console',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              "KIT's College of Engineering (Autonomous), Kolhapur · Central Master Data",
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Records from Database',
            onPressed: _loadDashboardData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.secondary,
          indicatorWeight: 3.5,
          tabs: [
            Tab(icon: const Icon(Icons.people_alt_outlined, size: 18), text: '1. Faculty Directory (${_facultyList.length})'),
            Tab(icon: const Icon(Icons.menu_book_outlined, size: 18), text: '2. Manage Subjects & Teaching Load (${_subjectAllocations.length})'),
            Tab(icon: const Icon(Icons.verified_user_outlined, size: 18), text: '3. Approvals & System Audit (${_requests.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading Live Central Master Data from Database...', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Failed to load Master Data', style: AppTypography.h3),
                        const SizedBox(height: 8),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Connection'),
                          onPressed: _loadDashboardData,
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFacultyManagementTab(isMobile),
                    _buildSubjectManagementTab(isMobile),
                    _buildApprovalsTab(isMobile),
                  ],
                ),
    );
  }

  // ─── TAB 1: FACULTY DIRECTORY & MANAGEMENT ─────────────────────────────────

  Widget _buildFacultyManagementTab(bool isMobile) {
    final filtered = _facultyList.where((f) {
      final matchesSearch = f.name.toLowerCase().contains(_facultySearchQuery.toLowerCase()) ||
          f.employeeId.toLowerCase().contains(_facultySearchQuery.toLowerCase()) ||
          f.email.toLowerCase().contains(_facultySearchQuery.toLowerCase()) ||
          f.designation.toLowerCase().contains(_facultySearchQuery.toLowerCase());
      final matchesDept = _selectedDeptFilter == 'All' || f.department == _selectedDeptFilter;
      return matchesSearch && matchesDept;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Counters Header
          _buildStatRow(isMobile),
          const SizedBox(height: 20),

          // Search & Filter Toolbar
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search faculty by name, employee code, or designation...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _facultySearchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _selectedDeptFilter,
                    underline: const SizedBox(),
                    items: ['All', 'CSE (AI & ML)', 'Computer Science', 'Electronics & Telecom', 'Basic Sciences', 'Mechanical Engineering']
                        .map((dept) => DropdownMenuItem(value: dept, child: Text(dept, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedDeptFilter = val!),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: const Text('Import Faculty (Excel/CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _openUploadFacultyDialog,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Faculty', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _openAddFacultyDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Faculty List
          Text('Registered Faculty Members (${filtered.length} shown)', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const AppCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No faculty records found matching your filters.'),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final faculty = filtered[idx];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            faculty.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(faculty.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(6)),
                                    child: Text(faculty.employeeId, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  ),
                                  if (faculty.canManageTimetable) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Timetable Coordinator', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text('${faculty.designation} · ${faculty.department}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                              const SizedBox(height: 4),
                              Text('✉ ${faculty.email}   |   ☎ ${faculty.phone.isNotEmpty ? faculty.phone : "N/A"}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11.5)),
                              if (faculty.assignedSubjectCodes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: faculty.assignedSubjectCodes.map((code) {
                                    return Chip(
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      label: Text('$code In-Charge', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit'),
                              onPressed: () => _openEditFacultyDialog(faculty),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              tooltip: 'Deactivate Faculty',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Deactivate Faculty Member?'),
                                    content: Text('Are you sure you want to deactivate ${faculty.name}?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                                        onPressed: () => Navigator.of(c).pop(true),
                                        child: const Text('Deactivate'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _repository.deleteFaculty(faculty.id);
                                  await _loadDashboardData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Deactivated ${faculty.name}')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── TAB 2: SUBJECT ALLOCATION & TEACHING LOAD ─────────────────────────────

  Widget _buildSubjectManagementTab(bool isMobile) {
    final filteredSubjects = _subjectAllocations.where((s) {
      return s.year == _allocYearFilter && s.semester == _allocSemFilter;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Toolbar
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _allocYearFilter,
                      decoration: const InputDecoration(labelText: 'Academic Year', isDense: true),
                      items: ['F.Y. B.Tech', 'S.Y. B.Tech', 'T.Y. B.Tech', 'Final Year B.Tech']
                          .map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setState(() => _allocYearFilter = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _allocSemFilter,
                      decoration: const InputDecoration(labelText: 'Semester', isDense: true),
                      items: ['Semester I', 'Semester II', 'Semester III', 'Semester IV', 'Semester V', 'Semester VI', 'Semester VII', 'Semester VIII']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setState(() => _allocSemFilter = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: const Text('Add Course', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _openAddNewSubjectDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Active Teaching Allocations (${filteredSubjects.length} courses in $_allocYearFilter - $_allocSemFilter)',
            style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (filteredSubjects.isEmpty)
            const AppCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No courses allocated for this semester yet.'),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredSubjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final alloc = filteredSubjects[idx];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            alloc.courseCode,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(alloc.courseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary)),
                              const SizedBox(height: 3),
                              Text('Assigned Teacher: ${alloc.facultyName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.secondary)),
                              if (alloc.coFacultyName != 'None' && alloc.coFacultyName.isNotEmpty)
                                Text('Co-Faculty: ${alloc.coFacultyName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: const BorderSide(color: AppColors.secondary),
                          ),
                          icon: const Icon(Icons.swap_horiz, size: 16),
                          label: const Text('Reassign Faculty'),
                          onPressed: () => _openReassignSubjectDialog(alloc),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── TAB 3: APPROVALS & SYSTEM AUDIT ───────────────────────────────────────

  Widget _buildApprovalsTab(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Pending Faculty Governance & CAS Requests'),
          const SizedBox(height: 12),
          if (_requests.isEmpty)
            const AppCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('All pending requests have been approved and verified!'),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final req = _requests[idx];
                return AppCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
                        child: Text(req.type, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text('Submitted by ${req.facultyName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                        onPressed: () => _handleRequestAction(req.id, true),
                        child: const Text('Approve'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: () => _handleRequestAction(req.id, false),
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 28),

          const SectionHeader(title: 'Administrative Quick Shortcuts'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TimetableHubScreen())),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Generate / Modify Department Timetable', style: TextStyle(fontWeight: FontWeight.bold)),
                      Icon(Icons.arrow_forward_ios, size: 15, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CopoWorkbenchScreen(initialMappingStarted: true))),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('CO-PO Attainment Workbench & Matrix', style: TextStyle(fontWeight: FontWeight.bold)),
                      Icon(Icons.arrow_forward_ios, size: 15, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(bool isMobile) {
    final totalFaculty = _stats?.totalFaculty ?? _facultyList.length;
    final allocatedCourses = _stats?.allocatedCoursesCount ?? _subjectAllocations.length;
    final attainmentPercent = _stats?.attainmentCompletedPercent ?? 0;
    final pendingGov = _stats?.pendingGovernanceCount ?? _requests.length;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.4 : 1.7,
      children: [
        _buildStatCard('Total Faculty', '$totalFaculty', Icons.people_alt_outlined, AppColors.primary),
        _buildStatCard('Allocated Courses', '$allocatedCourses', Icons.menu_book, AppColors.secondary),
        _buildStatCard('Attainment Completed', '$attainmentPercent%', Icons.check_circle_outline, AppColors.success),
        _buildStatCard('Pending Governance', '$pendingGov', Icons.pending_actions, AppColors.warning),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: AppTypography.statNumber.copyWith(color: color, fontSize: 26)),
                Icon(icon, color: color, size: 22),
              ],
            ),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
