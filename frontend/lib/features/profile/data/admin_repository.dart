import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

class AdminDashboardStats {
  final int totalFaculty;
  final int activeFaculty;
  final int allocatedCoursesCount;
  final int attainmentCompletedPercent;
  final int pendingGovernanceCount;
  final Map<String, int> departmentCounts;

  AdminDashboardStats({
    required this.totalFaculty,
    required this.activeFaculty,
    required this.allocatedCoursesCount,
    required this.attainmentCompletedPercent,
    required this.pendingGovernanceCount,
    required this.departmentCounts,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      totalFaculty: json['total_faculty'] as int? ?? 0,
      activeFaculty: json['active_faculty'] as int? ?? 0,
      allocatedCoursesCount: json['allocated_courses_count'] as int? ?? 0,
      attainmentCompletedPercent: json['attainment_completed_percent'] as int? ?? 0,
      pendingGovernanceCount: json['pending_governance_count'] as int? ?? 0,
      departmentCounts: (json['department_counts'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
    );
  }
}

class FacultyModel {
  final String id;
  String name;
  String email;
  String employeeId;
  String department;
  String designation;
  String phone;
  bool isActive;
  bool canManageTimetable;
  List<String> assignedSubjectCodes;
  DateTime? createdAt;

  FacultyModel({
    required this.id,
    required this.name,
    required this.email,
    required this.employeeId,
    required this.department,
    required this.designation,
    required this.phone,
    this.isActive = true,
    this.canManageTimetable = false,
    this.assignedSubjectCodes = const [],
    this.createdAt,
  });

  factory FacultyModel.fromJson(Map<String, dynamic> json) {
    return FacultyModel(
      id: json['id'] as String? ?? '',
      name: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      department: json['department'] as String? ?? '',
      designation: json['designation'] as String? ?? 'Assistant Professor',
      phone: json['phone'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      canManageTimetable: json['can_manage_timetable'] as bool? ?? false,
      assignedSubjectCodes: (json['assigned_subject_codes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': name,
        'email': email,
        'employee_id': employeeId,
        'department': department,
        'designation': designation,
        'phone': phone,
        'is_active': isActive,
        'can_manage_timetable': canManageTimetable,
      };
}

class SubjectAllocationModel {
  final String id;
  final String courseCode;
  String courseName;
  String department;
  String year;
  String semester;
  int credits;
  String facultyId;
  String facultyName;
  String coFacultyName;
  String attainmentStatus;

  SubjectAllocationModel({
    required this.id,
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

  factory SubjectAllocationModel.fromJson(Map<String, dynamic> json) {
    return SubjectAllocationModel(
      id: json['id'] as String? ?? '',
      courseCode: json['course_code'] as String? ?? '',
      courseName: json['course_name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      year: json['year'] as String? ?? '',
      semester: json['semester'] as String? ?? '',
      credits: json['credits'] as int? ?? 3,
      facultyId: json['faculty_id'] as String? ?? '',
      facultyName: json['faculty_name'] as String? ?? '',
      coFacultyName: json['co_faculty_name'] as String? ?? 'None',
      attainmentStatus: json['attainment_status'] as String? ?? 'In Progress',
    );
  }
}

class FacultyImportRowModel {
  final int rowNumber;
  final String fullName;
  final String email;
  final String employeeId;
  final String department;
  final String designation;
  final String? phone;
  final String? error;

  FacultyImportRowModel({
    required this.rowNumber,
    required this.fullName,
    required this.email,
    required this.employeeId,
    required this.department,
    this.designation = 'Assistant Professor',
    this.phone,
    this.error,
  });

  factory FacultyImportRowModel.fromJson(Map<String, dynamic> json) {
    return FacultyImportRowModel(
      rowNumber: json['row_number'] as int? ?? 0,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      department: json['department'] as String? ?? '',
      designation: json['designation'] as String? ?? 'Assistant Professor',
      phone: json['phone'] as String?,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'row_number': rowNumber,
        'full_name': fullName,
        'email': email,
        'employee_id': employeeId,
        'department': department,
        'designation': designation,
        if (phone != null) 'phone': phone,
        if (error != null) 'error': error,
      };
}

class FacultyValidationResultModel {
  final int totalRows;
  final int validCount;
  final int invalidCount;
  final int duplicateCount;
  final int missingFieldsCount;
  final List<FacultyImportRowModel> validRows;
  final List<FacultyImportRowModel> invalidRows;
  final List<FacultyImportRowModel> duplicateRows;
  final List<FacultyImportRowModel> missingFieldsRows;

  FacultyValidationResultModel({
    required this.totalRows,
    required this.validCount,
    required this.invalidCount,
    required this.duplicateCount,
    required this.missingFieldsCount,
    required this.validRows,
    required this.invalidRows,
    required this.duplicateRows,
    required this.missingFieldsRows,
  });

  factory FacultyValidationResultModel.fromJson(Map<String, dynamic> json) {
    return FacultyValidationResultModel(
      totalRows: json['total_rows'] as int? ?? 0,
      validCount: json['valid_count'] as int? ?? 0,
      invalidCount: json['invalid_count'] as int? ?? 0,
      duplicateCount: json['duplicate_count'] as int? ?? 0,
      missingFieldsCount: json['missing_fields_count'] as int? ?? 0,
      validRows: (json['valid_rows'] as List<dynamic>?)
              ?.map((r) => FacultyImportRowModel.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      invalidRows: (json['invalid_rows'] as List<dynamic>?)
              ?.map((r) => FacultyImportRowModel.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      duplicateRows: (json['duplicate_rows'] as List<dynamic>?)
              ?.map((r) => FacultyImportRowModel.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      missingFieldsRows: (json['missing_fields_rows'] as List<dynamic>?)
              ?.map((r) => FacultyImportRowModel.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class GovernanceRequestModel {
  final String id;
  final String facultyId;
  final String facultyName;
  final String type;
  final String title;
  final String status;
  final DateTime submittedAt;
  final String? documentUrl;

  GovernanceRequestModel({
    required this.id,
    required this.facultyId,
    required this.facultyName,
    required this.type,
    required this.title,
    required this.status,
    required this.submittedAt,
    this.documentUrl,
  });

  factory GovernanceRequestModel.fromJson(Map<String, dynamic> json) {
    return GovernanceRequestModel(
      id: json['id'] as String? ?? '',
      facultyId: json['faculty_id'] as String? ?? '',
      facultyName: json['faculty_name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'].toString())
          : DateTime.now(),
      documentUrl: json['document_url'] as String?,
    );
  }
}

class AdminRepository {
  static final AdminRepository _instance = AdminRepository._internal();
  factory AdminRepository() => _instance;
  AdminRepository._internal();

  String? get _token => AuthSession.token;

  Future<AdminDashboardStats> getDashboardStats() async {
    final res = await ApiClient.get('/admin/dashboard-stats', token: _token);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch dashboard stats: ${res.body}');
    }
    return AdminDashboardStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<FacultyModel>> getFacultyList({String? department}) async {
    final query = department != null && department != 'All' ? '?department=${Uri.encodeComponent(department)}' : '';
    final res = await ApiClient.get('/admin/faculty$query', token: _token);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch faculty list: ${res.body}');
    }
    final List list = jsonDecode(res.body) as List;
    return list.map((e) => FacultyModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FacultyModel> createFaculty({
    required String name,
    required String email,
    required String employeeId,
    required String department,
    String? designation,
    String? phone,
    String? password,
  }) async {
    final res = await ApiClient.postJson(
      '/admin/faculty',
      {
        'full_name': name,
        'email': email,
        'employee_id': employeeId,
        'department': department,
        'designation': designation ?? 'Assistant Professor',
        'phone': phone,
        if (password != null) 'password': password,
      },
      token: _token,
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to create faculty: ${res.body}');
    }
    return FacultyModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<FacultyModel> updateFaculty({
    required String id,
    String? name,
    String? email,
    String? employeeId,
    String? department,
    String? designation,
    String? phone,
    bool? isActive,
    bool? canManageTimetable,
  }) async {
    final res = await ApiClient.putJson(
      '/admin/faculty/$id',
      {
        if (name != null) 'full_name': name,
        if (email != null) 'email': email,
        if (employeeId != null) 'employee_id': employeeId,
        if (department != null) 'department': department,
        if (designation != null) 'designation': designation,
        if (phone != null) 'phone': phone,
        if (isActive != null) 'is_active': isActive,
        if (canManageTimetable != null) 'can_manage_timetable': canManageTimetable,
      },
      token: _token,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update faculty: ${res.body}');
    }
    return FacultyModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteFaculty(String id) async {
    final res = await ApiClient.delete('/admin/faculty/$id', token: _token);
    if (res.statusCode != 200) {
      throw Exception('Failed to delete faculty: ${res.body}');
    }
  }

  Future<FacultyValidationResultModel> validateFacultyUpload({
    List<int>? bytes,
    String? filePath,
    required String fileName,
  }) async {
    final streamedRes = await ApiClient.uploadFile(
      '/admin/faculty/validate-upload',
      fileName: fileName,
      fieldName: 'file',
      fileBytes: bytes,
      filePath: filePath,
      token: _token,
    );
    final res = await http.Response.fromStream(streamedRes);
    if (res.statusCode != 200) {
      throw Exception('Failed to validate upload: ${res.body}');
    }
    return FacultyValidationResultModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<int> bulkImportFaculty(List<FacultyImportRowModel> rows) async {
    final res = await ApiClient.postJson(
      '/admin/faculty/import',
      {
        'rows': rows.map((r) => r.toJson()).toList(),
      },
      token: _token,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to import faculty: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['imported_count'] as int? ?? 0;
  }

  Future<List<SubjectAllocationModel>> getSubjectAllocations({String? department}) async {
    final query = department != null && department != 'All' ? '?department=${Uri.encodeComponent(department)}' : '';
    final res = await ApiClient.get('/admin/allocations$query', token: _token);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch allocations: ${res.body}');
    }
    final List list = jsonDecode(res.body) as List;
    return list.map((e) => SubjectAllocationModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SubjectAllocationModel> createSubjectAllocation({
    required String courseCode,
    required String courseName,
    required String department,
    required String year,
    required String semester,
    int credits = 3,
    required String facultyId,
    String coFacultyName = 'None',
  }) async {
    final res = await ApiClient.postJson(
      '/admin/allocations',
      {
        'course_code': courseCode,
        'course_name': courseName,
        'department': department,
        'year': year,
        'semester': semester,
        'credits': credits,
        'faculty_id': facultyId,
        'co_faculty_name': coFacultyName,
      },
      token: _token,
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to create allocation: ${res.body}');
    }
    return SubjectAllocationModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<SubjectAllocationModel> reassignSubjectAllocation({
    required String allocationId,
    required String facultyId,
    String? coFacultyName,
  }) async {
    final res = await ApiClient.postJson(
      '/admin/allocations/$allocationId/reassign',
      {
        'faculty_id': facultyId,
        'co_faculty_name': coFacultyName ?? 'None',
      },
      token: _token,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to reassign allocation: ${res.body}');
    }
    return SubjectAllocationModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<GovernanceRequestModel>> getGovernanceRequests({String? statusFilter}) async {
    final query = statusFilter != null ? '?status_filter=${Uri.encodeComponent(statusFilter)}' : '';
    final res = await ApiClient.get('/admin/governance-requests$query', token: _token);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch governance requests: ${res.body}');
    }
    final List list = jsonDecode(res.body) as List;
    return list.map((e) => GovernanceRequestModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<GovernanceRequestModel> processGovernanceAction({
    required String requestId,
    required String action, // "APPROVE" | "REJECT"
    String? remarks,
  }) async {
    final res = await ApiClient.postJson(
      '/admin/governance-requests/$requestId/action',
      {
        'action': action,
        if (remarks != null) 'remarks': remarks,
      },
      token: _token,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to process governance action: ${res.body}');
    }
    return GovernanceRequestModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
