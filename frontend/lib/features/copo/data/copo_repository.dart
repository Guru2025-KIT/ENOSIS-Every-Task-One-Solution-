class CopoMatrix {
  final String courseId;
  final String semester;
  final List<List<int>> matrix; // 5 rows (CO1-CO5) x 6 columns (PO1-PO6)

  CopoMatrix({
    required this.courseId,
    required this.semester,
    required this.matrix,
  });
}

class CopoAttainmentResult {
  final String courseId;
  final String semester;
  final List<double> coAttainments; // 5 percentages (CO1-CO5)
  final List<double> poAttainments; // 6 percentages (PO1-PO6)

  CopoAttainmentResult({
    required this.courseId,
    required this.semester,
    required this.coAttainments,
    required this.poAttainments,
  });
}

class CopoCourseProgress {
  final String courseCode;
  final String courseName;
  final double progress; // 0.0 to 1.0

  CopoCourseProgress({
    required this.courseCode,
    required this.courseName,
    required this.progress,
  });
}

/// In-memory repository to manage CO-PO matrices, calculate attainment rates,
/// and track admin course progress metrics.
///
/// Keeps data dynamic and interactive in the frontend immediately without calling
/// non-existent backend APIs.
class CopoRepository {
  static final Map<String, CopoMatrix> _matrices = {
    'CS201': CopoMatrix(
      courseId: 'CS201',
      semester: 'Semester V',
      matrix: [
        [3, 2, 2, 1, 2, 1], // CO1
        [3, 2, 3, 2, 2, 1], // CO2
        [3, 2, 2, 3, 2, 2], // CO3
        [2, 1, 2, 2, 2, 1], // CO4
        [3, 2, 2, 1, 2, 1], // CO5
      ],
    ),
    'CS202': CopoMatrix(
      courseId: 'CS202',
      semester: 'Semester V',
      matrix: [
        [2, 2, 1, 1, 1, 1], // CO1
        [3, 2, 2, 1, 2, 1], // CO2
        [2, 2, 3, 2, 1, 1], // CO3
        [3, 1, 2, 1, 2, 1], // CO4
        [2, 2, 2, 1, 1, 1], // CO5
      ],
    ),
  };

  static final List<CopoCourseProgress> _courseProgress = [
    CopoCourseProgress(courseCode: 'CS201', courseName: 'Data Structures', progress: 0.80),
    CopoCourseProgress(courseCode: 'CS202', courseName: 'Database Mgmt. Systems', progress: 0.65),
    CopoCourseProgress(courseCode: 'CS203', courseName: 'Operating Systems', progress: 0.90),
    CopoCourseProgress(courseCode: 'CS204', courseName: 'Computer Networks', progress: 0.70),
    CopoCourseProgress(courseCode: 'CS205', courseName: 'AI & ML Lab', progress: 0.85),
  ];

  Future<CopoMatrix> fetchMatrix(String courseId, String semester) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _matrices[courseId] ??
        CopoMatrix(
          courseId: courseId,
          semester: semester,
          matrix: List.generate(5, (_) => List.generate(6, (_) => 0)),
        );
  }

  Future<void> saveMatrix(CopoMatrix matrix) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _matrices[matrix.courseId] = matrix;
  }

  Future<CopoAttainmentResult> calculateAttainment(String courseId, String semester) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final matrixData = await fetchMatrix(courseId, semester);

    // Calculate mock attainment rates dynamically based on the matrix values
    // to give realistic, non-hardcoded feedback!
    final List<double> co = [];
    final List<double> po = [];

    // Calculate CO attainment based on row averages
    for (int r = 0; r < 5; r++) {
      double sum = 0;
      for (int c = 0; c < 6; c++) {
        sum += matrixData.matrix[r][c];
      }
      // row sum average mapped to a percentage between 60% and 95%
      final avg = sum / 18.0; // max sum is 18
      final pct = (60.0 + (avg * 35.0)).clamp(60.0, 95.0);
      co.add(double.parse(pct.toStringAsFixed(1)));
    }

    // Calculate PO attainment based on column averages
    for (int c = 0; c < 6; c++) {
      double sum = 0;
      for (int r = 0; r < 5; r++) {
        sum += matrixData.matrix[r][c];
      }
      final avg = sum / 15.0; // max sum is 15
      final pct = (65.0 + (avg * 30.0)).clamp(65.0, 95.0);
      po.add(double.parse(pct.toStringAsFixed(1)));
    }

    return CopoAttainmentResult(
      courseId: courseId,
      semester: semester,
      coAttainments: co,
      poAttainments: po,
    );
  }

  Future<List<CopoCourseProgress>> fetchCourseProgress() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _courseProgress;
  }
}
