import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../copo/presentation/screens/copo_workbench_screen.dart';
import '../../../timetable/presentation/screens/timetable_hub_screen.dart';

// ─── DATA MODELS FOR ADMIN GOVERNANCE ────────────────────────────────────────

class FacultyMember {
  final String id;
  String name;
  String employeeId;
  String email;
  String department;
  String designation;
  String phone;
  List<String> assignedSubjectCodes;
  bool isActive;

  FacultyMember({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.email,
    required this.department,
    required this.designation,
    required this.phone,
    required this.assignedSubjectCodes,
    this.isActive = true,
  });
}

class SubjectAllocation {
  final String courseCode;
  String courseName;
  String department;
  String year;
  String semester;
  int credits;
  String facultyId;
  String facultyName;
  String coFacultyName;
  String attainmentStatus; // 'Not Started' | 'In Progress' | 'Submitted' | 'Approved'

  SubjectAllocation({
    required this.courseCode,
    required this.courseName,
    required this.department,
    required this.year,
    required this.semester,
    this.credits = 3,
    required this.facultyId,
    required this.facultyName,
    this.coFacultyName = 'None',
    this.attainmentStatus = 'In Progress',
  });
}

class _PendingRequest {
  final String id;
  final String facultyName;
  final String type; // "CAS" | "Leave" | "FDP"
  final String title;

  _PendingRequest({
    required this.id,
    required this.facultyName,
    required this.type,
    required this.title,
  });
}

