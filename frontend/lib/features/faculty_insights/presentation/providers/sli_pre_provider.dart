import 'package:flutter/material.dart';
import '../../data/models/faculty_teaching_context.dart';
import '../../data/models/pre_assessment_form.dart';
import '../../data/models/pre_assessment_submission.dart';
import '../../data/models/student_roster_item.dart';
import '../../data/services/sli_service.dart';

/// Provider managing the state of the PRE-Semester Assessment workflow.
class SliPreProvider extends ChangeNotifier {
  final SliService _service;

  SliPreProvider({SliService? service}) : _service = service ?? SliService();

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
  PreAssessmentForm? _form;
  bool _isLoadingForm = false;
  String? _formError;
  int _currentStep = 0; // 0 to 5
  bool _isSubmitting = false;
  String? _submissionError;
  PreAssessmentSubmissionResponse? _lastSubmissionResponse;

  PreAssessmentForm? get form => _form;
  bool get isLoadingForm => _isLoadingForm;
  String? get formError => _formError;
  int get currentStep => _currentStep;
  bool get isSubmitting => _isSubmitting;
  String? get submissionError => _submissionError;
  PreAssessmentSubmissionResponse? get lastSubmissionResponse => _lastSubmissionResponse;

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
      _form = await _service.getPreAssessmentForm(student.enrollmentId);
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

  // ─── Form Mutators ───────────────────────────────────────────────────────

  void setSubjectInterest(int value) {
    if (_form == null) return;
    _form!.subjectInterest = value;
    notifyListeners();
  }

  void setSelfAssessedSkill(int value) {
    if (_form == null) return;
    _form!.selfAssessedSkill = value;
    notifyListeners();
  }

  void setLearningConfidence(int value) {
    if (_form == null) return;
    _form!.learningConfidence = value;
    notifyListeners();
  }

  void setExpectedDifficulty(int value) {
    if (_form == null) return;
    _form!.expectedDifficulty = value;
    notifyListeners();
  }

  void setPreferredLearningFormat(String? format) {
    if (_form == null) return;
    _form!.preferredLearningFormat = format;
    notifyListeners();
  }

  void setPreferredContentTypes(List<String> types) {
    if (_form == null) return;
    _form!.preferredContentTypes = types;
    notifyListeners();
  }

  void setLearningSource(String? source) {
    if (_form == null) return;
    _form!.learningSource = source;
    notifyListeners();
  }

  void setFreeVsPaidPreference(String? pref) {
    if (_form == null) return;
    _form!.freeVsPaidPreference = pref;
    notifyListeners();
  }

  void setCareerInterest(String? value) {
    if (_form == null) return;
    _form!.careerInterest = value;
    notifyListeners();
  }

  void setPlacementGoal(String? value) {
    if (_form == null) return;
    _form!.placementGoal = value;
    notifyListeners();
  }

  void setSkillsToImprove(String? value) {
    if (_form == null) return;
    _form!.skillsToImprove = value;
    notifyListeners();
  }

  void setTopicConfidence(int topicId, int confidence) {
    if (_form == null) return;
    final topic = _form!.topics.firstWhere(
      (t) => t.topicId == topicId,
      orElse: () => TopicFeedbackItem(topicId: -1, topicName: ''),
    );
    if (topic.topicId != -1) {
      topic.confidenceLevel = confidence;
      notifyListeners();
    }
  }

  void setTopicDifficulty(int topicId, int difficulty) {
    if (_form == null) return;
    final topic = _form!.topics.firstWhere(
      (t) => t.topicId == topicId,
      orElse: () => TopicFeedbackItem(topicId: -1, topicName: ''),
    );
    if (topic.topicId != -1) {
      topic.difficultyLevel = difficulty;
      notifyListeners();
    }
  }

  // ─── Atomic Submission ───────────────────────────────────────────────────

  Future<bool> submitAssessment() async {
    if (_form == null) return false;

    _isSubmitting = true;
    _submissionError = null;
    notifyListeners();

    try {
      // Build topic feedback items
      final List<TopicFeedbackSubmissionItem> topicFeedback = [];
      for (final t in _form!.topics) {
        if (t.confidenceLevel != null && t.difficultyLevel != null) {
          topicFeedback.add(
            TopicFeedbackSubmissionItem(
              topicId: t.topicId,
              confidenceLevel: t.confidenceLevel!,
              difficultyLevel: t.difficultyLevel!,
            ),
          );
        }
      }

      final request = PreAssessmentSubmissionRequest(
        enrollmentId: _form!.enrollmentId,
        subjectInterest: _form!.subjectInterest,
        selfAssessedSkill: _form!.selfAssessedSkill,
        learningConfidence: _form!.learningConfidence,
        expectedDifficulty: _form!.expectedDifficulty,
        preferredLearningFormat: _form!.preferredLearningFormat,
        preferredContentTypes: _form!.preferredContentTypes,
        learningSource: _form!.learningSource,
        freeVsPaidPreference: _form!.freeVsPaidPreference,
        careerInterest: _form!.careerInterest,
        placementGoal: _form!.placementGoal,
        skillsToImprove: _form!.skillsToImprove,
        topicFeedback: topicFeedback,
      );

      _lastSubmissionResponse = await _service.submitPreAssessment(request);

      // Refresh roster to keep count & state accurate
      await fetchRosterForSelectedContext();

      // Also refresh teaching context list to keep counts up to date
      await fetchTeachingContexts();

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _submissionError = e.toString();
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }
}
