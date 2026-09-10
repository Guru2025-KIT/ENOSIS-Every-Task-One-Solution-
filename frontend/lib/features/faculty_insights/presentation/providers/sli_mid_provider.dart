import 'package:flutter/material.dart';
import '../../data/models/faculty_teaching_context.dart';
import '../../data/models/mid_assessment_form.dart';
import '../../data/models/mid_assessment_submission.dart';
import '../../data/models/student_roster_item.dart';
import '../../data/services/sli_service.dart';

/// Provider managing the state of the MID-Semester Assessment workflow.
class SliMidProvider extends ChangeNotifier {
  final SliService _service;

  SliMidProvider({SliService? service}) : _service = service ?? SliService();

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
  MidAssessmentForm? _form;
  bool _isLoadingForm = false;
  String? _formError;
  int _currentStep = 0; // 0 to 5
  bool _isSubmitting = false;
  String? _submissionError;
  MidAssessmentSubmissionResponse? _lastSubmissionResponse;

  MidAssessmentForm? get form => _form;
  bool get isLoadingForm => _isLoadingForm;
  String? get formError => _formError;
  int get currentStep => _currentStep;
  bool get isSubmitting => _isSubmitting;
  String? get submissionError => _submissionError;
  MidAssessmentSubmissionResponse? get lastSubmissionResponse => _lastSubmissionResponse;

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
      _form = await _service.getMidAssessmentForm(student.enrollmentId);
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

  void setCurrentConfidence(int value) {
    if (_form == null) return;
    _form!.currentConfidence = value;
    notifyListeners();
  }

  void setCurrentInterest(int value) {
    if (_form == null) return;
    _form!.currentInterest = value;
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

  void setUsefulLearningFormat(String? format) {
    if (_form == null) return;
    _form!.usefulLearningFormat = format;
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

  void toggleLearningBarrier(String barrier) {
    if (_form == null) return;
    if (_form!.learningBarriers.contains(barrier)) {
      _form!.learningBarriers.remove(barrier);
    } else {
      _form!.learningBarriers.add(barrier);
    }
    notifyListeners();
  }

  // Skills Progress Mutators
  void setSkillConfidence(int index, int confidence) {
    if (_form == null || index < 0 || index >= _form!.skillsProgress.length) return;
    _form!.skillsProgress[index].confidenceLevel = confidence;
    notifyListeners();
  }

  void setSkillProgressStatus(int index, String status) {
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

  // Topics Evaluation Mutators
  void setTopicMidConfidence(int topicId, int confidence) {
    if (_form == null) return;
    final topic = _form!.topics.firstWhere(
      (t) => t.topicId == topicId,
      orElse: () => MidTopicFeedbackItem(topicId: -1, topicName: ''),
    );
    if (topic.topicId != -1) {
      topic.midConfidence = confidence;
      notifyListeners();
    }
  }

  void setTopicMidDifficulty(int topicId, int difficulty) {
    if (_form == null) return;
    final topic = _form!.topics.firstWhere(
      (t) => t.topicId == topicId,
      orElse: () => MidTopicFeedbackItem(topicId: -1, topicName: ''),
    );
    if (topic.topicId != -1) {
      topic.midDifficulty = difficulty;
      notifyListeners();
    }
  }

  void setTopicProgressStatus(int topicId, String status) {
    if (_form == null) return;
    final topic = _form!.topics.firstWhere(
      (t) => t.topicId == topicId,
      orElse: () => MidTopicFeedbackItem(topicId: -1, topicName: ''),
    );
    if (topic.topicId != -1) {
      topic.progressStatus = status;
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
      final List<MidTopicFeedbackSubmissionItem> topicFeedback = [];
      for (final t in _form!.topics) {
        if (t.midConfidence != null || t.midDifficulty != null || t.progressStatus != null) {
          topicFeedback.add(
            MidTopicFeedbackSubmissionItem(
              topicId: t.topicId,
              confidenceLevel: t.midConfidence,
              difficultyLevel: t.midDifficulty,
              progressStatus: t.progressStatus,
            ),
          );
        }
      }

      final request = MidAssessmentSubmissionRequest(
        enrollmentId: _form!.enrollmentId,
        currentConfidence: _form!.currentConfidence,
        currentInterest: _form!.currentInterest,
        perceivedDifficulty: _form!.perceivedDifficulty,
        understandingLevel: _form!.understandingLevel,
        conceptApplicationAbility: _form!.conceptApplicationAbility,
        learningSatisfaction: _form!.learningSatisfaction,
        usefulLearningFormat: _form!.usefulLearningFormat,
        resourceEffectiveness: _form!.resourceEffectiveness,
        practicalLabExperience: _form!.practicalLabExperience,
        teachingPace: _form!.teachingPace,
        learningBarriers: _form!.learningBarriers,
        skillsProgress: _form!.skillsProgress,
        topicFeedback: topicFeedback,
      );

      _lastSubmissionResponse = await _service.submitMidAssessment(request);

      // Refresh roster to keep count & status accurate
      await fetchRosterForSelectedContext();

      // Refresh contexts list to keep mid_assessed_students count accurate
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
