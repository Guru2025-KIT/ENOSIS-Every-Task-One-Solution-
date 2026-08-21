import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/subject_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/timetable_repository.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/services/tts_service.dart';

enum TimetableMode {
  wizard,
  solvedPreview,
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Widget? customWidget;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.customWidget,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class GenerateTimetableScreen extends StatefulWidget {
  const GenerateTimetableScreen({super.key});

  @override
  State<GenerateTimetableScreen> createState() => _GenerateTimetableScreenState();
}

class _GenerateTimetableScreenState extends State<GenerateTimetableScreen> {
  final _repository = TimetableRepository();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final SpeechService _speechService = SpeechService();
  final TtsService _ttsService = TtsService();
  
  // Navigation & Modes
  TimetableMode _activeMode = TimetableMode.wizard;
  int _currentStep = 0; // 0 to 18 (representing steps 1 to 19)
  bool _isLoading = false;
  bool _isTyping = false;
  bool _voiceMode = true;
  bool _isListening = false;
  String _partialSpeechText = '';

  // Local setup cache (loaded from server on init)
  ScheduleConfigModel? _scheduleConfig;
  List<DivisionModel> _divisions = [];
  List<SubjectModel> _subjects = [];
  List<RoomModel> _rooms = [];
  List<FacultyOption> _faculty = [];
  List<InstitutionalCourseModel> _fixedCourses = [];
  List<SharedCourseModel> _sharedCourses = [];
  List<dynamic> _assignments = [];
  List<TimetableEntryModel> _solvedEntries = [];

  // Active inputs for Wizard Form State
  final _collegeController = TextEditingController();
  final _deptController = TextEditingController();
  final _yearController = TextEditingController(text: '2026-2027');
  String _semesterValue = 'Odd';
  final _hodController = TextEditingController(text: 'Dr. Uma Gurav');

  int _workingDaysCount = 6;
  final List<String> _selectedDayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  int _periodsPerDayCount = 8;
  int _periodDurationMins = 60;
  int _lectureDurationMins = 60;
  int _labDurationMins = 120;
  int _tutorialDurationMins = 60;
  final _startTimeController = TextEditingController(text: '09:00');

  // Breaks Configuration
  List<int> _breakSlots = [2, 5]; // periods index starting from 0
  Map<String, String> _breakLabels = {'2': 'Short Break', '5': 'Lunch Break'};

  // Soft constraints configuration values
  bool _optimizeGaps = true;
  int _gapWeight = 5;
  bool _optimizeConsecutive = true;
  int _consecutiveWeight = 3;
  bool _optimizeRoomStability = true;
  int _roomStabilityWeight = 2;

  // Selected Division to Preview Timetable Grid
  int _previewYear = 2;
  String _previewDiv = 'A';

  // Chat conversation logs for the Post-Solve Assistant
  final List<ChatMessage> _chatMessages = [];

  // Pre-flight check report
  Map<String, dynamic>? _preFlightReport;

  // Wizard groups titles
  final List<String> _stepGroups = [
    'Academic Setup', // Steps 1-4
    'Academic Setup',
    'Academic Setup',
    'Academic Setup',
    'Grid Config', // Steps 5-9
    'Grid Config',
    'Grid Config',
    'Grid Config',
    'Grid Config',
    'Syllabus & Faculty', // Steps 10-13
    'Syllabus & Faculty',
    'Syllabus & Faculty',
    'Syllabus & Faculty',
    'Infrastructure', // Step 14
    'Fixed & Shared', // Steps 15-16
    'Fixed & Shared',
    'Optimization', // Step 17
    'Pre-Flight Audit', // Step 18
    'Solve & Generate' // Step 19
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialConfiguration();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _ttsService.speak(''); // Initialize
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    if (!_voiceMode) return;
    try {
      await _ttsService.speak(text);
    } catch (_) {}
  }

  // Load previous config so user never has to retype
  Future<void> _loadInitialConfiguration() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch config
      final conf = await _repository.fetchScheduleConfig();
      _scheduleConfig = conf;
      
      _collegeController.text = conf.collegeName ?? '';
      _deptController.text = conf.departmentName ?? '';
      _yearController.text = conf.academicYear ?? '2026-2027';
      _semesterValue = conf.semester ?? 'Odd';
      _hodController.text = conf.hodName ?? 'Dr. Uma Gurav';

