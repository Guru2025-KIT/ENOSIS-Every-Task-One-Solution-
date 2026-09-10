import 'package:flutter/material.dart';
import '../../data/models/end_assessment_form.dart';
import '../../data/models/end_assessment_submission.dart';
import '../../data/models/faculty_teaching_context.dart';
import '../../data/models/student_roster_item.dart';
import '../../data/services/sli_service.dart';

/// Provider managing the state of the END-Semester Assessment workflow.
class SliEndProvider extends ChangeNotifier {
  final SliService _service;

  SliEndProvider({SliService? service}) : _service = service ?? SliService();

  // ─── Teaching Contexts State ──────────────────────────────────────────────
  List<FacultyTeachingContext> _contexts = [];
  bool _isLoadingContexts = false;
  String? _contextError;
  FacultyTeachingContext? _selectedContext;

  List<FacultyTeachingContext> get contexts => _contexts;
  bool get isLoadingContexts => _isLoadingContexts;
  String? get contextError => _contextError;
  FacultyTeachingContext? get selectedContext => _selectedContext;

  // ─── Student Roster State ────────────────────────────────────────────────
  List<StudentRosterItem> _roster = [];
  bool _isLoadingRoster = false;
  String? _rosterError;
  StudentRosterItem? _selectedStudent;

  List<StudentRosterItem> get roster => _roster;
  bool get isLoadingRoster => _isLoadingRoster;
  String? get rosterError => _rosterError;
  StudentRosterItem? get selectedStudent => _selectedStudent;

  // ─── Form & Assessment Draft State ───────────────────────────────────────
  EndAssessmentForm? _form;
  bool _isLoadingForm = false;
  String? _formError;
  int _currentStep = 0; // 0 to 5
  bool _isSubmitting = false;
  String? _submissionError;
  EndAssessmentSubmissionResponse? _lastSubmissionResponse;

  EndAssessmentForm? get form => _form;
  bool get isLoadingForm => _isLoadingForm;
  String? get formError => _formError;
  int get currentStep => _currentStep;
  bool get isSubmitting => _isSubmitting;
  String? get submissionError => _submissionError;
  EndAssessmentSubmissionResponse? get lastSubmissionResponse => _lastSubmissionResponse;

  // ─── Teaching Contexts Operations ────────────────────────────────────────

  Future<void> fetchTeachingContexts() async {
    _isLoadingContexts = true;
    _contextError = null;
    notifyListeners();

    try {
      _contexts = await _service.getTeachingContexts();
    } catch (e) {
      _contextError = e.toString();
    } finally {
      _isLoadingContexts = false;
      notifyListeners();
    }
  }

  void selectContext(FacultyTeachingContext context) {
    _selectedContext = context;
    notifyListeners();
    fetchRosterForSelectedContext();
  }

  // ─── Roster Operations ───────────────────────────────────────────────────

  Future<void> fetchRosterForSelectedContext() async {
    if (_selectedContext == null) return;

    final classId = _selectedContext!.classId;
    final subjectId = _selectedContext!.subjectId;
    final semesterId = _selectedContext!.semesterId;

    if (classId == null || semesterId == null) {
      _rosterError = 'Invalid class or semester context.';
      notifyListeners();
      return;
    }

    _isLoadingRoster = true;
    _rosterError = null;
    notifyListeners();

    try {
      _roster = await _service.getStudentsForContext(
        classId: classId,
        subjectId: subjectId,
        semesterId: semesterId,
      );
    } catch (e) {
      _rosterError = e.toString();
    } finally {
      _isLoadingRoster = false;
      notifyListeners();
    }
  }

  // ─── Form Operations ─────────────────────────────────────────────────────

  Future<void> loadAssessmentForStudent(StudentRosterItem student) async {
    _selectedStudent = student;
    _isLoadingForm = true;
    _formError = null;
    _submissionError = null;
    _lastSubmissionResponse = null;
    _currentStep = 0;
    notifyListeners();

    try {
      _form = await _service.getEndAssessmentForm(student.enrollmentId);
    } catch (e) {
      _formError = e.toString();
    } finally {
      _isLoadingForm = false;
      notifyListeners();
    }
  }

  void setStep(int step) {
    if (step >= 0 && step <= 5) {
      _currentStep = step;
      notifyListeners();
    }
  }

