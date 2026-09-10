import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/student_portal_assessment.dart';
import '../../data/services/sli_service.dart';

/// Clean, token-driven Student Assessment Portal.
/// No student login, no roster dropdown.
/// Students enter their Full Name, Roll Number/PRN, and Division,
/// answer dynamic subject questions, and submit directly.
class StudentAssessmentPortalScreen extends StatefulWidget {
  final String? initialToken;

  const StudentAssessmentPortalScreen({
    super.key,
    this.initialToken,
  });

  @override
  State<StudentAssessmentPortalScreen> createState() => _StudentAssessmentPortalScreenState();
}

class _StudentAssessmentPortalScreenState extends State<StudentAssessmentPortalScreen> {
  final SliService _sliService = SliService();
  final TextEditingController _tokenController = TextEditingController();

  // Student Identity Intake Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollNoController = TextEditingController();
  final TextEditingController _divisionController = TextEditingController();

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  StudentPortalAssessment? _portalData;
  bool _isSubmittedSuccess = false;
  String? _submittedMessage;

  // PRE Form State
  int _subjectInterest = 4;
  int _selfAssessedSkill = 3;
  int _learningConfidence = 4;
  int _expectedDifficulty = 3;
  String _preferredFormat = 'PRACTICAL_LABS';
  final TextEditingController _skillsToImproveController = TextEditingController();
  final Map<int, Map<String, int>> _topicRatings = {};
  final Map<String, int> _dynamicRatings = {};

  // MID Form State
  int _currentConfidence = 4;
  int _currentInterest = 4;
  int _understandingLevel = 4;
  int _learningSatisfaction = 4;
  String _usefulFormat = 'PRACTICAL_LABS';
  String _teachingPace = 'JUST_RIGHT';
  final Set<String> _selectedBarriers = {};
  final Map<int, String> _midTopicProgress = {};

  // END Form State
  int _finalConfidence = 5;
  int _finalInterest = 5;
  int _coreConceptsMastery = 5;
  int _problemSolvingAbility = 4;
  int _practicalLabCompetence = 5;
  int _independentLearningAbility = 4;
  int _realWorldApplication = 5;
  String _effectiveFormat = 'HYBRID';
  int _overallLearningExperience = 5;

  static const List<Map<String, String>> _availableBarriers = [
    {'value': 'CONCEPTUAL_DIFFICULTY', 'label': 'Conceptual Difficulty'},
    {'value': 'LACK_OF_PRACTICE', 'label': 'Lack of Practice'},
    {'value': 'TIME_MANAGEMENT', 'label': 'Time Management'},
    {'value': 'PREREQUISITE_GAP', 'label': 'Prerequisite Gap'},
    {'value': 'TEACHING_PACE', 'label': 'Pace of Delivery'},
    {'value': 'LIMITED_LAB_EXPOSURE', 'label': 'Limited Lab Hands-On'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      _tokenController.text = widget.initialToken!;
      _loadAssessment(widget.initialToken!);
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _nameController.dispose();
    _rollNoController.dispose();
    _divisionController.dispose();
    _skillsToImproveController.dispose();
    super.dispose();
  }

  Future<void> _loadAssessment(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSubmittedSuccess = false;
    });

