import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/copo_pdf_service.dart';
import '../../data/copo_repository.dart';
import '../../data/copo_spreadsheet_service.dart';

class CopoWorkbenchScreen extends StatefulWidget {
  final bool initialMappingStarted;

  const CopoWorkbenchScreen({
    super.key,
    this.initialMappingStarted = true,
  });

  @override
  State<CopoWorkbenchScreen> createState() => _CopoWorkbenchScreenState();
}

class _CopoWorkbenchScreenState extends State<CopoWorkbenchScreen>
    with SingleTickerProviderStateMixin {
  final _repository = CopoRepository();
  late TabController _tabController;

  int _selectedIseIndex = 0; // 0 for ISE1, 1 for ISE2
  int _selectedExamIndex = 0; // 0 for MSE, 1 for ESE
  bool _isProcessing = false;
  CopoAttainmentReport? _cachedReport;

  // Year, Semester & Course Selection State
  late bool _hasStartedMapping;
  String _selectedYear = 'S.Y. B.Tech';
  String _selectedSemester = 'Semester IV';
  late KitCourseInfo _selectedCourse;

  List<String> get _availableSemesters {
    switch (_selectedYear) {
      case 'F.Y. B.Tech':
        return ['Semester I', 'Semester II'];
      case 'S.Y. B.Tech':
        return ['Semester III', 'Semester IV'];
      case 'T.Y. B.Tech':
        return ['Semester V', 'Semester VI'];
      case 'Final Year B.Tech':
        return ['Semester VII', 'Semester VIII'];
      default:
        return ['Semester IV'];
    }
  }

  List<KitCourseInfo> get _availableCourses {
    return kitAimlCourses.where((c) => c.semester == _selectedSemester).toList();
  }

  void _onYearChanged(String newYear) {
    setState(() {
      _selectedYear = newYear;
      final sems = _availableSemesters;
      _selectedSemester = sems.first;
      final courses = _availableCourses;
      if (courses.isNotEmpty) {
        _selectedCourse = courses.first;
        _repository.selectCourse(_selectedCourse);
      }
      _recalculate();
    });
  }

  void _onSemesterChanged(String newSem) {
    setState(() {
      _selectedSemester = newSem;
      final courses = _availableCourses;
      if (courses.isNotEmpty) {
        _selectedCourse = courses.first;
        _repository.selectCourse(_selectedCourse);
      }
      _recalculate();
    });
  }

  void _onCourseChanged(KitCourseInfo newCourse) {
    setState(() {
      _selectedCourse = newCourse;
      _repository.selectCourse(_selectedCourse);
      _recalculate();
    });
  }

  static const List<String> _stepNames = [
    'Master Matrix',
    'Roll Call',
    'In-Sem (ISE)',
    'Question-wise (MSE/ESE)',
    'Exit Survey',
    'Attainment Report',
  ];

  void _goToTab(int index) {
    if (index >= 0 && index < 6) {
      _tabController.animateTo(index);
    }
  }

  @override
  void initState() {
    super.initState();
    _hasStartedMapping = widget.initialMappingStarted;
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _repository.ensureInitialized();
    _selectedCourse = kitAimlCourses.firstWhere(
      (c) => c.code == 'UAMPC0403',
      orElse: () => kitAimlCourses.first,
    );
    _repository.selectCourse(_selectedCourse);
    _recalculate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _cachedReport = _repository.calculateLocalReport();
    });
  }

  void _resetToSample() {
    setState(() {
      _repository.initializeWithSampleData();
      _recalculate();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Loaded standard DBE sample course dataset with 30 students.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── FILE PICKER & EXTRACTION HANDLERS ──────────────────────────────────────

  Future<void> _handleUploadIseMarks(IseExamData exam) async {
    setState(() => _isProcessing = true);
    try {
      final result = await CopoSpreadsheetService.pickAndParseMarksSheet();
      if (result == null || result.rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No spreadsheet selected or file was empty.')),
          );
        }
        return;
      }

      int matched = 0;
      for (final parsed in result.rows) {
        final existingIdx = exam.scores.indexWhere(
          (s) => s.rollNo.trim().toLowerCase() == parsed.rollNo.trim().toLowerCase(),
        );

        if (existingIdx != -1) {
          exam.scores[existingIdx].marks = parsed.singleMark;
          matched++;
        } else {
          // Add new student score if not already present
          exam.scores.add(StudentIseScore(rollNo: parsed.rollNo, marks: parsed.singleMark));
          matched++;
        }
      }

      _recalculate();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully extracted marks for $matched students from ${result.fileName}!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extraction error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleUploadQuestionWiseMarks(QuestionWiseExamData exam) async {
    setState(() => _isProcessing = true);
    try {
      final result = await CopoSpreadsheetService.pickAndParseMarksSheet();
      if (result == null || result.rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No spreadsheet selected or file was empty.')),
          );
        }
        return;
      }

      int matched = 0;
      for (final parsed in result.rows) {
        final existingIdx = exam.studentScores.indexWhere(
          (s) => s.rollNo.trim().toLowerCase() == parsed.rollNo.trim().toLowerCase(),
        );

        if (existingIdx != -1) {
          for (final q in exam.questions) {
            if (parsed.questionMarks.containsKey(q.questionId)) {
              exam.studentScores[existingIdx].scores[q.questionId] = parsed.questionMarks[q.questionId];
            }
          }
          matched++;
        } else {
          exam.studentScores.add(StudentQuestionScore(
            rollNo: parsed.rollNo,
            scores: parsed.questionMarks,
          ));
          matched++;
        }
      }

      _recalculate();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extracted question marks for $matched students from ${result.fileName}!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extraction error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleUploadRoster() async {
    setState(() => _isProcessing = true);
    try {
      final result = await CopoSpreadsheetService.pickAndParseMarksSheet();
      if (result == null || result.rows.isEmpty) return;

      final List<StudentRosterItem> newRoster = [];
      for (int i = 0; i < result.rows.length; i++) {
        final row = result.rows[i];
        newRoster.add(StudentRosterItem(
          srNo: i + 1,
          rollNo: row.rollNo,
          name: row.name.isNotEmpty ? row.name : 'Student ${row.rollNo}',
          prn: 'PRN${row.rollNo}',
        ));
      }

      setState(() {
        _repository.roster = newRoster;
        _recalculate();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${newRoster.length} students into Roll Call!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Roster import error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── FACULTY COURSE SELECTION PORTAL (STEP 1: YEAR -> STEP 2: SEMESTER -> STEP 3: COURSE) ───

  Widget _buildCourseSelectionPortal() {
    final availableCourses = _availableCourses;
    final availableSemesters = _availableSemesters;
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "KIT's College of Engineering (Autonomous), Kolhapur",
                    style: AppTypography.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Dept of CSE (Artificial Intelligence & Machine Learning) · NEP Syllabus Framework',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 1,
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.playlist_add_check, size: 18),
            label: const Text('Load Demo Roster'),
            onPressed: _resetToSample,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Header
                  _buildSelectionFlowHero(),
                  const SizedBox(height: 24),

                  // Step 1: Year Selection
                  _buildYearSelectionStep(isMobile),
                  const SizedBox(height: 24),

                  // Step 2: Semester Selection
                  _buildSemesterSelectionStep(availableSemesters),
                  const SizedBox(height: 24),

                  // Step 3: Course Selection
                  _buildCourseSelectionStep(availableCourses, isMobile),
                  const SizedBox(height: 28),

                  // Selected Course Card & Start Action
                  _buildStartMappingCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionFlowHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1F44), Color(0xFF1E3A6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F1F44).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'FACULTY OBE WORKFLOW',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'NEP 2020 Framework',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Select Year and Course to Begin CO-PO Mapping',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select your Academic Year, corresponding Semester, and Course from the autonomous KITCoEK CSE (AIML) syllabus. Once confirmed, the system launches the 5×14 correlation matrix, roll call, and attainment engine.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Flow breadcrumb pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildWorkflowStepBadge('1', 'Year: $_selectedYear', true),
              const Icon(Icons.chevron_right, color: Colors.white60, size: 18),
              _buildWorkflowStepBadge('2', 'Semester: $_selectedSemester', true),
              const Icon(Icons.chevron_right, color: Colors.white60, size: 18),
              _buildWorkflowStepBadge('3', 'Course: ${_selectedCourse.code}', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStepBadge(String num, String text, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: AppColors.secondary,
            child: Text(
              num,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelectionStep(bool isMobile) {
    final years = [
      (
        'F.Y. B.Tech',
        'First Year',
        'Circuit Branches Foundation',
        'Sem I · Sem II',
        Icons.filter_1_rounded,
      ),
      (
        'S.Y. B.Tech',
        'Second Year',
        'AIML Core Fundamentals',
        'Sem III · Sem IV',
        Icons.filter_2_rounded,
      ),
      (
        'T.Y. B.Tech',
        'Third Year',
        'Advanced ML, Vision & NLP',
        'Sem V · Sem VI',
        Icons.filter_3_rounded,
      ),
      (
        'Final Year B.Tech',
        'Fourth Year',
        'GenAI, IoT & Industry Capstone',
        'Sem VII · Sem VIII',
        Icons.filter_4_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('STEP 1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            const Text(
              'Select Academic Year',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const Text('(Mandatory)', style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 800
                ? (constraints.maxWidth - 36) / 4
                : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: years.map((y) {
                final isSelected = _selectedYear == y.$1;
                return SizedBox(
                  width: cardWidth,
                  child: InkWell(
                    onTap: () => _onYearChanged(y.$1),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          else
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  y.$5,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check, color: Colors.white, size: 12),
                                      SizedBox(width: 3),
                                      Text('Active', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            y.$1,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            y.$3,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              y.$4,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Year Selected: $_selectedYear · Next: Choose Semester in Step 2 below ➔',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSemesterSelectionStep(List<String> semesters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('STEP 2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            Text(
              'Select Semester for $_selectedYear',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: semesters.map((sem) {
            final isSelected = _selectedSemester == sem;
            return ChoiceChip(
              label: Text(
                sem,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              onSelected: (selected) {
                if (selected) _onSemesterChanged(sem);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.secondary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Semester Selected: $_selectedSemester · Next: Pick Course in Step 3 below ➔',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.secondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCourseSelectionStep(List<KitCourseInfo> courses, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('STEP 3', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            Text(
              'Select Course (${courses.length} subjects available in $_selectedSemester)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 750
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: courses.map((course) {
                final isSelected = _selectedCourse.code == course.code;
                return SizedBox(
                  width: cardWidth,
                  child: InkWell(
                    onTap: () => _onCourseChanged(course),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.secondary.withOpacity(0.06) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.secondary : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          else
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Radio<String>(
                            value: course.code,
                            groupValue: _selectedCourse.code,
                            activeColor: AppColors.secondary,
                            onChanged: (_) => _onCourseChanged(course),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.secondary : AppColors.primarySoft,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        course.code,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${course.category} · ${course.credits} Credits',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  course.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '5 Defined Course Outcomes (CO1-CO5) · OBE Matrix Ready',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStartMappingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_outlined, color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ready to Begin Course Mapping',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${_selectedCourse.code} · ${_selectedCourse.name} (${_selectedCourse.year}, ${_selectedCourse.semester})',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'Defined Course Outcomes (CO1 to CO5):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          ..._selectedCourse.cos.take(5).map((co) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.success, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    co,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 20),
          // Giant Start Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: Text(
                'Start CO-PO Mapping for ${_selectedCourse.code} ➔',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
              onPressed: () {
                _repository.selectCourse(_selectedCourse);
                _recalculate();
                setState(() {
                  _hasStartedMapping = true;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasStartedMapping) {
      return _buildCourseSelectionPortal();
    }

    final report = _cachedReport ?? _repository.calculateLocalReport();
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CO-PO Attainment Workbench',
              style: AppTypography.h3.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              '${_repository.master.courseCode} · ${_repository.master.courseName}',
              style: AppTypography.caption.copyWith(color: Colors.white.withOpacity(0.85), fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 1,
        actions: [
          Tooltip(
            message: 'Attainment Rules (${_repository.config.directWeightPercent.toInt()}% Direct : ${_repository.config.indirectWeightPercent.toInt()}% Survey · Cutoff ${_repository.config.passingThresholdPercent.toInt()}%)',
            child: IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
              tooltip: 'Attainment Rules (${_repository.config.directWeightPercent.toInt()}/${_repository.config.indirectWeightPercent.toInt()})',
              onPressed: _showAttainmentConfigDialog,
            ),
          ),
          Tooltip(
            message: 'Export Official Attainment PDF Report',
            child: IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 20),
              tooltip: 'Export PDF Report',
              onPressed: () => _exportPdfReport(report),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.school_outlined, color: Colors.white, size: 20),
            tooltip: 'Switch Course / Year',
            onPressed: () {
              setState(() {
                _hasStartedMapping = false;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.functions_rounded, color: Colors.white, size: 20),
            tooltip: 'View CO-PO Formulas & Rules',
            onPressed: _showFormulaGuideDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            tooltip: 'Recalculate Attainment',
            onPressed: _recalculate,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.65),
          indicatorColor: AppColors.secondary,
          indicatorWeight: 3.5,
          tabs: const [
            Tab(icon: Icon(Icons.grid_on, size: 18), text: '1. Master & Matrix'),
            Tab(icon: Icon(Icons.people_outline, size: 18), text: '2. Roll Call'),
            Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: '3. In-Sem (ISE)'),
            Tab(icon: Icon(Icons.quiz_outlined, size: 18), text: '4. Question-wise (MSE/ESE)'),
            Tab(icon: Icon(Icons.rate_review_outlined, size: 18), text: '5. Exit Survey'),
            Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: '6. Attainment Report'),
          ],
        ),
      ),
      bottomNavigationBar: _buildWorkbenchBottomBar(report),
      body: SafeArea(
        child: Column(
          children: [
            // Top Attainment Status Banner
            _buildAttainmentHeroBanner(report),
            // Tab contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMasterMatrixTab(),
                  _buildRollCallTab(),
                  _buildIseTab(report),
                  _buildQuestionWiseTab(report),
                  _buildExitSurveyTab(report),
                  _buildAttainmentReportTab(report),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttainmentHeroBanner(CopoAttainmentReport report) {
    final target = report.master.targetAttainment;
    final overall = report.overallCourseAttainment;
    final isOverallAttained = overall >= target;
    final courses = _availableCourses;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Academic Year & Semester Selectors
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'KITCoEK NEP',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('1. Academic Year: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _selectedYear,
                  isDense: true,
                  underline: const SizedBox(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12.5),
                  items: ['F.Y. B.Tech', 'S.Y. B.Tech', 'T.Y. B.Tech', 'Final Year B.Tech']
                      .map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  onChanged: (y) {
                    if (y != null) _onYearChanged(y);
                  },
                ),
                const SizedBox(width: 18),
                const Text('2. Semester: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _selectedSemester,
                  isDense: true,
                  underline: const SizedBox(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12.5),
                  items: _availableSemesters
                      .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (s) {
                    if (s != null) _onSemesterChanged(s);
                  },
                ),
                const SizedBox(width: 18),
                const Text('3. Course: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _selectedCourse.code,
                  isDense: true,
                  underline: const SizedBox(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 12.5),
                  items: courses.map((c) {
                    return DropdownMenuItem(
                      value: c.code,
                      child: Text(
                        '${c.code} · ${c.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (code) {
                    if (code != null) {
                      final chosen = courses.firstWhere((c) => c.code == code);
                      _onCourseChanged(chosen);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Row 2: Active Mapping Course Status Banner
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      _selectedCourse.code,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedCourse.name,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'KIT\'s College of Engineering (Autonomous) · ${_selectedCourse.semester}',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOverallAttained
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOverallAttained ? AppColors.success : AppColors.error,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOverallAttained ? Icons.check_circle : Icons.warning_amber_rounded,
                          size: 14,
                          color: isOverallAttained ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOverallAttained ? 'ATTAINED' : 'NOT ATTAINED',
                          style: AppTypography.captionBold.copyWith(
                            color: isOverallAttained ? AppColors.success : AppColors.error,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${overall.toStringAsFixed(2)} / 3.00',
                    style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: MASTER SHEET & 5x14 MATRIX ──────────────────────────────────────

  Widget _buildMasterMatrixTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course details card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Course Master Configuration', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      _buildConfigChip('Course Code', _repository.master.courseCode),
                      _buildConfigChip('Course Name', _repository.master.courseName),
                      _buildConfigChip('Semester', _repository.master.semester),
                      _buildConfigChip('Target Level', '${_repository.master.targetAttainment} / 3.00'),
                      _buildConfigChip('CO Count', '5 Course Outcomes (CO1-CO5)'),
                      _buildConfigChip('PO/PSO Columns', '14 (PO1-PO12, PSO1-PSO2)'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5x14 Matrix Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CO-PO & PSO Correlation Matrix (Master)', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Tap any cell to cycle values: 0 (-) → 1 (Low) → 2 (Medium) → 3 (High)', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _repository.matrix = List.generate(5, (_) => List.generate(14, (_) => 0));
                            _recalculate();
                          });
                        },
                        icon: const Icon(Icons.clear, size: 14),
                        label: const Text('Clear Matrix'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildMatrixTable(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildTabStepFooter(0),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildConfigChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.textTertiary, fontSize: 10.5)),
          const SizedBox(height: 2),
          Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMatrixTable() {
    return Table(
      defaultColumnWidth: const FixedColumnWidth(54),
      columnWidths: const {0: FixedColumnWidth(80)},
      border: TableBorder.all(color: AppColors.border, width: 1, borderRadius: BorderRadius.circular(8)),
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(color: AppColors.primarySoft),
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('CO / PO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            for (final po in poColumnNames)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    po,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: po.startsWith('PSO') ? AppColors.secondary : AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Rows CO1 to CO5
        for (int r = 0; r < 5; r++)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('CO${r + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              for (int c = 0; c < 14; c++)
                InkWell(
                  onTap: () {
                    setState(() {
                      _repository.matrix[r][c] = (_repository.matrix[r][c] + 1) % 4;
                      _recalculate();
                    });
                  },
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    color: _getColorForMatrixVal(_repository.matrix[r][c]),
                    child: Text(
                      _repository.matrix[r][c] == 0 ? '-' : '${_repository.matrix[r][c]}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _repository.matrix[r][c] == 0 ? AppColors.textTertiary : Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        // Average Row
        TableRow(
          decoration: BoxDecoration(color: AppColors.surface),
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Avg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
            ),
            for (int c = 0; c < 14; c++)
              Container(
                height: 34,
                alignment: Alignment.center,
                child: Text(
                  _calculateColumnAvg(c).toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                ),
              ),
          ],
        ),
      ],
    );
  }

  double _calculateColumnAvg(int col) {
    double sum = 0.0;
    for (int r = 0; r < 5; r++) {
      sum += _repository.matrix[r][col];
    }
    return sum / 5.0;
  }

  Color _getColorForMatrixVal(int val) {
    switch (val) {
      case 3:
        return const Color(0xFF15803D); // High green
      case 2:
        return const Color(0xFF0284C7); // Medium blue
      case 1:
        return const Color(0xFFD97706); // Low amber
      default:
        return Colors.transparent;
    }
  }

  // ─── TAB 2: ROLL CALL ───────────────────────────────────────────────────────

  Widget _buildRollCallTab() {
    final roster = _repository.roster;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Student Roll Call (${roster.length} enrolled)', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Master student list joined with all exam evaluations via Roll No.', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _handleUploadRoster,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Upload Roll Call (Excel/CSV)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: roster.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final student = roster[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primarySoft,
                    child: Text('${student.srNo}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                  title: Text(student.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Text('Roll No: ${student.rollNo} ${student.prn != null ? "· PRN: ${student.prn}" : ""}'),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildTabStepFooter(1),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ─── TAB 3: IN-SEM EVALUATIONS (ISE 1 & 2) ──────────────────────────────────

  Widget _buildIseTab(CopoAttainmentReport report) {
    final exam = _selectedIseIndex == 0 ? _repository.ise1 : _repository.ise2;
    final stats = _selectedIseIndex == 0 ? report.ise1Stats : report.ise2Stats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('ISE 1 (In-Sem 1)'), icon: Icon(Icons.looks_one)),
                  ButtonSegment(value: 1, label: Text('ISE 2 (In-Sem 2)'), icon: Icon(Icons.looks_two)),
                ],
                selected: {_selectedIseIndex},
                onSelectionChanged: (val) => setState(() => _selectedIseIndex = val.first),
              ),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _handleUploadIseMarks(exam),
                icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                label: Text('Upload ${exam.examType} Marks (Excel/CSV)'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Config row
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text('Mapped Course Outcome: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: exam.mappedCo,
                    underline: const SizedBox(),
                    items: ['CO1', 'CO2', 'CO3', 'CO4', 'CO5'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          exam.mappedCo = val;
                          _recalculate();
                        });
                      }
                    },
                  ),
                  const Spacer(),
                  Text('Max Marks: ${exam.maxMarks.toStringAsFixed(0)}', style: AppTypography.captionBold),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // KPI Stats Cards
          Row(
            children: [
              Expanded(child: _buildKpiCard('Attempted', '${stats.attemptedCount} (${stats.attemptedPercentage}%)', Icons.people_alt_outlined, const Color(0xFF0284C7))),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Scoring >= 50% (5 Marks)', '${stats.scoring50Count} (${stats.scoring50Percentage}%)', Icons.check_circle_outline, const Color(0xFF16A34A))),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Scoring >= 55% (5.5 Marks)', '${stats.scoring55Count} (${stats.scoring55Percentage}%)', Icons.trending_up, const Color(0xFFD97706))),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Attainment Level', 'Level ${stats.attainmentLevel} / 3', Icons.star_border_purple500, const Color(0xFF8B5CF6))),
            ],
          ),
          const SizedBox(height: 20),

          // Marks entry table
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Student Marks (Out of 10) — Manual Entry or Extracted',
                          style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Real-time calculation', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: exam.scores.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final scoreItem = exam.scores[idx];
                    final student = _repository.roster.firstWhere(
                      (s) => s.rollNo == scoreItem.rollNo,
                      orElse: () => StudentRosterItem(srNo: idx + 1, rollNo: scoreItem.rollNo, name: scoreItem.rollNo),
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(width: 80, child: Text(scoreItem.rollNo, style: const TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(child: Text(student.name, style: AppTypography.bodyMedium)),
                          SizedBox(
                            width: 100,
                            height: 36,
                            child: TextFormField(
                              initialValue: scoreItem.marks?.toString() ?? '',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(),
                                hintText: '0-10',
                              ),
                              onChanged: (val) {
                                scoreItem.marks = double.tryParse(val);
                                _recalculate();
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildTabStepFooter(2),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.captionBold.copyWith(color: AppColors.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ─── TAB 4: QUESTION-WISE EXAMS (MSE / ESE) ─────────────────────────────────

  Widget _buildQuestionWiseTab(CopoAttainmentReport report) {
    final exam = _selectedExamIndex == 0 ? _repository.mse : _repository.ese;
    final questionStats = _selectedExamIndex == 0 ? report.mseQuestionStats : report.eseQuestionStats;
    final coLevels = _selectedExamIndex == 0 ? report.mseCoLevels : report.eseCoLevels;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Mid Sem Exam (MSE)'), icon: Icon(Icons.assignment)),
                  ButtonSegment(value: 1, label: Text('End Sem Exam (ESE)'), icon: Icon(Icons.school)),
                ],
                selected: {_selectedExamIndex},
                onSelectionChanged: (val) => setState(() => _selectedExamIndex = val.first),
              ),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _handleUploadQuestionWiseMarks(exam),
                icon: const Icon(Icons.upload_file, size: 16),
                label: Text('Upload ${exam.examType} Sheet (Excel/CSV)'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Per-CO aggregated level summary
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aggregated Attainment Levels per CO for ${exam.examType}', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: coLevels.entries.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${e.key}: Level ${e.value.toStringAsFixed(2)} / 3',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Question statistics grid
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Question-wise Performance & 40/60/80 Attainment Level', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(AppColors.primarySoft),
                      columns: const [
                        DataColumn(label: Text('Question')),
                        DataColumn(label: Text('CO Tag')),
                        DataColumn(label: Text('Max Marks')),
                        DataColumn(label: Text('Attempted %')),
                        DataColumn(label: Text('>= 50% (% Attainment)')),
                        DataColumn(label: Text('>= 55%')),
                        DataColumn(label: Text('Attainment Level')),
                      ],
                      rows: questionStats.map((q) {
                        return DataRow(cells: [
                          DataCell(Text(q.questionId, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Chip(label: Text(q.coTag, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)),
                          DataCell(Text('${q.maxMarks}')),
                          DataCell(Text('${q.stats.attemptedPercentage}%')),
                          DataCell(Text('${q.stats.scoring50Percentage}%')),
                          DataCell(Text('${q.stats.scoring55Percentage}%')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getLevelBadgeColor(q.stats.attainmentLevel),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Level ${q.stats.attainmentLevel}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildTabStepFooter(3),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Color _getLevelBadgeColor(int level) {
    switch (level) {
      case 3:
        return const Color(0xFF16A34A);
      case 2:
        return const Color(0xFF0284C7);
      case 1:
        return const Color(0xFFD97706);
      default:
        return const Color(0xFFDC2626);
    }
  }

  // ─── TAB 5: COURSE EXIT SURVEY (INDIRECT) ───────────────────────────────────

  Widget _buildExitSurveyTab(CopoAttainmentReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Course Exit Survey (Indirect Attainment)', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Weighted average scale 1.0 to 3.0: Strongly Agree = 3, Agree = 2, Neutral = 1. Used in 90/10 direct/indirect calculation.',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          for (final resp in _repository.surveyResponses)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(resp.coId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        children: [
                          _buildSurveyCounter('Strongly Agree (3)', resp.stronglyAgree3, (v) {
                            setState(() {
                              resp.stronglyAgree3 = v;
                              _recalculate();
                            });
                          }),
                          const SizedBox(width: 16),
                          _buildSurveyCounter('Agree (2)', resp.agree2, (v) {
                            setState(() {
                              resp.agree2 = v;
                              _recalculate();
                            });
                          }),
                          const SizedBox(width: 16),
                          _buildSurveyCounter('Neutral (1)', resp.neutral1, (v) {
                            setState(() {
                              resp.neutral1 = v;
                              _recalculate();
                            });
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Indirect Attainment', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                        Text(
                          _getSurveyScore(resp).toStringAsFixed(2),
                          style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          _buildTabStepFooter(4),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  double _getSurveyScore(ExitSurveyCoData resp) {
    final tot = resp.stronglyAgree3 + resp.agree2 + resp.neutral1;
    if (tot == 0) return 2.50;
    return ((resp.stronglyAgree3 * 3) + (resp.agree2 * 2) + (resp.neutral1 * 1)) / tot;
  }

  Widget _buildSurveyCounter(String label, int value, ValueChanged<int> onChanged) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: value > 0 ? () => onChanged(value - 1) : null,
              ),
              Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TAB 6: ATTAINMENT REPORT & PO MATRIX ───────────────────────────────────

  Widget _buildAttainmentReportTab(CopoAttainmentReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── AUDIT REPORT EXPORT & RULES HUB ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'NBA Compliance Audit Report Generator',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Active Rules: Direct ${_repository.config.directWeightPercent.toInt()}% · Survey ${_repository.config.indirectWeightPercent.toInt()}% · Passing Cutoff ${_repository.config.passingThresholdPercent.toInt()}% · Target ${_repository.config.targetBenchmark.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white60),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Configure Calculation %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _showAttainmentConfigDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Colors.white24),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text(
                        'Print / Save as PDF Report 🖨️',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () => _exportPdfReport(report),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.18),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                      label: const Text(
                        'Download HTML Audit Report',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      onPressed: () {
                        CopoPdfService.downloadReportHtml(
                          report: report,
                          config: _repository.config,
                          course: _selectedCourse,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Downloaded standalone HTML audit report file.'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 1: Final CO Attainment Table
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Final Course Outcome (CO) Attainment', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
                      Chip(
                        label: Text('Target: ${_repository.config.targetBenchmark.toStringAsFixed(2)} / 3.00'),
                        backgroundColor: AppColors.primarySoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Formula: Final CO Attainment = (${(_repository.config.directWeightPercent / 100).toStringAsFixed(2)} × Direct) + (${(_repository.config.indirectWeightPercent / 100).toStringAsFixed(2)} × Indirect Survey)',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(AppColors.primarySoft),
                      columns: const [
                        DataColumn(label: Text('CO')),
                        DataColumn(label: Text('ISE 1')),
                        DataColumn(label: Text('ISE 2')),
                        DataColumn(label: Text('MSE Level')),
                        DataColumn(label: Text('ESE Level')),
                        DataColumn(label: Text('Direct (Avg)')),
                        DataColumn(label: Text('Indirect (Survey)')),
                        DataColumn(label: Text('Final Attainment')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: report.coAttainments.map((co) {
                        return DataRow(cells: [
                          DataCell(Text(co.coId, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(co.ise1Level != null ? 'L${co.ise1Level}' : '-')),
                          DataCell(Text(co.ise2Level != null ? 'L${co.ise2Level}' : '-')),
                          DataCell(Text(co.mseLevel != null ? '${co.mseLevel}' : '-')),
                          DataCell(Text(co.eseLevel != null ? '${co.eseLevel}' : '-')),
                          DataCell(Text(co.directAttainment.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(co.indirectAttainment.toStringAsFixed(2))),
                          DataCell(Text(co.finalAttainment.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primary))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: co.isAttained ? AppColors.success.withOpacity(0.15) : AppColors.error.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: co.isAttained ? AppColors.success : AppColors.error),
                              ),
                              child: Text(
                                co.remark,
                                style: TextStyle(
                                  color: co.isAttained ? AppColors.success : AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Program Outcomes (PO1-PO12, PSO1-PSO2) Attainment
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Program Outcomes (PO & PSO) Attainment', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Weighted average calculated via Master Correlation Matrix: PO = ∑(Corr_i × Final_CO_i) / ∑(Corr_i)', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(AppColors.primarySoft),
                      columns: const [
                        DataColumn(label: Text('Outcome')),
                        DataColumn(label: Text('Correlation Sum')),
                        DataColumn(label: Text('Average Corr')),
                        DataColumn(label: Text('PO Attainment')),
                        DataColumn(label: Text('Visual')),
                      ],
                      rows: report.poAttainments.map((po) {
                        final val = po.poAttainment;
                        return DataRow(cells: [
                          DataCell(Text(po.poName, style: TextStyle(fontWeight: FontWeight.bold, color: po.poName.startsWith('PSO') ? AppColors.secondary : AppColors.primary))),
                          DataCell(Text('${po.correlationSum}')),
                          DataCell(Text(po.averageCorrelation.toStringAsFixed(1))),
                          DataCell(
                            Text(
                              val != null ? val.toStringAsFixed(2) : 'Not Mapped',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: val != null ? (val >= report.master.targetAttainment ? AppColors.success : AppColors.textPrimary) : AppColors.textTertiary,
                              ),
                            ),
                          ),
                          DataCell(
                            val != null
                                ? SizedBox(
                                    width: 120,
                                    child: LinearProgressIndicator(
                                      value: (val / 3.0).clamp(0.0, 1.0),
                                      backgroundColor: AppColors.border,
                                      color: val >= report.master.targetAttainment ? AppColors.success : AppColors.secondary,
                                    ),
                                  )
                                : const SizedBox(),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildTabStepFooter(5),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ─── GUIDED STEP FOOTER & BOTTOM NAVIGATION ────────────────────────────────

  Widget _buildTabStepFooter(int currentStep) {
    final hasPrev = currentStep > 0;
    final hasNext = currentStep < 5;
    final prevTitle = hasPrev ? _stepNames[currentStep - 1] : null;
    final nextTitle = hasNext ? _stepNames[currentStep + 1] : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'STAGE ${currentStep + 1} OF 6',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Current Step: ${_stepNames[currentStep]}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              if (hasPrev)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text('Back: $prevTitle', style: const TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () => _goToTab(currentStep - 1),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.school_outlined, size: 18),
                  label: const Text('Change Course / Year'),
                  onPressed: () => setState(() => _hasStartedMapping = false),
                ),
              if (hasNext)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    'Next: $nextTitle ➔',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, letterSpacing: 0.2),
                  ),
                  onPressed: () => _goToTab(currentStep + 1),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text(
                    'Attainment Finalized ✓',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All 6 Stages completed! Attainment report is verified.'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkbenchBottomBar(CopoAttainmentReport report) {
    final currentIndex = _tabController.index;
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex < 5;
    final prevTitle = hasPrev ? _stepNames[currentIndex - 1] : 'Course Selection';
    final nextTitle = hasNext ? _stepNames[currentIndex + 1] : 'Recalculate';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Prev Step
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text(
                    hasPrev ? 'Back' : 'Switch Course',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onPressed: hasPrev
                      ? () => _goToTab(currentIndex - 1)
                      : () => setState(() => _hasStartedMapping = false),
                ),
                const SizedBox(width: 8),
                // Progress dots
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < 6; i++)
                      InkWell(
                        onTap: () => _goToTab(i),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == currentIndex ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == currentIndex
                                ? AppColors.secondary
                                : (i < currentIndex ? AppColors.primary : AppColors.divider),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '${currentIndex + 1}/6',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Next Step
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasNext ? AppColors.secondary : AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(hasNext ? Icons.arrow_forward : Icons.check, size: 16),
                  label: Text(
                    hasNext ? 'Next: Stage ${currentIndex + 2} ➔' : 'Report Ready ✓',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    if (hasNext) {
                      _goToTab(currentIndex + 1);
                    } else {
                      _recalculate();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Attainment report is fully computed across all 6 stages.'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFormulaGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780, maxHeight: 680),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NBA / DBE CO-PO Attainment Mathematical Formulas',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Standard calculations implemented across all 6 stages of this workbench',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormulaCard(
                          title: '1. Single Exam / Question Attainment & KPI',
                          formula: '• Threshold 50% = 0.50 × Max Marks\n• Attempted % = (Attempted Students / Total Strength) × 100\n• % Scoring ≥ 50% = (Count(Marks ≥ Threshold 50%) / Attempted Students) × 100\n• % Scoring ≥ 55% = (Count(Marks ≥ Threshold 55%) / Attempted Students) × 100',
                          description: 'Evaluates percentage of enrolled students who appeared and achieved the benchmark threshold in ISE 1, ISE 2, or individual MSE/ESE questions.',
                          color: const Color(0xFF0284C7),
                        ),
                        const SizedBox(height: 14),
                        _buildFormulaCard(
                          title: '2. NBA 40 / 60 / 80 Attainment Level Rule',
                          formula: '• Level 3 (High): ≥ 80.5% (81-100%) of students scored ≥ 50%\n• Level 2 (Medium): 60.5% to 80.49% (61-80%) of students scored ≥ 50%\n• Level 1 (Low): 39.5% to 60.49% (40-60%) of students scored ≥ 50%\n• Level 0 (Unattained): < 39.5% of students scored ≥ 50%',
                          description: 'Standard 40/60/80 rubric buckets percentages into discrete academic attainment levels from 0 to 3.',
                          color: const Color(0xFF16A34A),
                        ),
                        const SizedBox(height: 14),
                        _buildFormulaCard(
                          title: '3. MSE & ESE Question-wise CO Level',
                          formula: '• Question Level = Map40_60_80(% Scoring ≥ 50% in Question)\n• Exam CO Level = ∑ (Levels of Questions mapped to CO) / Count(Questions for CO)',
                          description: 'Averages the attainment levels of all specific questions mapped to a particular Course Outcome in MSE or ESE.',
                          color: const Color(0xFF7C3AED),
                        ),
                        const SizedBox(height: 14),
                        _buildFormulaCard(
                          title: '4. Course Exit Survey (Indirect Attainment)',
                          formula: '• Weights: Strongly Agree = 3, Agree = 2, Neutral = 1\n• Indirect Attainment(CO) = (3 × SA + 2 × A + 1 × N) / (SA + A + N)',
                          description: 'Quantifies qualitative student perception on a normalized 1.00 to 3.00 scale for each Course Outcome.',
                          color: const Color(0xFFD97706),
                        ),
                        const SizedBox(height: 14),
                        _buildFormulaCard(
                          title: '5. Direct Attainment per CO',
                          formula: '• Direct Attainment(CO) = Average of applicable [ISE 1, ISE 2, MSE Level, ESE Level]',
                          description: 'Aggregates all direct in-semester and end-semester assessments that tested that specific CO.',
                          color: const Color(0xFF0891B2),
                        ),
                        const SizedBox(height: 14),
                        _buildFormulaCard(
                          title: '6. Final CO Attainment & Target Benchmark',
                          formula: '• Final CO Attainment = (0.90 × Direct Attainment) + (0.10 × Indirect Survey)\n• Status: ATTAINED if Final Attainment ≥ Target Level (e.g., 2.50), else NOT ATTAINED\n• Overall Course Attainment = ∑ Final CO Attainment (CO1..CO5) / 5',
                          description: 'Applies standard 90% direct evaluation + 10% indirect survey weighting.',
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 14),
                        _buildFormulaCard(
                          title: '7. Program Outcome (PO & PSO) Attainment',
                          formula: '• Correlation Sum = ∑ (Correlation_i) for i = 1..5\n• If Correlation Sum > 0:\n    PO Attainment = ∑ (Correlation_i × Final CO Attainment_i) / Correlation Sum\n• If Correlation Sum == 0:\n    Not Mapped (N/A)',
                          description: 'Correlation weights (1: Low, 2: Medium, 3: High) from the master matrix weigh each CO’s final attainment to determine institutional PO attainment.',
                          color: const Color(0xFFBE185D),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Got it!'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormulaCard({
    required String title,
    required String formula,
    required String description,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border.withOpacity(0.5)),
            ),
            child: Text(
              formula,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }

  // ─── DYNAMIC ATTAINMENT CALCULATION RULES MODAL ────────────────────────────

  void _showAttainmentConfigDialog() {
    final currentCfg = _repository.config;
    double passingCutoff = currentCfg.passingThresholdPercent;
    double directWeight = currentCfg.directWeightPercent;
    double indirectWeight = currentCfg.indirectWeightPercent;
    double level3 = currentCfg.level3CutoffPercent;
    double level2 = currentCfg.level2CutoffPercent;
    double level1 = currentCfg.level1CutoffPercent;
    double target = currentCfg.targetBenchmark;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dynamic Attainment Rules & Calculation %',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Faculty customizable passing cutoff, direct/indirect weighting & rubric cutoffs',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Student Passing Threshold
                            _buildConfigSectionTitle('1. Student Passing Cutoff (% of Max Marks)', 'Students scoring ≥ this % are counted as benchmark achievers.'),
                            const SizedBox(height: 8),
                            Row(
                              children: [40.0, 50.0, 55.0, 60.0].map((val) {
                                final isSelected = (passingCutoff - val).abs() < 0.5;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text('${val.toInt()}% Cutoff'),
                                    selected: isSelected,
                                    selectedColor: AppColors.primarySoft,
                                    labelStyle: TextStyle(
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    onSelected: (sel) {
                                      if (sel) setDialogState(() => passingCutoff = val);
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                            Slider(
                              value: passingCutoff,
                              min: 30.0,
                              max: 75.0,
                              divisions: 9,
                              label: '${passingCutoff.toInt()}%',
                              activeColor: AppColors.primary,
                              onChanged: (v) => setDialogState(() => passingCutoff = v),
                            ),
                            const SizedBox(height: 16),

                            // 2. Direct vs Indirect Split
                            _buildConfigSectionTitle('2. Direct Assessment vs. Indirect Exit Survey Split', 'Standard Autonomous institutes use 90:10 or 80:20.'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: directWeight == 90.0 ? AppColors.primarySoft : null,
                                      side: BorderSide(color: directWeight == 90.0 ? AppColors.primary : AppColors.border),
                                    ),
                                    onPressed: () => setDialogState(() {
                                      directWeight = 90.0;
                                      indirectWeight = 10.0;
                                    }),
                                    child: const Text('90% Direct : 10% Survey', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: directWeight == 80.0 ? AppColors.primarySoft : null,
                                      side: BorderSide(color: directWeight == 80.0 ? AppColors.primary : AppColors.border),
                                    ),
                                    onPressed: () => setDialogState(() {
                                      directWeight = 80.0;
                                      indirectWeight = 20.0;
                                    }),
                                    child: const Text('80% Direct : 20% Survey', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Active Split: Direct ${directWeight.toInt()}%  ·  Survey ${indirectWeight.toInt()}%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            Slider(
                              value: directWeight,
                              min: 60.0,
                              max: 100.0,
                              divisions: 8,
                              label: '${directWeight.toInt()}% Direct',
                              activeColor: AppColors.secondary,
                              onChanged: (v) => setDialogState(() {
                                directWeight = v;
                                indirectWeight = 100.0 - v;
                              }),
                            ),
                            const SizedBox(height: 16),

                            // 3. Target Attainment Benchmark
                            _buildConfigSectionTitle('3. NBA Target Attainment Benchmark', 'Target performance score on a 1.00 to 3.00 scale (e.g., 2.50).'),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: target,
                                    min: 1.50,
                                    max: 3.00,
                                    divisions: 15,
                                    label: target.toStringAsFixed(2),
                                    activeColor: AppColors.success,
                                    onChanged: (v) => setDialogState(() => target = double.parse(v.toStringAsFixed(2))),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${target.toStringAsFixed(2)} / 3.00',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 4. Live Formula Summary Preview
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified, color: AppColors.secondary, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Active Formula: Final CO = (${(directWeight / 100).toStringAsFixed(2)} × Direct) + (${(indirectWeight / 100).toStringAsFixed(2)} × Survey)\nPassing Benchmark: ${passingCutoff.toInt()}% of Max Marks · Target: ${target.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                passingCutoff = 50.0;
                                directWeight = 90.0;
                                indirectWeight = 10.0;
                                target = 2.50;
                              });
                            },
                            child: const Text('Reset Defaults'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Apply & Recalculate Now', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              final newConfig = AttainmentConfig(
                                passingThresholdPercent: passingCutoff,
                                directWeightPercent: directWeight,
                                indirectWeightPercent: indirectWeight,
                                level3CutoffPercent: level3,
                                level2CutoffPercent: level2,
                                level1CutoffPercent: level1,
                                targetBenchmark: target,
                              );
                              _repository.updateConfig(newConfig);
                              _recalculate();
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Attainment Rules Updated: Direct ${directWeight.toInt()}%, Survey ${indirectWeight.toInt()}%, Cutoff ${passingCutoff.toInt()}%. Recalculated!'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConfigSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary)),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  void _exportPdfReport(CopoAttainmentReport report) {
    CopoPdfService.generateAndOpenReportPdf(
      report: report,
      config: _repository.config,
      course: _selectedCourse,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening printable CO-PO Attainment Report. Use "Print / Save as PDF" in your browser.'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