  void nextStep() {
    if (_currentStep < 5) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  // ─── Form Mutators (Section 1: Final Subject Understanding) ───────────────

  void setFinalConfidence(int value) {
    if (_form == null) return;
    _form!.finalConfidence = value;
    notifyListeners();
  }

  void setFinalInterest(int value) {
    if (_form == null) return;
    _form!.finalInterest = value;
    notifyListeners();
  }

  void setPerceivedDifficulty(int value) {
    if (_form == null) return;
    _form!.perceivedDifficulty = value;
    notifyListeners();
  }

  void setUnderstandingLevel(int value) {
    if (_form == null) return;
    _form!.understandingLevel = value;
    notifyListeners();
  }

  void setConceptApplicationAbility(int value) {
    if (_form == null) return;
    _form!.conceptApplicationAbility = value;
    notifyListeners();
  }

  void setLearningSatisfaction(int value) {
    if (_form == null) return;
    _form!.learningSatisfaction = value;
    notifyListeners();
  }

  // ─── Form Mutators (Section 2: Final Competency & Application) ────────────

  void setCoreConceptsMastery(int value) {
    if (_form == null) return;
    _form!.coreConceptsMastery = value;
    notifyListeners();
  }

  void setProblemSolvingAbility(int value) {
    if (_form == null) return;
    _form!.problemSolvingAbility = value;
    notifyListeners();
  }

  void setPracticalLabCompetence(int value) {
    if (_form == null) return;
    _form!.practicalLabCompetence = value;
    notifyListeners();
  }

  void setIndependentLearningAbility(int value) {
    if (_form == null) return;
    _form!.independentLearningAbility = value;
    notifyListeners();
  }

  void setRealWorldApplication(int value) {
    if (_form == null) return;
    _form!.realWorldApplication = value;
    notifyListeners();
  }

  // ─── Form Mutators (Section 3: Overall Learning Experience) ───────────────

  void setEffectiveLearningFormat(String? format) {
    if (_form == null) return;
    _form!.effectiveLearningFormat = format;
    notifyListeners();
  }

  void setResourceEffectiveness(int value) {
    if (_form == null) return;
    _form!.resourceEffectiveness = value;
    notifyListeners();
  }

  void setPracticalLabExperience(int value) {
    if (_form == null) return;
    _form!.practicalLabExperience = value;
    notifyListeners();
  }

  void setTeachingPace(String? pace) {
    if (_form == null) return;
    _form!.teachingPace = pace;
    notifyListeners();
  }

  void setOverallLearningExperience(int value) {
    if (_form == null) return;
    _form!.overallLearningExperience = value;
    notifyListeners();
  }

  // ─── Form Mutators (Section 4: Skills Progression) ────────────────────────

  void updateSkillConfidence(int index, int confidence) {
    if (_form == null || index < 0 || index >= _form!.skillsProgress.length) return;
    _form!.skillsProgress[index].confidenceLevel = confidence;
    notifyListeners();
  }

  void updateSkillStatus(int index, String status) {
    if (_form == null || index < 0 || index >= _form!.skillsProgress.length) return;
    _form!.skillsProgress[index].progressStatus = status;
    notifyListeners();
  }

  void addSkill(String skillName) {
    if (_form == null || skillName.trim().isEmpty) return;
    _form!.skillsProgress.add(
      SkillProgressItem(
        skillName: skillName.trim(),
        confidenceLevel: 3,
        progressStatus: 'IN_PROGRESS',
      ),
    );
    notifyListeners();
  }

  void removeSkill(int index) {
    if (_form == null || index < 0 || index >= _form!.skillsProgress.length) return;
    _form!.skillsProgress.removeAt(index);
    notifyListeners();
  }

  // ─── Form Mutators (Section 5: Topic Feedback) ────────────────────────────

  void setTopicConfidence(int topicId, int value) {
    if (_form == null) return;
    final index = _form!.topics.indexWhere((t) => t.topicId == topicId);
    if (index != -1) {
      _form!.topics[index].endConfidence = value;
      notifyListeners();
    }
  }

  void setTopicDifficulty(int topicId, int value) {
    if (_form == null) return;
    final index = _form!.topics.indexWhere((t) => t.topicId == topicId);
    if (index != -1) {
      _form!.topics[index].endDifficulty = value;
      notifyListeners();
    }
  }

  void setTopicStatus(int topicId, String status) {
    if (_form == null) return;
    final index = _form!.topics.indexWhere((t) => t.topicId == topicId);
    if (index != -1) {
      _form!.topics[index].endProgressStatus = status;
      notifyListeners();
    }
  }

  // ─── Submit Assessment ───────────────────────────────────────────────────

  Future<bool> submitAssessment() async {
    if (_form == null) return false;

    _isSubmitting = true;
    _submissionError = null;
    notifyListeners();

    final topicSubmissions = _form!.topics.map((t) {
      return EndTopicFeedbackSubmissionItem(
        topicId: t.topicId,
        confidenceLevel: t.endConfidence,
        difficultyLevel: t.endDifficulty,
        progressStatus: t.endProgressStatus,
      );
    }).toList();

    final req = EndAssessmentSubmissionRequest(
      enrollmentId: _form!.enrollmentId,
      finalConfidence: _form!.finalConfidence,
      finalInterest: _form!.finalInterest,
      perceivedDifficulty: _form!.perceivedDifficulty,
      understandingLevel: _form!.understandingLevel,
      conceptApplicationAbility: _form!.conceptApplicationAbility,
      learningSatisfaction: _form!.learningSatisfaction,
      coreConceptsMastery: _form!.coreConceptsMastery,
      problemSolvingAbility: _form!.problemSolvingAbility,
      practicalLabCompetence: _form!.practicalLabCompetence,
      independentLearningAbility: _form!.independentLearningAbility,
      realWorldApplication: _form!.realWorldApplication,
      effectiveLearningFormat: _form!.effectiveLearningFormat,
      resourceEffectiveness: _form!.resourceEffectiveness,
      practicalLabExperience: _form!.practicalLabExperience,
      teachingPace: _form!.teachingPace,
      overallLearningExperience: _form!.overallLearningExperience,
      skillsProgress: _form!.skillsProgress,
      topicFeedback: topicSubmissions,
    );

    try {
      _lastSubmissionResponse = await _service.submitEndAssessment(req);
      if (_selectedStudent != null) {
        final index = _roster.indexWhere((s) => s.enrollmentId == _selectedStudent!.enrollmentId);
        if (index != -1) {
          final s = _roster[index];
          _roster[index] = StudentRosterItem(
            enrollmentId: s.enrollmentId,
            studentId: s.studentId,
            name: s.name,
            email: s.email,
            currentYear: s.currentYear,
            division: s.division,
            isAssessed: true,
            isPreAssessed: s.isPreAssessed,
            isMidAssessed: s.isMidAssessed,
            isEndAssessed: true,
            submittedAt: _lastSubmissionResponse!.submittedAt,
            updatedAt: _lastSubmissionResponse!.submittedAt,
          );
        }
      }
      return true;
    } catch (e) {
      _submissionError = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