// ─── ADMIN DASHBOARD SCREEN ──────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ─── INITIAL MOCK DATA ────────────────────────────────────────────────────

  final List<FacultyMember> _facultyList = [
    FacultyMember(
      id: 'fac_1',
      name: 'Dr. Priya Sharma',
      employeeId: 'KIT-AIML-101',
      email: 'priya.sharma@kitcoek.in',
      department: 'CSE (AI & ML)',
      designation: 'Professor & HOD',
      phone: '+91 98220 11223',
      assignedSubjectCodes: ['UAMPC0403', 'UAMPC0303'],
    ),
    FacultyMember(
      id: 'fac_2',
      name: 'Prof. Rajesh Kumar',
      employeeId: 'KIT-AIML-102',
      email: 'rajesh.kumar@kitcoek.in',
      department: 'CSE (AI & ML)',
      designation: 'Associate Professor',
      phone: '+91 98220 22334',
      assignedSubjectCodes: ['UAMPC0401'],
    ),
    FacultyMember(
      id: 'fac_3',
      name: 'Dr. Anil Mehta',
      employeeId: 'KIT-AIML-103',
      email: 'anil.mehta@kitcoek.in',
      department: 'CSE (AI & ML)',
      designation: 'Professor',
      phone: '+91 98220 33445',
      assignedSubjectCodes: ['UAMPC0402'],
    ),
    FacultyMember(
      id: 'fac_4',
      name: 'Prof. Sunita Rao',
      employeeId: 'KIT-AIML-104',
      email: 'sunita.rao@kitcoek.in',
      department: 'CSE (AI & ML)',
      designation: 'Assistant Professor',
      phone: '+91 98220 44556',
      assignedSubjectCodes: ['UAMPC0404'],
    ),
    FacultyMember(
      id: 'fac_5',
      name: 'Dr. Manoj Kulkarni',
      employeeId: 'KIT-AIML-105',
      email: 'manoj.kulkarni@kitcoek.in',
      department: 'CSE (AI & ML)',
      designation: 'Associate Professor',
      phone: '+91 98220 55667',
      assignedSubjectCodes: ['UAMPC0301'],
    ),
    FacultyMember(
      id: 'fac_6',
      name: 'Prof. Neha Patil',
      employeeId: 'KIT-CSE-201',
      email: 'neha.patil@kitcoek.in',
      department: 'Computer Science',
      designation: 'Assistant Professor',
      phone: '+91 98220 66778',
      assignedSubjectCodes: ['UAMPC0302'],
    ),
    FacultyMember(
      id: 'fac_7',
      name: 'Dr. Vikram Deshmukh',
      employeeId: 'KIT-ETC-301',
      email: 'vikram.d@kitcoek.in',
      department: 'Electronics & Telecom',
      designation: 'Associate Professor',
      phone: '+91 98220 77889',
      assignedSubjectCodes: ['UAMPC0104'],
    ),
    FacultyMember(
      id: 'fac_8',
      name: 'Prof. Kavita Joshi',
      email: 'kavita.j@kitcoek.in',
      employeeId: 'KIT-BS-401',
      department: 'Basic Sciences',
      designation: 'Assistant Professor',
      phone: '+91 98220 88990',
      assignedSubjectCodes: ['UAMPC0101'],
    ),
  ];

  final List<SubjectAllocation> _subjectAllocations = [
    SubjectAllocation(
      courseCode: 'UAMPC0403',
      courseName: 'Design and Analysis of Algorithms',
      department: 'CSE (AI & ML)',
      year: 'S.Y. B.Tech',
      semester: 'Semester IV',
      credits: 4,
      facultyId: 'fac_1',
      facultyName: 'Dr. Priya Sharma',
      coFacultyName: 'Prof. Rajesh Kumar',
      attainmentStatus: 'In Progress',
    ),
    SubjectAllocation(
      courseCode: 'UAMPC0401',
      courseName: 'Operating Systems & Architecture',
      department: 'CSE (AI & ML)',
      year: 'S.Y. B.Tech',
      semester: 'Semester IV',
      credits: 3,
      facultyId: 'fac_2',
      facultyName: 'Prof. Rajesh Kumar',
      coFacultyName: 'Prof. Sunita Rao',
      attainmentStatus: 'Submitted',
    ),
    SubjectAllocation(
      courseCode: 'UAMPC0402',
      courseName: 'Database Management Systems',
      department: 'CSE (AI & ML)',
      year: 'S.Y. B.Tech',
      semester: 'Semester IV',
      credits: 3,
      facultyId: 'fac_3',
      facultyName: 'Dr. Anil Mehta',
      coFacultyName: 'None',
      attainmentStatus: 'In Progress',
    ),
    SubjectAllocation(
      courseCode: 'UAMPC0404',
      courseName: 'Machine Learning Foundations',
      department: 'CSE (AI & ML)',
      year: 'S.Y. B.Tech',
      semester: 'Semester IV',
      credits: 4,
      facultyId: 'fac_4',
      facultyName: 'Prof. Sunita Rao',
      coFacultyName: 'Dr. Priya Sharma',
      attainmentStatus: 'Not Started',
    ),
    SubjectAllocation(
      courseCode: 'UAMPC0301',
      courseName: 'Discrete Mathematics and Graph Theory',
      department: 'CSE (AI & ML)',
      year: 'S.Y. B.Tech',
      semester: 'Semester III',
      credits: 3,
      facultyId: 'fac_5',
      facultyName: 'Dr. Manoj Kulkarni',
      coFacultyName: 'None',
      attainmentStatus: 'Approved',
    ),
    SubjectAllocation(
      courseCode: 'UAMPC0302',
      courseName: 'Linear Algebra for Machine Learning',
      department: 'CSE (AI & ML)',
      year: 'S.Y. B.Tech',
      semester: 'Semester III',
      credits: 3,
      facultyId: 'fac_6',
      facultyName: 'Prof. Neha Patil',
      coFacultyName: 'Dr. Anil Mehta',
      attainmentStatus: 'Approved',
    ),
    SubjectAllocation(
      courseCode: 'UAMPC0303',
      courseName: 'Advanced Data Structures',
      department: 'CSE (AI & ML)',
      year: 'S.Y. B.Tech',
      semester: 'Semester III',
      credits: 3,
      facultyId: 'fac_1',
      facultyName: 'Dr. Priya Sharma',
      coFacultyName: 'Prof. Sunita Rao',
      attainmentStatus: 'Approved',
    ),
    SubjectAllocation(
      courseCode: 'UAMPC0101',
      courseName: 'Engineering Mathematics-I',
      department: 'Basic Sciences',
      year: 'F.Y. B.Tech',
      semester: 'Semester I',
      credits: 4,
      facultyId: 'fac_8',
      facultyName: 'Prof. Kavita Joshi',
      coFacultyName: 'None',
      attainmentStatus: 'Approved',
    ),
  ];

  final List<_PendingRequest> _requests = [
    _PendingRequest(id: 'r_1', facultyName: 'Dr. Priya Sharma', type: 'CAS', title: 'CAS Portfolio Verification: Tier II Promotion to Senior Professor'),
    _PendingRequest(id: 'r_2', facultyName: 'Prof. Rajesh Kumar', type: 'Leave', title: 'Medical Leave: 14 Aug - 18 Aug (5 days)'),
    _PendingRequest(id: 'r_3', facultyName: 'Dr. Anil Mehta', type: 'FDP', title: 'National Workshop on AI/ML at IIT Bombay (Sponsored)'),
    _PendingRequest(id: 'r_4', facultyName: 'Prof. Sunita Rao', type: 'CAS', title: 'Research Publication Indexing & Validation: IEEE Access'),
  ];

  // Filters
  String _facultySearchQuery = '';
  String _selectedDeptFilter = 'All';
  String _allocYearFilter = 'S.Y. B.Tech';
  String _allocSemFilter = 'Semester IV';

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

  void _handleRequestAction(String id, bool approve) {
    setState(() {
      _requests.removeWhere((r) => r.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approve ? 'Request approved and signed.' : 'Request rejected.'),
        backgroundColor: approve ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
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
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setState(() {
                      _facultyList.add(FacultyMember(
                        id: 'fac_${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text.trim(),
                        employeeId: empCtrl.text.trim(),
                        email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : '${nameCtrl.text.trim().toLowerCase().replaceAll(' ', '.')}@kitcoek.in',
                        department: dept,
                        designation: desig,
                        phone: phoneCtrl.text.trim(),
                        assignedSubjectCodes: [],
                      ));
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Faculty ${nameCtrl.text.trim()} added successfully!'), backgroundColor: AppColors.success),
                    );
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

  void _openEditFacultyDialog(FacultyMember faculty) {
    final nameCtrl = TextEditingController(text: faculty.name);
    final emailCtrl = TextEditingController(text: faculty.email);
    final phoneCtrl = TextEditingController(text: faculty.phone);
    String dept = faculty.department;
    String desig = faculty.designation;

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
                        items: ['CSE (AI & ML)', 'Computer Science', 'Electronics & Telecom', 'Basic Sciences', 'Mechanical Engineering']
                            .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setDialogState(() => dept = v!),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: desig,
                        decoration: const InputDecoration(labelText: 'Designation'),
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() {
                      faculty.name = nameCtrl.text.trim();
                      faculty.email = emailCtrl.text.trim();
                      faculty.phone = phoneCtrl.text.trim();
                      faculty.department = dept;
                      faculty.designation = desig;
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Updated ${faculty.name}!'), backgroundColor: AppColors.success),
                    );
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

  void _openReassignSubjectDialog(SubjectAllocation allocation) {
    String selectedFacId = allocation.facultyId;
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
                      value: selectedFacId.isNotEmpty ? selectedFacId : _facultyList.first.id,
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
                  onPressed: () {
                    final newFaculty = _facultyList.firstWhere((f) => f.id == selectedFacId);
                    setState(() {
                      // Update old faculty
                      for (final f in _facultyList) {
                        f.assignedSubjectCodes.remove(allocation.courseCode);
                      }
                      // Update new faculty
                      newFaculty.assignedSubjectCodes.add(allocation.courseCode);
                      allocation.facultyId = newFaculty.id;
                      allocation.facultyName = newFaculty.name;
                      allocation.coFacultyName = coFacName;
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Reallocated ${allocation.courseCode} to ${newFaculty.name}!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
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
                  onPressed: () {
                    if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
                    final fac = _facultyList.firstWhere((f) => f.id == facId);
                    setState(() {
                      final newAlloc = SubjectAllocation(
                        courseCode: codeCtrl.text.trim().toUpperCase(),
                        courseName: nameCtrl.text.trim(),
                        department: dept,
                        year: year,
                        semester: sem,
                        credits: credits,
                        facultyId: fac.id,
                        facultyName: fac.name,
                        attainmentStatus: 'Not Started',
                      );
                      _subjectAllocations.add(newAlloc);
                      fac.assignedSubjectCodes.add(newAlloc.courseCode);
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Course ${codeCtrl.text.trim()} created!'), backgroundColor: AppColors.success),
                    );
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
              "KIT's College of Engineering (Autonomous), Kolhapur · Academic Monitoring",
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Records',
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.secondary,
          indicatorWeight: 3.5,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: '1. Faculty Directory'),
            Tab(icon: Icon(Icons.menu_book_outlined, size: 18), text: '2. Manage Subjects & Teaching Load'),
            Tab(icon: Icon(Icons.verified_user_outlined, size: 18), text: '3. Approvals & System Audit'),
          ],
        ),
      ),
      body: TabBarView(
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
              child: isMobile
                  ? Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search faculty...',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _facultySearchQuery = val),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButton<String>(
                                value: _selectedDeptFilter,
                                isExpanded: true,
                                underline: const SizedBox(),
                                items: ['All', 'CSE (AI & ML)', 'Computer Science', 'Electronics & Telecom', 'Basic Sciences']
                                    .map((dept) => DropdownMenuItem(value: dept, child: Text(dept, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                                    .toList(),
                                onChanged: (val) => setState(() => _selectedDeptFilter = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: _openAddFacultyDialog,
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
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
                          items: ['All', 'CSE (AI & ML)', 'Computer Science', 'Electronics & Telecom', 'Basic Sciences']
                              .map((dept) => DropdownMenuItem(value: dept, child: Text(dept, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedDeptFilter = val!),
                        ),
                        const SizedBox(width: 16),
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
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('${faculty.designation} · ${faculty.department}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            Text('✉ ${faculty.email}   |   ☎ ${faculty.phone}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11.5)),
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
                            onPressed: () {
                              setState(() {
                                _facultyList.removeWhere((f) => f.id == faculty.id);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Removed ${faculty.name}')),
                              );
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
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_list, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      const Text('Filter Term:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _allocYearFilter,
                        underline: const SizedBox(),
                        items: ['F.Y. B.Tech', 'S.Y. B.Tech', 'T.Y. B.Tech', 'Final Year B.Tech']
                            .map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontWeight: FontWeight.bold))))
                            .toList(),
                        onChanged: (v) => setState(() => _allocYearFilter = v!),
                      ),
                      const SizedBox(width: 14),
                      DropdownButton<String>(
                        value: _allocSemFilter,
                        underline: const SizedBox(),
                        items: ['Semester I', 'Semester II', 'Semester III', 'Semester IV', 'Semester V', 'Semester VI', 'Semester VII', 'Semester VIII']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold))))
                            .toList(),
                        onChanged: (v) => setState(() => _allocSemFilter = v!),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Course'),
                    onPressed: _openAddNewSubjectDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('Subject Faculty Allocations for $_allocYearFilter ($_allocSemFilter)', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          if (filteredSubjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('No subjects registered for this semester. Click "Add Course" above.'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredSubjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final sub = filteredSubjects[idx];
                final statusColor = sub.attainmentStatus == 'Approved'
                    ? AppColors.success
                    : (sub.attainmentStatus == 'Submitted' ? Colors.blue : (sub.attainmentStatus == 'In Progress' ? AppColors.warning : AppColors.textTertiary));

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            sub.courseCode,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sub.courseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Text('${sub.department} · ${sub.credits} Credits · Theory & Practical', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 16, color: AppColors.secondary),
                                  const SizedBox(width: 6),
                                  Text('Primary Faculty: ${sub.facultyName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.textPrimary)),
                                  const SizedBox(width: 14),
                                  Text('Co-Faculty: ${sub.coFacultyName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                sub.attainmentStatus,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.swap_horiz, size: 16),
                                  label: const Text('Reallocate Faculty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () => _openReassignSubjectDialog(sub),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.open_in_new, size: 15),
                                  label: const Text('Workbench', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const CopoWorkbenchScreen(initialMappingStarted: true)),
                                    );
                                  },
                                ),
                              ],
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

  // ─── TAB 3: APPROVALS & SYSTEM AUDIT ───────────────────────────────────────

  Widget _buildApprovalsTab(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Pending Faculty Governance Requests'),
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
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.4 : 1.7,
      children: [
        _buildStatCard('Total Faculty', '${_facultyList.length}', Icons.people_alt_outlined, AppColors.primary),
        _buildStatCard('Allocated Courses', '${_subjectAllocations.length}', Icons.menu_book, AppColors.secondary),
        _buildStatCard('Attainment Completed', '75%', Icons.check_circle_outline, AppColors.success),
        _buildStatCard('Pending Governance', '${_requests.length}', Icons.pending_actions, AppColors.warning),
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