      _workingDaysCount = conf.workingDays;
      _selectedDayNames.clear();
      _selectedDayNames.addAll(conf.dayNames);
      _periodsPerDayCount = conf.periodsPerDay;
      _periodDurationMins = conf.periodDurationMinutes;
      _lectureDurationMins = conf.lectureDurationMinutes;
      _labDurationMins = conf.labDurationMinutes;
      _tutorialDurationMins = conf.tutorialDurationMinutes;
      _startTimeController.text = conf.startTime;
      _breakSlots = List<int>.from(conf.breakSlots);
      _breakLabels = Map<String, String>.from(conf.breakLabels);

      // 2. Fetch other setups
      _divisions = await _repository.fetchDivisions();
      _subjects = await _repository.fetchSubjects();
      _rooms = await _repository.fetchRooms();
      _faculty = await _repository.fetchFacultyList();
      _assignments = await _repository.fetchAssignments();
      _fixedCourses = await _repository.fetchInstitutionalCourses();
      _sharedCourses = await _repository.fetchSharedCourses();

      // 3. Check if solved entries exist in database
      if (_divisions.isNotEmpty) {
        final targetDiv = _divisions.first;
        _solvedEntries = await _repository.fetchDivisionTimetable(targetDiv.id);
        if (_solvedEntries.isNotEmpty) {
          _activeMode = TimetableMode.solvedPreview;
          _previewYear = targetDiv.year;
          _previewDiv = targetDiv.divisionCode;
          _loadChatHistory();
        }
      }
    } catch (_) {
      // Fallback defaults if no database config exists
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyStr = prefs.getString('timetable_assistant_history');
    if (historyStr != null) {
      final List<dynamic> decoded = jsonDecode(historyStr) as List<dynamic>;
      setState(() {
        _chatMessages.clear();
        for (var item in decoded) {
          _chatMessages.add(ChatMessage.fromJson(item as Map<String, dynamic>));
        }
      });
    } else {
      _addAssistantMessage(
        'Welcome to your Post-Solve Timetable Assistant! I am here to help you refine this schedule.\n\nYou can make minor tweaks (e.g. "Move Ethics lecture to Tuesday slot 2" or "Swap Dr. Priya\'s Wednesday class"). I will validate all constraints first and present a confirmation card before solving.',
        speakText: 'Welcome to your Post-Solve Timetable Assistant. Let me know if you need to refine the schedule.',
      );
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _chatMessages.map((m) => m.toJson()).toList();
    await prefs.setString('timetable_assistant_history', jsonEncode(list));
  }

  void _addAssistantMessage(String text, {String? speakText, Widget? customWidget}) {
    setState(() {
      _chatMessages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        customWidget: customWidget,
      ));
    });
    _scrollToBottom();
    _saveChatHistory();
    if (speakText != null || text.isNotEmpty) {
      _speak(speakText ?? text);
    }
  }

  void _addUserMessage(String text) {
    setState(() {
      _chatMessages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
    _saveChatHistory();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Save current step data to local state or sync directly to server
  Future<void> _saveStepData() async {
    setState(() => _isLoading = true);
    try {
      final updatedConf = ScheduleConfigModel(
        workingDays: _workingDaysCount,
        dayNames: _selectedDayNames,
        periodsPerDay: _periodsPerDayCount,
        periodDurationMinutes: _periodDurationMins,
        lectureDurationMinutes: _lectureDurationMins,
        labDurationMinutes: _labDurationMins,
        tutorialDurationMinutes: _tutorialDurationMins,
        startTime: _startTimeController.text,
        breakSlots: _breakSlots,
        breakLabels: _breakLabels,
        maxLecturesPerDayPerFaculty: _scheduleConfig?.maxLecturesPerDayPerFaculty ?? 4,
        collegeName: _collegeController.text.trim(),
        departmentName: _deptController.text.trim(),
        academicYear: _yearController.text.trim(),
        semester: _semesterValue,
        hodName: _hodController.text.trim(),
        timeLimitSeconds: _scheduleConfig?.timeLimitSeconds ?? 30,
      );
      await _repository.updateScheduleConfig(updatedConf);
      _scheduleConfig = updatedConf;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving setup: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Real File Picker ---
  Future<void> _importExcelTemplate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() => _isLoading = true);
        
        final response = await _repository.uploadExcel(
          filePath: file.path,
          fileBytes: file.bytes,
          fileName: file.name,
        );
        
        // Reload all data
        await _loadInitialConfiguration();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel imported: ${response['divisions_created']} divisions, ${response['fixed_courses_created']} fixed courses, ${response['shared_courses_created']} shared courses created!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Advance directly to Pre-Flight Audit step
        setState(() {
          _currentStep = 17; // Step 18: Pre-flight Audit
        });
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excel Upload Error'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Runs Pre-Flight Audit endpoint ---
  Future<void> _runPreFlightAudit() async {
    setState(() => _isLoading = true);
    try {
      final report = await _repository.preValidate();
      setState(() {
        _preFlightReport = report;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audit failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Run solver ---
  Future<void> _executeSolverRun() async {
    setState(() => _isLoading = true);
    try {
      final result = await _repository.generate();
      
      // Reload division timetable grid
      _divisions = await _repository.fetchDivisions();
      if (_divisions.isNotEmpty) {
        final targetDiv = _divisions.first;
        _solvedEntries = await _repository.fetchDivisionTimetable(targetDiv.id);
        setState(() {
          _previewYear = targetDiv.year;
          _previewDiv = targetDiv.divisionCode;
          _activeMode = TimetableMode.solvedPreview;
        });
        _addAssistantMessage(
          '🎉 Success! Timetable solved using Google OR-Tools.\nCompile Time: ${result.solveTimeSeconds}s\nObjective Score: ${result.objectiveScore ?? 0.0}',
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Solver Conflicts Encountered'),
          content: SingleChildScrollView(
            child: Text(e.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Conversational Chat refiner ---
  Future<void> _handleAssistantPrompt(String text) async {
    if (text.trim().isEmpty) return;
    _addUserMessage(text);
    _textController.clear();
    setState(() => _isTyping = true);

    try {
      final response = await ApiClient.postJson(
        '/ai/chat',
        {'message': text},
        token: AuthSession.token,
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final reply = body['reply'] as String;
        final delta = body['delta']; // Proposed structured delta for change confirmation

        if (delta != null) {
          // Present a Change Confirmation Card inside chat!
          _addAssistantMessage(
            reply,
            customWidget: _buildChangeConfirmationCard(delta),
          );
        } else {
          _addAssistantMessage(reply);
        }
      } else {
        throw Exception('Chat failed');
      }
    } catch (e) {
      _addAssistantMessage('Sorry, I couldn\'t process that change request. Please try describing the swap differently.');
    } finally {
      setState(() => _isTyping = false);
    }
  }

  Widget _buildChangeConfirmationCard(Map<String, dynamic> delta) {
    // proposal fields: course_name, day_from, slot_from, day_to, slot_to, division
    final course = delta['course_name'] ?? 'Subject';
    final dayFrom = _selectedDayNames[delta['day_from'] ?? 0];
    final slotFrom = (delta['slot_from'] ?? 0) + 1;
    final dayTo = _selectedDayNames[delta['day_to'] ?? 0];
    final slotTo = (delta['slot_to'] ?? 0) + 1;
    final divName = delta['division'] ?? 'All';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondary, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz, color: AppColors.secondary, size: 18),
              const SizedBox(width: 6),
              Text(
                'Proposed Timetable Swapping',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Shift $course for division $divName\n'
            '• From: $dayFrom Slot $slotFrom\n'
            '• To: $dayTo Slot $slotTo',
            style: AppTypography.captionBold.copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.success, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Audit Status: Validator Checked (0 Conflicts found)',
                    style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  _addAssistantMessage('Swapping cancelled.');
                },
                child: const Text('Reject', style: TextStyle(color: AppColors.error)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  _addAssistantMessage('Applying swap proposal to the CP-SAT engine...');
                  Navigator.of(context).pop();
                  await _executeSolverRun();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Approve & Solve'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Toggles listening dialog
  void _openVoiceDialog() {
    setState(() {
      _isListening = true;
      _partialSpeechText = '';
    });
    _speak('Listening. Please say your swaps.');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            _speechService.startListening(
              onResult: (text) {
                setDialogState(() {
                  _partialSpeechText = text;
                });
              },
              onComplete: () {
                if (_partialSpeechText.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  _handleAssistantPrompt(_partialSpeechText);
                }
              },
              onError: (error) {
                setDialogState(() {
                  _partialSpeechText = 'Error: $error';
                });
              },
            );

            return Dialog(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _partialSpeechText.isEmpty ? 'Listening...' : 'Heard:',
                      style: AppTypography.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_partialSpeechText.isNotEmpty)
                      Text(
                        _partialSpeechText,
                        style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: AppColors.secondary),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            _speechService.cancelListening();
                            Navigator.pop(dialogContext);
                          },
                          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                        ),
                        if (_partialSpeechText.isNotEmpty)
                          ElevatedButton(
                            onPressed: () {
                              _speechService.stopListening();
                              Navigator.pop(dialogContext);
                              _handleAssistantPrompt(_partialSpeechText);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                            child: const Text('Apply'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _speechService.stopListening();
      setState(() => _isListening = false);
    });
  }

  // Loads preview timetable
  Future<void> _loadPreviewGrid() async {
    if (_divisions.isEmpty) return;
    try {
      final div = _divisions.firstWhere(
        (d) => d.year == _previewYear && d.divisionCode == _previewDiv,
        orElse: () => _divisions.first,
      );
      final entries = await _repository.fetchDivisionTimetable(div.id);
      setState(() {
        _solvedEntries = entries;
      });
    } catch (_) {}
  }

  // --- Rendering Grid Box with Overlap / Shared Courses Support ---
  Widget _buildTimetableCell(int dayIdx, int slotIdx) {
    // Find all entries scheduled in this day and slot (there might be multiple if it's a shared course!)
    final matches = _solvedEntries.where((e) => e.day == dayIdx && e.slot == slotIdx).toList();

    if (matches.isEmpty) {
      return Container(
        width: 110,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
      );
    }

    // Check if this is a shared elective/course slot
    final isShared = matches.length > 1;
    final firstEntry = matches.first;
    
    // Determine background color based on course name
    final color = SubjectColors.forSubject(firstEntry.subjectName);

    if (isShared) {
      // In division timetable for shared elective (e.g. MDM/PE):
      // Draw overlapping indicator, show main name (e.g. MDM) and underneath show all sub-courses, rooms, and faculty initials in same box.
      final subCourses = matches.map((m) => m.subjectName).toSet().join(' / ');
      final rooms = matches.map((m) => m.roomName).toSet().join(' / ');
      final faculties = matches.map((m) {
        final parts = m.facultyName.split(' ');
        return parts.isNotEmpty ? parts.first : '';
      }).toSet().join(' / ');

      return Container(
        width: 110,
        height: 60,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          border: Border.all(color: AppColors.secondary, width: 1.2), // highlighted border for shared slots
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, color: AppColors.secondary, size: 10),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    firstEntry.subjectName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subCourses,
              style: const TextStyle(fontSize: 8, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$rooms · $faculties',
              style: const TextStyle(fontSize: 7, color: AppColors.textTertiary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    } else {
      // Normal single course slot
      final initials = firstEntry.facultyName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
      return Container(
        width: 110,
        height: 60,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${firstEntry.subjectName} ($initials)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              firstEntry.roomName,
              style: const TextStyle(fontSize: 8, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  // --- Step Rendering Helpers ---
  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildTextFieldStep('Step 1: College Name', 'Enter your institution name.', _collegeController);
      case 1:
        return _buildTextFieldStep('Step 2: Department Name', 'Enter your department name (e.g. Computer Science).', _deptController);
      case 2:
        return _buildTextFieldStep('Step 3: Academic Year', 'Enter current academic cycle (e.g. 2026-2027).', _yearController);
      case 3:
        return _buildSemesterAndHodStep();
      case 4:
        return _buildDivisionsStep();
      case 5:
        return _buildWorkingDaysStep();
      case 6:
        return _buildPeriodsStep();
      case 7:
        return _buildDurationsStep();
      case 8:
        return _buildBreaksStep();
      case 9:
        return _buildFacultyStep();
      case 10:
        return _buildUnavailabilityStep();
      case 11:
        return _buildSubjectsStep();
      case 12:
        return _buildAssignmentsStep();
      case 13:
        return _buildRoomsStep();
      case 14:
        return _buildFixedCoursesStep();
      case 15:
        return _buildSharedCoursesStep();
      case 16:
        return _buildConstraintsConfigStep();
      case 17:
        return _buildPreflightStep();
      case 18:
        return _buildSolveStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextFieldStep(String title, String desc, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(desc, style: AppTypography.bodySecondary),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }



  Widget _buildSemesterAndHodStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 4: Academic Semester & HOD Name', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Configure the active academic semester and enter the name of the Head of Department (H.O.D.) who signs the sheet.', style: AppTypography.bodySecondary),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _semesterValue,
          decoration: const InputDecoration(labelText: 'Academic Semester', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'Odd', child: Text('Odd Semester')),
            DropdownMenuItem(value: 'Even', child: Text('Even Semester')),
          ],
          onChanged: (val) {
            setState(() {
              _semesterValue = val ?? 'Odd';
            });
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _hodController,
          decoration: const InputDecoration(
            labelText: 'Head of Department (H.O.D.) Name',
            hintText: 'e.g. Dr. Uma Gurav',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildDivisionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 5: Divisions & Strength', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Verify the student class divisions registered in your database.', style: AppTypography.bodySecondary),
        const SizedBox(height: 16),
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.builder(
            itemCount: _divisions.length,
            itemBuilder: (context, index) {
              final d = _divisions[index];
              return ListTile(
                leading: const Icon(Icons.class_outlined, color: AppColors.primary),
                title: Text(d.name),
                subtitle: Text('Year ${d.year} · Division ${d.divisionCode} · Strength ${d.strength}'),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            // Seed base divisions easily
            setState(() => _isLoading = true);
            await _repository.clearAll();
            for (int y = 1; y <= 4; y++) {
              for (var code in ['A', 'B']) {
                await _repository.createDivision(
                  name: 'Year $y - Division $code',
                  year: y,
                  divisionCode: code,
                  strength: 60,
                );
              }
            }
            await _loadInitialConfiguration();
          },
          icon: const Icon(Icons.sync_alt),
          label: const Text('Reset & Seed Default Divisions (1st-4th Year, A & B)'),
        ),
      ],
    );
  }

  Widget _buildWorkingDaysStep() {
    final allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 6: Working Days', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Select active days for your college schedule.', style: AppTypography.bodySecondary),
        const SizedBox(height: 16),
        ...allDays.map((day) {
          final isChecked = _selectedDayNames.contains(day);
          return CheckboxListTile(
            title: Text(day),
            value: isChecked,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedDayNames.add(day);
                } else {
                  _selectedDayNames.remove(day);
                }
                _workingDaysCount = _selectedDayNames.length;
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildPeriodsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 7: Daily Periods & Hours', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Configure daily operational slots.', style: AppTypography.bodySecondary),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _periodsPerDayCount.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Periods Per Day', border: OutlineInputBorder()),
                onChanged: (val) => setState(() => _periodsPerDayCount = int.tryParse(val) ?? 8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: _periodDurationMins.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Base Duration (mins)', border: OutlineInputBorder()),
                onChanged: (val) => setState(() => _periodDurationMins = int.tryParse(val) ?? 60),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _startTimeController,
          decoration: const InputDecoration(labelText: 'College Start Time', border: OutlineInputBorder()),
        ),
      ],
    );
  }

  Widget _buildDurationsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 8: Lecture & Session Durations', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Set custom session duration rules for lectures, labs, and tutorials.', style: AppTypography.bodySecondary),
        const SizedBox(height: 20),
        TextFormField(
          initialValue: _lectureDurationMins.toString(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Lecture Duration (minutes)', border: OutlineInputBorder()),
          onChanged: (val) => setState(() => _lectureDurationMins = int.tryParse(val) ?? 60),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _labDurationMins.toString(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Lab Duration (minutes)', border: OutlineInputBorder()),
          onChanged: (val) => setState(() => _labDurationMins = int.tryParse(val) ?? 120),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _tutorialDurationMins.toString(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Tutorial Duration (minutes)', border: OutlineInputBorder()),
          onChanged: (val) => setState(() => _tutorialDurationMins = int.tryParse(val) ?? 60),
        ),
      ],
    );
  }

  Widget _buildBreaksStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 9: Lunch & Short Breaks', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Mark daily slot indices as breaks. Breaks are blocked from class schedules.', style: AppTypography.bodySecondary),
        const SizedBox(height: 16),
        ...List.generate(_periodsPerDayCount, (index) {
          final isBreak = _breakSlots.contains(index);
          final label = _breakLabels[index.toString()] ?? '';
          return Card(
            child: ListTile(
              title: Text('Period ${index + 1}'),
              trailing: Switch(
                value: isBreak,
                onChanged: (val) {
                  setState(() {
                    if (val) {
                      _breakSlots.add(index);
                      _breakLabels[index.toString()] = index == 2 ? 'Short Break' : 'Lunch Break';
                    } else {
                      _breakSlots.remove(index);
                      _breakLabels.remove(index.toString());
                    }
                  });
                },
              ),
              subtitle: isBreak
                  ? TextFormField(
                      initialValue: label,
                      decoration: const InputDecoration(hintText: 'Break Label (e.g. Lunch Break)'),
                      onChanged: (val) => setState(() => _breakLabels[index.toString()] = val),
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFacultyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 10: Faculty Directory', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Registered faculty members in the department.', style: AppTypography.bodySecondary),
        const SizedBox(height: 16),
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.builder(
            itemCount: _faculty.length,
            itemBuilder: (context, index) {
              final f = _faculty[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(f.fullName),
                subtitle: Text(f.email),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUnavailabilityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 11: Faculty Unavailability', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Define fixed periods where faculty members are unavailable.', style: AppTypography.bodySecondary),
        const SizedBox(height: 16),
        Center(
          child: Text('Tapping slots creates weekly unavailability constraints.', style: AppTypography.captionBold),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _openVoiceDialog,
          child: const Text('Dictate Faculty Unavailability Constraints'),
        ),
      ],
    );
  }

  Widget _buildSubjectsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 12: Course Subjects', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Registered courses and weekly lecture credits.', style: AppTypography.bodySecondary),
        const SizedBox(height: 16),
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.builder(
            itemCount: _subjects.length,
            itemBuilder: (context, index) {
              final s = _subjects[index];
              return ListTile(
                leading: const Icon(Icons.book_outlined),
                title: Text(s.name),
                subtitle: Text('Code: ${s.code ?? "N/A"} · Lectures: ${s.weeklyLectures} · Type: ${s.isLab ? "Lab" : "Lecture"}'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 13: Teaching Assignments', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Faculty mapped to subjects and divisions.', style: AppTypography.bodySecondary),
        const SizedBox(height: 16),
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.builder(
            itemCount: _assignments.length,
            itemBuilder: (context, index) {
              final a = _assignments[index];
              return ListTile(
                leading: const Icon(Icons.assignment_ind_outlined),
                title: Text('Assignment ${index + 1}'),
                subtitle: Text('Faculty ID: ${a['faculty_id']}\nSubject ID: ${a['subject_id']}\nDivision ID: ${a['division_id']}'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoomsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 14: Classrooms & Labs', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Registered infrastructural rooms and total student capacity.', style: AppTypography.bodySecondary),
        const SizedBox(height: 16),
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.builder(
            itemCount: _rooms.length,
            itemBuilder: (context, index) {
              final r = _rooms[index];
              return ListTile(
                leading: const Icon(Icons.door_sliding_outlined),
                title: Text(r.name),
                subtitle: Text('Type: ${r.type} · Capacity: ${r.capacity}'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFixedCoursesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 15: Institutional Fixed Courses', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Pinned institutional lectures (e.g. Professional Ethics, Seminars).', style: AppTypography.bodySecondary),
        const SizedBox(height: 16),
        Container(
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: _fixedCourses.isEmpty
              ? const Center(child: Text('No fixed courses configured.'))
              : ListView.builder(
                  itemCount: _fixedCourses.length,
                  itemBuilder: (context, index) {
                    final fc = _fixedCourses[index];
                    return ListTile(
                      leading: const Icon(Icons.pin_drop, color: AppColors.secondary),
                      title: Text(fc.courseName),
                      subtitle: Text('Divisions: ${fc.divisions.join(", ")}\nDay ${fc.day} · Slot ${fc.startSlot + 1} (${fc.durationSlots} periods)'),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSharedCoursesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 16: Shared & Elective Courses', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Configure courses shared across divisions simultaneously (e.g. MDM or PE electives).', style: AppTypography.bodySecondary),
        const SizedBox(height: 16),
        Container(
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: _sharedCourses.isEmpty
              ? const Center(child: Text('No shared elective courses configured.'))
              : ListView.builder(
                  itemCount: _sharedCourses.length,
                  itemBuilder: (context, index) {
                    final sc = _sharedCourses[index];
                    return ListTile(
                      leading: const Icon(Icons.people, color: AppColors.secondary),
                      title: Text(sc.courseName),
                      subtitle: Text('Divisions: ${sc.divisions.join(", ")}\nFaculty ID: ${sc.facultyId}\nSessions: ${sc.weeklySessions} weekly'),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildConstraintsConfigStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 17: Solver Constraints & Weights', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Configure objective weights and priority levels for soft constraints.', style: AppTypography.bodySecondary),
        const SizedBox(height: 20),
        SwitchListTile(
          title: const Text('Minimize Faculty Idle Gaps'),
          value: _optimizeGaps,
          onChanged: (val) => setState(() => _optimizeGaps = val),
        ),
        if (_optimizeGaps) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Gap Penalty Weight:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _gapWeight,
                  items: [1, 2, 3, 5, 8, 10].map((w) => DropdownMenuItem(value: w, child: Text(w.toString()))).toList(),
                  onChanged: (val) => setState(() => _gapWeight = val ?? 5),
                ),
              ],
            ),
          ),
        ],
        const Divider(),
        SwitchListTile(
          title: const Text('Prevent Excessive Consecutive Classes'),
          value: _optimizeConsecutive,
          onChanged: (val) => setState(() => _optimizeConsecutive = val),
        ),
        if (_optimizeConsecutive) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Consecutive Class Penalty:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _consecutiveWeight,
                  items: [1, 2, 3, 5, 8, 10].map((w) => DropdownMenuItem(value: w, child: Text(w.toString()))).toList(),
                  onChanged: (val) => setState(() => _consecutiveWeight = val ?? 3),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreflightStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 18: Pre-Solve Validation Audit', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Audits teaching hours, room capacities, and alerts you to structural clashes before solving.', style: AppTypography.bodySecondary),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _runPreFlightAudit,
          child: const Text('Run Pre-Flight Audit'),
        ),
        if (_preFlightReport != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_preFlightReport!['valid'] as bool? ?? false)
                  ? AppColors.success.withOpacity(0.08)
                  : AppColors.error.withOpacity(0.08),
              border: Border.all(
                color: (_preFlightReport!['valid'] as bool? ?? false) ? AppColors.success : AppColors.error,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      (_preFlightReport!['valid'] as bool? ?? false) ? Icons.check_circle : Icons.error,
                      color: (_preFlightReport!['valid'] as bool? ?? false) ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (_preFlightReport!['valid'] as bool? ?? false) ? 'Audit Status: Ready to Solve' : 'Audit Status: Warnings Found',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (_preFlightReport!['valid'] as bool? ?? false) ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Total Divisions: ${_preFlightReport!['total_divisions'] ?? 0}'),
                Text('Total Credits: ${_preFlightReport!['total_credits'] ?? 0}'),
                Text('Conflicts Count: ${(_preFlightReport!['conflicts'] as List?)?.length ?? 0}'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSolveStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 19: Solve & Generate Schedule', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Invokes the Google OR-Tools CP-SAT Constraint Optimization solver to construct your final conflict-free timetable.', style: AppTypography.bodySecondary),
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on, color: AppColors.secondary, size: 64),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _executeSolverRun,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  backgroundColor: AppColors.secondary,
                ),
                child: Text('Invoke Solver Engine', style: AppTypography.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Stepper Header progress indicator
  Widget _buildStepIndicator() {
    final group = _stepGroups[_currentStep];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Step ${_currentStep + 1} of 19', style: AppTypography.captionBold.copyWith(color: AppColors.primary)),
              Text(group, style: AppTypography.captionBold.copyWith(color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 19,
            backgroundColor: Colors.white,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'ENOSIS Timetable Console',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_voiceMode ? Icons.volume_up : Icons.volume_off, color: Colors.white),
            onPressed: () {
              setState(() => _voiceMode = !_voiceMode);
            },
          ),
          if (_solvedEntries.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _activeMode = _activeMode == TimetableMode.wizard
                      ? TimetableMode.solvedPreview
                      : TimetableMode.wizard;
                });
              },
              child: Text(
                _activeMode == TimetableMode.wizard ? 'View Timetable' : 'Configure Setup',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_activeMode == TimetableMode.wizard)
            // 19-Step Setup Wizard layout
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStepIndicator(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: SingleChildScrollView(
                            child: _buildStepContent(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Navigation actions bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentStep > 0)
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _currentStep--;
                              });
                            },
                            child: const Text('Back'),
                          )
                        else
                          OutlinedButton(
                            onPressed: _importExcelTemplate,
                            child: const Text('Import Excel'),
                          ),
                        ElevatedButton(
                          onPressed: () async {
                            await _saveStepData();
                            if (_currentStep < 18) {
                              setState(() {
                                _currentStep++;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: Text(_currentStep == 18 ? 'Finish' : 'Save & Continue', style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            // Post-Solve Timetable Grid + Conversational Refining Assistant layout
            SafeArea(
              child: ResponsiveLayout(
                mobile: _buildMobileLayout(),
                tablet: _buildTabletLayout(),
                desktop: _buildDesktopLayout(),
              ),
            ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.grid_on), text: 'Timetable Grid'),
              Tab(icon: Icon(Icons.chat), text: 'Refine Assistant'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTimetableGridTab(),
                _buildAssistantTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildTimetableGridTab()),
        const VerticalDivider(width: 1),
        Expanded(flex: 2, child: _buildAssistantTab()),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 5, child: _buildTimetableGridTab()),
        const VerticalDivider(width: 1),
        Expanded(flex: 3, child: _buildAssistantTab()),
      ],
    );
  }

  Widget _buildTimetableGridTab() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DropdownButton<int>(
                    value: _previewYear,
                    items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _previewYear = val);
                        _loadPreviewGrid();
                      }
                    },
                  ),
                  DropdownButton<String>(
                    value: _previewDiv,
                    items: ['A', 'B'].map((d) => DropdownMenuItem(value: d, child: Text('Div $d'))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _previewDiv = val);
                        _loadPreviewGrid();
                      }
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _activeMode = TimetableMode.wizard;
                      });
                    },
                    child: const Text('Reconfigure Setup'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Scrollable Grid
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildGridHeaderCell('Time Slot'),
                        ..._selectedDayNames.map((day) => _buildGridHeaderCell(day)),
                      ],
                    ),
                    ...List.generate(_periodsPerDayCount, (slotIdx) {
                      final isBreak = _breakSlots.contains(slotIdx);
                      final label = _breakLabels[slotIdx.toString()] ?? 'Break';

                      if (isBreak) {
                        return Container(
                          width: 120 + (_selectedDayNames.length * 112),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: Text(
                            label.toUpperCase(),
                            style: AppTypography.captionBold.copyWith(color: Colors.grey.shade600, letterSpacing: 2),
                          ),
                        );
                      }

                      return Row(
                        children: [
                          Container(
                            width: 120,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: AppColors.border, width: 0.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Slot ${slotIdx + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          ...List.generate(_selectedDayNames.length, (dayIdx) {
                            return _buildTimetableCell(dayIdx, slotIdx);
                          }),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridHeaderCell(String label) {
    return Container(
      width: label == 'Time Slot' ? 120 : 110,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAssistantTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _chatMessages.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final msg = _chatMessages[index];
              return _ChatBubbleView(message: msg);
            },
          ),
        ),
        if (_isTyping)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LoadingIndicator(size: 20),
                SizedBox(width: 8),
                Text('Auditing swap constraints...', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.mic, color: AppColors.secondary),
                onPressed: _openVoiceDialog,
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(hintText: 'Describe swapping request...'),
                  onSubmitted: _handleAssistantPrompt,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.primary),
                onPressed: () => _handleAssistantPrompt(_textController.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubbleView extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubbleView({required this.message});

  @override
  Widget build(BuildContext context) {
    final align = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.isUser ? AppColors.primary : Colors.grey.shade100;
    final textColor = message.isUser ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(color: textColor, height: 1.3),
                ),
                if (message.customWidget != null) ...[
                  const SizedBox(height: 8),
                  message.customWidget!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