    try {
      final data = await _sliService.getStudentAssessmentPortal(cleanToken);
      if (!mounted) return;
      setState(() {
        _portalData = data;
        _isLoading = false;
        if (_divisionController.text.isEmpty && data.expectedDivision.isNotEmpty) {
          _divisionController.text = data.expectedDivision;
        }
        _initTopicRatings(data);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _initTopicRatings(StudentPortalAssessment data) {
    _topicRatings.clear();
    _midTopicProgress.clear();
    _dynamicRatings.clear();

    // 1. Initialize from topics array if provided
    for (final t in data.topics) {
      if (t is Map && t['topic_id'] != null) {
        final tId = int.tryParse(t['topic_id'].toString()) ?? 0;
        if (tId > 0) {
          _topicRatings[tId] = {'confidence': 3, 'difficulty': 3};
          _midTopicProgress[tId] = 'COMPLETED';
        }
      }
    }

    // 2. Initialize from questions list
    for (int i = 0; i < data.questions.length; i++) {
      final q = data.questions[i];
      if (q is Map) {
        final qId = q['question_id']?.toString() ?? 'Q_${i + 1}';
        final dim = (q['dimension'] as String?)?.toLowerCase() ?? '';
        final defaultScore = (dim == 'perceived_difficulty') ? 3 : 4;
        _dynamicRatings[qId] = defaultScore;

        // Register topic ID if present
        if (q['topic_id'] != null) {
          final tId = int.tryParse(q['topic_id'].toString()) ?? 0;
          if (tId > 0) {
            _topicRatings.putIfAbsent(tId, () => {'confidence': 3, 'difficulty': 3});
            _midTopicProgress.putIfAbsent(tId, () => 'COMPLETED');
            if (dim == 'perceived_difficulty') {
              _topicRatings[tId]!['difficulty'] = defaultScore;
            } else if (dim == 'self_reported_confidence') {
              _topicRatings[tId]!['confidence'] = defaultScore;
            }
          }
        }

        if (q['topics'] is List) {
          for (final t in q['topics']) {
            if (t is Map && t['topic_id'] != null) {
              final tId = int.tryParse(t['topic_id'].toString()) ?? 0;
              if (tId > 0) {
                _topicRatings.putIfAbsent(tId, () => {'confidence': 3, 'difficulty': 3});
                _midTopicProgress.putIfAbsent(tId, () => 'COMPLETED');
              }
            }
          }
        }
      }
    }
  }

  String _normalizeDiv(String str) {
    return str
        .toUpperCase()
        .replaceAll(RegExp(r'\b(DIVISION|DIV|YEAR|SEMESTER|SEM|TY|SY|FY)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .trim();
  }

  Future<void> _submitAssessment() async {
    if (_portalData == null) return;

    final name = _nameController.text.trim();
    final rollNo = _rollNoController.text.trim();
    final divEntered = _divisionController.text.trim();

    if (name.isEmpty || rollNo.isEmpty || divEntered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Full Name, Roll Number, and Division.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Client-side division check
      final expDiv = _normalizeDiv(_portalData!.expectedDivision);
      final entDiv = _normalizeDiv(divEntered);
      if (expDiv.isNotEmpty && entDiv.isNotEmpty && expDiv != entDiv) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Division mismatch: This assessment is for Division "${_portalData!.expectedDivision}", but you entered "$divEntered".'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });
      final Map<String, dynamic> payload = {
        'student_id': rollNo,
        'full_name': name,
        'division_code': divEntered,
      };
      final type = _portalData!.assessmentType;

      if (type == 'PRE') {
        payload.addAll({
          'subject_interest': _subjectInterest,
          'self_assessed_skill': _selfAssessedSkill,
          'learning_confidence': _learningConfidence,
          'expected_difficulty': _expectedDifficulty,
          'preferred_learning_format': _preferredFormat,
          'skills_to_improve': _skillsToImproveController.text.trim().isNotEmpty
              ? _skillsToImproveController.text.trim()
              : 'Core fundamentals',
          'topic_feedback': _topicRatings.entries.map((e) => {
            'topic_id': e.key,
            'confidence_level': e.value['confidence'] ?? 3,
            'difficulty_level': e.value['difficulty'] ?? 3,
          }).toList(),
        });
      } else if (type == 'MID') {
        payload.addAll({
          'current_confidence': _currentConfidence,
          'current_interest': _currentInterest,
          'understanding_level': _understandingLevel,
          'learning_satisfaction': _learningSatisfaction,
          'useful_learning_format': _usefulFormat,
          'teaching_pace': _teachingPace,
          'learning_barriers': _selectedBarriers.toList(),
          'skills_progress': [
            {'skill_name': 'Core Syllabus Concepts', 'confidence_level': _currentConfidence, 'progress_status': 'IMPROVED'},
          ],
          'topic_feedback': _topicRatings.entries.map((e) => {
            'topic_id': e.key,
            'confidence_level': e.value['confidence'] ?? 4,
            'difficulty_level': e.value['difficulty'] ?? 3,
            'progress_status': _midTopicProgress[e.key] ?? 'COMPLETED',
          }).toList(),
        });
      } else if (type == 'END') {
        payload.addAll({
          'final_confidence': _finalConfidence,
          'final_interest': _finalInterest,
          'understanding_level': _coreConceptsMastery,
          'core_concepts_mastery': _coreConceptsMastery,
          'problem_solving_ability': _problemSolvingAbility,
          'practical_lab_competence': _practicalLabCompetence,
          'independent_learning_ability': _independentLearningAbility,
          'real_world_application': _realWorldApplication,
          'effective_learning_format': _effectiveFormat,
          'overall_learning_experience': _overallLearningExperience,
          'skills_progress': [
            {'skill_name': 'Comprehensive Course Attainment', 'confidence_level': _finalConfidence, 'progress_status': 'MASTERED'},
          ],
          'topic_feedback': _topicRatings.entries.map((e) => {
            'topic_id': e.key,
            'confidence_level': _finalConfidence,
            'difficulty_level': 2,
            'progress_status': 'COMPLETED',
          }).toList(),
        });
      }

      if (_dynamicRatings.isNotEmpty) {
        payload['question_responses'] = _dynamicRatings;
      }

      final res = await _sliService.submitStudentAssessment(
        accessToken: _portalData!.accessToken,
        payload: payload,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSubmittedSuccess = true;
        _submittedMessage = res['message'] as String? ?? 'Assessment submitted successfully!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? 'Submission failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Student Assessment Form',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Token Entry Card (if opened without token)
            if (_portalData == null && !_isLoading) _buildTokenEntryCard(),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: LoadingIndicator(size: 40)),
              ),

            if (_errorMessage != null && _portalData == null)
              Card(
                elevation: 0,
                color: AppColors.error.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.error),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isSubmittedSuccess)
              _buildSuccessCard()
            else if (_portalData != null && !_isLoading)
              _buildAssessmentForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenEntryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Assessment Access Code',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Paste the assessment access code or link token provided by your course faculty.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                hintText: 'e.g. gO_m5qLz4b8Wv1...',
                prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Open Assessment'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _loadAssessment(_tokenController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.success),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded, size: 56, color: AppColors.success),
            const SizedBox(height: 16),
            const Text(
              'Assessment Submitted Successfully!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _submittedMessage ?? 'Your responses have been recorded and integrated into the Student Learning Intelligence analytics.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Student Name:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(_nameController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Roll / PRN:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(_rollNoController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subject:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(_portalData?.subjectName ?? 'Course', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentForm() {
    final data = _portalData!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Course & Assessment Header Banner
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${data.assessmentType} SEMESTER ASSESSMENT',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                      ),
                    ),
                    Text(
                      '${data.questions.length} Questions',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  data.subjectName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${data.className} • Division ${data.divisionName} • ${data.academicYear}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Step 1: Student Details Intake Card (No login required)
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Step 1: Student Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your institutional credentials. Your response will automatically register into the course analytics.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'Enter your full name',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _rollNoController,
                        decoration: InputDecoration(
                          labelText: 'Roll No / PRN *',
                          hintText: 'e.g. 2023CSE001',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _divisionController,
                        decoration: InputDecoration(
                          labelText: 'Division *',
                          hintText: 'e.g. ${data.expectedDivision}',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Step 2: Assessment Questions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Step 2: Course Assessment Questions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${data.questions.length} Questions',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        if (data.questions.isNotEmpty)
          _buildDynamicQuestionsList(data)
        else if (data.assessmentType == 'PRE')
          _buildPreAssessmentQuestions(data)
        else if (data.assessmentType == 'MID')
          _buildMidAssessmentQuestions(data)
        else
          _buildEndAssessmentQuestions(data),

        const SizedBox(height: 20),

        // Submit Button
        ElevatedButton.icon(
          icon: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(
            _isSubmitting ? 'Submitting Responses...' : 'Submit Assessment',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isSubmitting ? null : _submitAssessment,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  void _onDynamicRatingChanged(Map<String, dynamic> q, String qId, int score) {
    setState(() {
      _dynamicRatings[qId] = score;

      final dim = (q['dimension'] as String?)?.toLowerCase() ?? '';
      final tId = q['topic_id'] != null ? int.tryParse(q['topic_id'].toString()) : null;

      if (tId != null && tId > 0) {
        _topicRatings.putIfAbsent(tId, () => {'confidence': 3, 'difficulty': 3});
        if (dim == 'perceived_difficulty') {
          _topicRatings[tId]!['difficulty'] = score;
        } else {
          _topicRatings[tId]!['confidence'] = score;
        }
      }

      if (dim == 'self_reported_confidence') {
        _selfAssessedSkill = score;
        _learningConfidence = score;
      } else if (dim == 'application_ability') {
        _coreConceptsMastery = score;
        _practicalLabCompetence = score;
      } else if (dim == 'perceived_difficulty') {
        _expectedDifficulty = score;
      } else if (dim == 'overall_confidence') {
        _subjectInterest = score;
        _learningConfidence = score;
        _currentConfidence = score;
        _finalConfidence = score;
      } else if (dim == 'problem_solving') {
        _problemSolvingAbility = score;
      } else if (dim == 'independent_learning') {
        _independentLearningAbility = score;
      } else if (dim == 'barrier_frequency') {
        _understandingLevel = (6 - score).clamp(1, 5);
      } else if (dim == 'learning_pace') {
        if (score <= 2) {
          _teachingPace = 'TOO_SLOW';
        } else if (score >= 4) {
          _teachingPace = 'TOO_FAST';
        } else {
          _teachingPace = 'JUST_RIGHT';
        }
      }
    });
  }

  Widget _buildDynamicQuestionsList(StudentPortalAssessment data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(data.questions.length, (index) {
        final q = data.questions[index] as Map<String, dynamic>;
        final qId = q['question_id']?.toString() ?? 'Q_${index + 1}';
        final title = q['title'] ?? q['section'] ?? 'Question ${index + 1}';
        final description = q['description'] ?? q['prompt'] ?? '';
        final section = q['section'] as String?;
        final type = (q['type'] as String?)?.toUpperCase() ?? 'LIKERT_1_5';
        final dim = (q['dimension'] as String?)?.toLowerCase() ?? '';

        if (type == 'BARRIERS_AND_SKILLS' || dim == 'learning_barriers') {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildDynamicBarriersCard(
              qIndex: index + 1,
              title: title,
              description: description,
              section: section,
            ),
          );
        }

        if (type == 'PEDAGOGY' || dim == 'learning_pace') {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildDynamicPacingCard(
              qIndex: index + 1,
              qId: qId,
              q: q,
              title: title,
              description: description,
              section: section,
            ),
          );
        }

        if (type == 'PREFERENCES' || dim == 'required_support') {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildDynamicPreferencesCard(
              qIndex: index + 1,
              title: title,
              description: description,
              section: section,
            ),
          );
        }

        String minLabel = '1 = Low';
        String maxLabel = '5 = High';
        if (dim == 'perceived_difficulty') {
          minLabel = '1 = Very Easy';
          maxLabel = '5 = Very Challenging';
        } else if (dim == 'self_reported_confidence' || dim == 'overall_confidence') {
          minLabel = '1 = Low Confidence';
          maxLabel = '5 = High Mastery';
        } else if (dim == 'application_ability') {
          minLabel = '1 = Novice / Basic';
          maxLabel = '5 = Practical Problem Solver';
        } else if (dim == 'problem_solving') {
          minLabel = '1 = Need Guidance';
          maxLabel = '5 = Autonomous Problem Solver';
        } else if (dim == 'independent_learning') {
          minLabel = '1 = Dependent';
          maxLabel = '5 = Self-Directed';
        } else if (dim == 'barrier_frequency') {
          minLabel = '1 = Rarely / Never';
          maxLabel = '5 = Persistent / Frequent';
        }

        final currentScore = _dynamicRatings[qId] ?? 4;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildDynamicLikertCard(
            qIndex: index + 1,
            title: title,
            description: description,
            section: section,
            value: currentScore,
            minLabel: minLabel,
            maxLabel: maxLabel,
            onChanged: (score) => _onDynamicRatingChanged(q, qId, score),
          ),
        );
      }),
    );
  }

  Widget _buildDynamicLikertCard({
    required int qIndex,
    required String title,
    required String description,
    String? section,
    required int value,
    required ValueChanged<int> onChanged,
    required String minLabel,
    required String maxLabel,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q$qIndex',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (section != null && section.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                final score = index + 1;
                final isSelected = value == score;
                return InkWell(
                  onTap: () => onChanged(score),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 46,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$score',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(minLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                Text(maxLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicBarriersCard({
    required int qIndex,
    required String title,
    required String description,
    String? section,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q$qIndex',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (section != null && section.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _availableBarriers.map((b) {
                final isSelected = _selectedBarriers.contains(b['value']);
                return FilterChip(
                  label: Text(b['label'] ?? '', style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _selectedBarriers.add(b['value']!);
                      } else {
                        _selectedBarriers.remove(b['value']!);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicPacingCard({
    required int qIndex,
    required String qId,
    required Map<String, dynamic> q,
    required String title,
    required String description,
    String? section,
  }) {
    final paceOptions = [
      {'val': 'TOO_SLOW', 'label': 'Too Slow', 'score': 1},
      {'val': 'JUST_RIGHT', 'label': 'Just Right / Well-Paced', 'score': 3},
      {'val': 'TOO_FAST', 'label': 'Too Fast', 'score': 5},
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q$qIndex',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (section != null && section.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: paceOptions.map((opt) {
                final isSelected = _teachingPace == opt['val'];
                return ChoiceChip(
                  label: Text(
                    opt['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _teachingPace = opt['val'] as String;
                        _dynamicRatings[qId] = opt['score'] as int;
                      });
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicPreferencesCard({
    required int qIndex,
    required String title,
    required String description,
    String? section,
  }) {
    final formats = [
      {'val': 'PRACTICAL_LABS', 'label': 'Practical Labs'},
      {'val': 'RECORDED_VIDEOS', 'label': 'Recorded Videos'},
      {'val': 'INTERACTIVE_SESSIONS', 'label': 'Interactive Sessions'},
      {'val': 'READING_MATERIAL', 'label': 'Reading Materials'},
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q$qIndex',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (section != null && section.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 12),
            const Text(
              'Preferred Learning Format:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: formats.map((fmt) {
                final isSelected = _preferredFormat == fmt['val'];
                return ChoiceChip(
                  label: Text(
                    fmt['label']!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _preferredFormat = fmt['val']!;
                        _usefulFormat = fmt['val']!;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Target Skills or Support Needed:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _skillsToImproveController,
              decoration: InputDecoration(
                hintText: 'e.g. Code walkthroughs, lab mentoring, practice exercises',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreAssessmentQuestions(StudentPortalAssessment data) {
    return Column(
      children: [
        _buildLikertCard(
          title: 'Q1: Fundamental Prerequisite Familiarity',
          description: 'How familiar are you with prerequisite concepts for ${data.subjectName}?',
          value: _selfAssessedSkill,
          onChanged: (v) => setState(() => _selfAssessedSkill = v),
          minLabel: '1 = Beginner',
          maxLabel: '5 = Advanced',
        ),
        const SizedBox(height: 12),
        _buildLikertCard(
          title: 'Q2: Course Interest & Enthusiasm',
          description: 'Rate your personal interest in learning this subject.',
          value: _subjectInterest,
          onChanged: (v) => setState(() => _subjectInterest = v),
          minLabel: '1 = Low Interest',
          maxLabel: '5 = High Interest',
        ),
        const SizedBox(height: 12),
        _buildLikertCard(
          title: 'Q3: Expected Learning Confidence',
          description: 'How confident do you feel about mastering the course syllabus?',
          value: _learningConfidence,
          onChanged: (v) => setState(() => _learningConfidence = v),
          minLabel: '1 = Very Low',
          maxLabel: '5 = High Confidence',
        ),
        const SizedBox(height: 12),
        _buildTopicRatingMatrixCard(data),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Q5: Target Skills to Improve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _skillsToImproveController,
                  decoration: InputDecoration(
                    hintText: 'e.g. SQL Query Optimization, Indexing, Normalization',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMidAssessmentQuestions(StudentPortalAssessment data) {
    return Column(
      children: [
        _buildLikertCard(
          title: 'Q1: Mid-Semester Conceptual Grasp',
          description: 'How well do you understand the ${data.subjectName} principles covered so far?',
          value: _understandingLevel,
          onChanged: (v) => setState(() => _understandingLevel = v),
          minLabel: '1 = Struggling',
          maxLabel: '5 = Clear Grasp',
        ),
        const SizedBox(height: 12),
        _buildLikertCard(
          title: 'Q2: Course Satisfaction & Progression',
          description: 'Rate your satisfaction with your learning progress in this course.',
          value: _learningSatisfaction,
          onChanged: (v) => setState(() => _learningSatisfaction = v),
          minLabel: '1 = Unsatisfied',
          maxLabel: '5 = Highly Satisfied',
        ),
        const SizedBox(height: 12),
        _buildBarriersCard(),
        const SizedBox(height: 12),
        _buildTopicRatingMatrixCard(data),
      ],
    );
  }

  Widget _buildEndAssessmentQuestions(StudentPortalAssessment data) {
    return Column(
      children: [
        _buildLikertCard(
          title: 'Q1: Final Course Mastery',
          description: 'Rate your comprehensive mastery of ${data.subjectName} theory and practice.',
          value: _coreConceptsMastery,
          onChanged: (v) => setState(() => _coreConceptsMastery = v),
          minLabel: '1 = Basic',
          maxLabel: '5 = Complete Mastery',
        ),
        const SizedBox(height: 12),
        _buildLikertCard(
          title: 'Q2: Problem Solving & Analytical Competence',
          description: 'How confident are you in independently solving complex technical problems?',
          value: _problemSolvingAbility,
          onChanged: (v) => setState(() => _problemSolvingAbility = v),
          minLabel: '1 = Low',
          maxLabel: '5 = High Competence',
        ),
        const SizedBox(height: 12),
        _buildLikertCard(
          title: 'Q3: Practical Lab & Real-World Application',
          description: 'Rate your hands-on laboratory and practical project implementation ability.',
          value: _practicalLabCompetence,
          onChanged: (v) => setState(() => _practicalLabCompetence = v),
          minLabel: '1 = Novice',
          maxLabel: '5 = Industry Ready',
        ),
        const SizedBox(height: 12),
        _buildLikertCard(
          title: 'Q4: Overall Learning Experience',
          description: 'Retrospective rating of course quality, resources, and instructional pace.',
          value: _overallLearningExperience,
          onChanged: (v) => setState(() => _overallLearningExperience = v),
          minLabel: '1 = Poor',
          maxLabel: '5 = Outstanding',
        ),
      ],
    );
  }

  Widget _buildLikertCard({
    required String title,
    required String description,
    required int value,
    required ValueChanged<int> onChanged,
    required String minLabel,
    required String maxLabel,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                final score = index + 1;
                final isSelected = value == score;
                return InkWell(
                  onTap: () => onChanged(score),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 46,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$score',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(minLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                Text(maxLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarriersCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Q3: Learning Challenges & Barriers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Select any learning hurdles you are currently experiencing:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _availableBarriers.map((b) {
                final isSelected = _selectedBarriers.contains(b['value']);
                return FilterChip(
                  label: Text(b['label'] ?? '', style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _selectedBarriers.add(b['value']!);
                      } else {
                        _selectedBarriers.remove(b['value']!);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicRatingMatrixCard(StudentPortalAssessment data) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Topic Baseline & Comprehension Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Rate your confidence (1 to 5) for each subject topic:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ..._topicRatings.entries.map((entry) {
              final topicId = entry.key;
              final score = entry.value['confidence'] ?? 3;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Topic #$topicId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                    Row(
                      children: List.generate(5, (idx) {
                        final val = idx + 1;
                        final isSel = score == val;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _topicRatings[topicId]?['confidence'] = val;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 32,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.primary : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$val',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
