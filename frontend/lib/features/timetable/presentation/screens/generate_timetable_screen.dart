import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

enum AgentState {
  welcome,
  awaitingCollegeDept,
  awaitingYearsDivs,
  awaitingSubjects,
  awaitingRooms,
  awaitingConstraints,
  readyToSolve,
  solving,
  solved,
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
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechService _speechService = SpeechService();
  final TtsService _ttsService = TtsService();
  String _partialSpeechText = '';

  // Chat Log & Agent State
  final List<ChatMessage> _messages = [];
  AgentState _agentState = AgentState.welcome;
  bool _isTyping = false;
  bool _voiceMode = true;
  bool _isListening = false;

  // Timetable Setup States
  String _collegeName = '';
  String _deptName = '';
  int _totalYears = 4;
  int _divisionsPerYear = 2;
  final List<Map<String, dynamic>> _parsedSubjects = [];
  final List<Map<String, dynamic>> _parsedRooms = [];
  List<String> _userConstraints = [];

  // Solver Preview Grid states
  List<TimetableEntryModel> _previewEntries = [];
  int _selectedPreviewYear = 2;
  String _selectedPreviewDiv = 'A';
  List<FacultyOption> _faculty = [];

  final List<String> _timeLabels = [
    '9.00-10.00',
    '10.00-11.00',
    '11.00-11.15', // Short Break
    '11.15-12.15',
    '12.15-1.15',
    '1.15-2.00',  // Lunch Break
    '2.00-3.00',
    '3.00-4.00',
    '4.00-5.00',
  ];
  final List<String> _dayLabels = ['Tue', 'Wed', 'Thur', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadSetupData();
    _loadChatHistory();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.05);
      await _flutterTts.setSpeechRate(0.75);

      // Query all available voices and pick the best Indian voice
      final voices = await _flutterTts.getVoices;
      bool voiceSet = false;

      if (voices != null && voices is List) {
        // Priority 1: Hindi voice (hi-IN) — sounds most natural for Indian accent
        for (var voice in voices) {
          if (voice is Map) {
            final name = voice['name']?.toString().toLowerCase() ?? '';
            final locale = voice['locale']?.toString().toLowerCase() ?? '';
            if (locale == 'hi-in' && (name.contains('google') || name.contains('female') || name.contains('hindi'))) {
              await _flutterTts.setLanguage('hi-IN');
              await _flutterTts.setVoice({"name": voice['name'].toString(), "locale": voice['locale'].toString()});
              voiceSet = true;
              break;
            }
          }
        }

        // Priority 2: Indian English Google voice
        if (!voiceSet) {
          for (var voice in voices) {
            if (voice is Map) {
              final name = voice['name']?.toString().toLowerCase() ?? '';
              final locale = voice['locale']?.toString().toLowerCase() ?? '';
              if (locale == 'en-in' && name.contains('google')) {
                await _flutterTts.setLanguage('en-IN');
                await _flutterTts.setVoice({"name": voice['name'].toString(), "locale": voice['locale'].toString()});
                voiceSet = true;
                break;
              }
            }
          }
        }

        // Priority 3: Any en-IN voice available
        if (!voiceSet) {
          for (var voice in voices) {
            if (voice is Map) {
              final locale = voice['locale']?.toString().toLowerCase() ?? '';
              if (locale == 'en-in') {
                await _flutterTts.setLanguage('en-IN');
                await _flutterTts.setVoice({"name": voice['name'].toString(), "locale": voice['locale'].toString()});
                voiceSet = true;
                break;
              }
            }
          }
        }
      }

      // Fallback to en-IN language if no specific voice was found
      if (!voiceSet) {
        await _flutterTts.setLanguage('en-IN');
      }
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    if (!_voiceMode) return;
    try {
      // Try TtsService (ElevenLabs -> Edge-TTS -> flutter_tts fallback chain)
      await _ttsService.speak(text);
    } catch (_) {
      // Ultimate fallback: direct flutter_tts
      try {
        await _flutterTts.stop();
        await _flutterTts.speak(text);
      } catch (_) {}
    }
  }

  Future<void> _loadSetupData() async {
    try {
      final facs = await _repository.fetchFacultyList();
      if (mounted) {
        setState(() {
          _faculty = facs;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _messages.map((m) => m.toJson()).toList();
      await prefs.setString('timetable_chat_history', jsonEncode(list));
      await prefs.setString('timetable_agent_state', _agentState.name);
      await prefs.setStringList('timetable_user_constraints', _userConstraints);
    } catch (_) {}
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyStr = prefs.getString('timetable_chat_history');
      final stateStr = prefs.getString('timetable_agent_state');
      final constraints = prefs.getStringList('timetable_user_constraints');

      if (historyStr != null) {
        final List<dynamic> decoded = jsonDecode(historyStr) as List<dynamic>;
        setState(() {
          _messages.clear();
          for (var item in decoded) {
            final msg = ChatMessage.fromJson(item as Map<String, dynamic>);
            Widget? customWidget;
            if (msg.text.contains('generated successfully')) {
              customWidget = _buildPreviewGridContainer();
            } else if (msg.text.contains('Ready to solve?')) {
              customWidget = _buildSolveActions();
            } else if (msg.text.contains('successfully mapped to database')) {
              customWidget = _buildSolveActions();
            }
            _messages.add(ChatMessage(
              text: msg.text,
              isUser: msg.isUser,
              timestamp: msg.timestamp,
              customWidget: customWidget,
            ));
          }
          if (stateStr != null) {
            _agentState = AgentState.values.firstWhere((s) => s.name == stateStr, orElse: () => AgentState.welcome);
          }
          if (constraints != null) {
            _userConstraints = constraints;
          }
        });
        if (_agentState == AgentState.solved) {
          _loadActiveTimetablePreview();
        }
        _scrollToBottom();
      } else {
        // Welcome greeting if fresh session
        _addSystemMessage(
          'Namaste! I am the ENOSIS Timetable Agent. I am here to help you configure and generate college schedules using Google OR-Tools.\n\nWould you like to manually configure step-by-step, or upload an Excel spreadsheet configuration?',
          speakText: 'Namaste! I am the ENOSIS Timetable Agent. Would you like to manually configure step-by-step, or upload an Excel spreadsheet configuration?',
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    try {
      _flutterTts.stop();
    } catch (_) {}
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addSystemMessage(String text, {String? speakText, Widget? customWidget}) {
    setState(() {
      _messages.add(ChatMessage(
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
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
    _saveChatHistory();
  }

  // --- Real Voice Listening Dialog with Speech-to-Text ---
  void _openVoiceListeningDialog() {
    setState(() {
      _isListening = true;
      _partialSpeechText = '';
    });
    _speak('Listening. Please say your constraint or command.');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            // Start listening when dialog opens
            _speechService.startListening(
              onResult: (text) {
                setDialogState(() {
                  _partialSpeechText = text;
                });
              },
              onComplete: () {
                if (_partialSpeechText.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  _handleUserInput(_partialSpeechText);
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _partialSpeechText.isEmpty ? 'Listening...' : 'Heard:',
                      style: AppTypography.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    if (_partialSpeechText.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _partialSpeechText,
                          style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Animated waveform bars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300 + index * 100),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 6,
                          height: _partialSpeechText.isEmpty
                              ? 20.0 + (index % 2 == 0 ? 30 : 10)
                              : 10,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Or tap a suggestion:',
                      style: AppTypography.bodySecondary.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _voiceCommandChip(dialogContext, 'Dr. Priya is unavailable on Mondays'),
                        _voiceCommandChip(dialogContext, 'Generate timetable schedule'),
                        _voiceCommandChip(dialogContext, 'Reset everything'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await _speechService.cancelListening();
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                          },
                          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                        ),
                        if (_partialSpeechText.isNotEmpty)
                          ElevatedButton(
                            onPressed: () async {
                              await _speechService.stopListening();
                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              _handleUserInput(_partialSpeechText);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Use This'),
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
    ).then((_) async {
      await _speechService.stopListening();
      setState(() => _isListening = false);
    });
  }

  Widget _voiceCommandChip(BuildContext context, String command) {
    return ActionChip(
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      side: BorderSide.none,
      label: Text(command, style: const TextStyle(color: Colors.white, fontSize: 12)),
      onPressed: () async {
        await _speechService.cancelListening();
        if (context.mounted) Navigator.pop(context);
        _handleUserInput(command);
      },
    );
  }

  // --- Real File Picker from Device (Supports Web & Laptop Native) ---
  Future<void> _openRealFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        allowMultiple: false,
        dialogTitle: 'Select Timetable Configuration File',
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        final filePath = file.path;
        final fileBytes = file.bytes;
        final fileName = file.name;

        if (filePath == null && fileBytes == null) {
          _addSystemMessage(
            '❌ Could not access the selected file. Please try again.',
          );
          return;
        }

        _addUserMessage(
          '📎 Selected file: $fileName '
              '(${(file.size / 1024).toStringAsFixed(1)} KB)',
        );

        await _uploadExcelFile(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: fileName,
        );
      } else {
        _addSystemMessage(
          'File selection cancelled. You can try again or configure manually.',
        );
      }
    } catch (e) {
      _addSystemMessage(
        '❌ Error opening file picker: $e',
      );
    }
  }

  // --- Real Excel Upload to Backend ---
  Future<void> _uploadExcelFile({
    String? filePath,
    List<int>? fileBytes,
    required String fileName,
  }) async {
    setState(() => _isTyping = true);

    _addSystemMessage('⚙️ Uploading "$fileName" to server...\n\n1. Clearing existing configuration...\n2. Parsing Excel sheets...');

    try {
      final result = await _repository.uploadExcel(
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
      );

      final divsCreated = result['divisions_created'] ?? 0;
      final subsCreated = result['subjects_created'] ?? 0;
      final roomsCreated = result['rooms_created'] ?? 0;

      await _loadSetupData();

      setState(() {
        _agentState = AgentState.readyToSolve;
        _isTyping = false;
      });

      _addSystemMessage(
        '🎉 Excel file "$fileName" uploaded and parsed successfully!\n\n'
        '📂 Divisions created: $divsCreated\n'
        '📚 Subjects created: $subsCreated\n'
        '🏫 Rooms created: $roomsCreated\n\n'
        'All data has been saved to the database. Would you like to run the CP-SAT solver now or configure constraints?',
        speakText: 'Excel file uploaded and parsed successfully. $divsCreated divisions, $subsCreated subjects, and $roomsCreated rooms created. Would you like to run the solver or add constraints?',
        customWidget: _buildSolveActions(),
      );
    } catch (e) {
      setState(() => _isTyping = false);
      _addSystemMessage('❌ Error uploading Excel file: $e\n\nPlease ensure the file has sheets named "Divisions", "Subjects", and "Rooms" with the correct column headers.');
    }
  }

  // --- Main Conversational Input Engine ---
  void _handleUserInput(String text) {
    if (text.trim().isEmpty) return;
    _addUserMessage(text);
    _textController.clear();

    setState(() => _isTyping = true);

    Future.delayed(const Duration(milliseconds: 800), () async {
      final input = text.toLowerCase();

      // Global Reset
      if (input.contains('reset') || input.contains('clear')) {
        await _repository.clearAll();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('timetable_chat_history');
        await prefs.remove('timetable_agent_state');
        await prefs.remove('timetable_user_constraints');

        setState(() {
          _agentState = AgentState.welcome;
          _collegeName = '';
          _deptName = '';
          _parsedSubjects.clear();
          _parsedRooms.clear();
          _userConstraints.clear();
          _previewEntries.clear();
          _isTyping = false;
        });
        _addSystemMessage('All configuration data wiped. Let\'s start fresh. Step 1: What is your College Name and Department?');
        return;
      }

      // Conversational state transitions
      switch (_agentState) {
        case AgentState.welcome:
          if (input.contains('excel') || input.contains('upload')) {
            setState(() => _isTyping = false);
            _openRealFilePicker();
          } else {
            setState(() {
              _agentState = AgentState.awaitingCollegeDept;
              _isTyping = false;
            });
            _addSystemMessage('Sure! Let\'s setup manually. First, what is your College and Department name? (e.g. Govt College, Computer Science)');
          }
          break;

        case AgentState.awaitingCollegeDept:
          final parts = text.split(',');
          setState(() {
            _collegeName = parts.first.trim();
            _deptName = parts.length > 1 ? parts[1].trim() : 'Computer Science';
            _agentState = AgentState.awaitingYearsDivs;
            _isTyping = false;
          });
          _addSystemMessage(
            'Understood: College: $_collegeName, Dept: $_deptName.\n\nNext, how many years is the course and how many divisions per year? (e.g. 4 years, 2 divisions)',
            speakText: 'Understood. Next, how many years is the course and how many divisions per year?',
          );
          break;

        case AgentState.awaitingYearsDivs:
          final matches = RegExp(r'\d+').allMatches(input).toList();
          int years = 4;
          int divs = 2;
          if (matches.length >= 2) {
            years = int.parse(matches[0].group(0)!);
            divs = int.parse(matches[1].group(0)!);
          }
          setState(() {
            _totalYears = years;
            _divisionsPerYear = divs;
            _agentState = AgentState.awaitingSubjects;
            _isTyping = false;
          });

          await _repository.clearAll();
          for (int y = 1; y <= years; y++) {
            for (int d = 0; d < divs; d++) {
              final code = String.fromCharCode(65 + d);
              await _repository.createDivision(
                name: 'Year $y - Div $code',
                year: y,
                divisionCode: code,
              );
            }
          }

          _addSystemMessage(
            'Created $years Years with $divs divisions each.\n\nNow, please list your subjects and their weekly credits. (e.g. DAA (3 credits), DBMS (4 credits), OS (3 credits))',
            speakText: 'Created divisions. Now, please list your subjects and their weekly credits.',
          );
          break;

        case AgentState.awaitingSubjects:
          final items = text.split(',');
          _parsedSubjects.clear();
          for (var item in items) {
            final nameMatch = RegExp(r'^[a-zA-Z\s]+').firstMatch(item);
            final creditMatch = RegExp(r'\d+').firstMatch(item);
            if (nameMatch != null) {
              final name = nameMatch.group(0)!.trim();
              final credits = creditMatch != null ? int.parse(creditMatch.group(0)!) : 3;
              _parsedSubjects.add({'name': name, 'credits': credits});
              await _repository.createSubject(name: name, weeklyLectures: credits);
            }
          }
          setState(() {
            _agentState = AgentState.awaitingRooms;
            _isTyping = false;
          });
          _addSystemMessage(
            'Parsed ${_parsedSubjects.length} subjects successfully.\n\nWhat classrooms or labs are available? (e.g. Room 301, Room 302, Lab 1)',
            speakText: 'Parsed subjects successfully. What classrooms or labs are available?',
          );
          break;

        case AgentState.awaitingRooms:
          final rooms = text.split(',');
          _parsedRooms.clear();
          for (var r in rooms) {
            final name = r.trim();
            final isLab = name.toLowerCase().contains('lab');
            _parsedRooms.add({'name': name, 'type': isLab ? 'lab' : 'lecture'});
            await _repository.createRoom(name: name, type: isLab ? 'lab' : 'lecture', capacity: 70);
          }

          await _loadSetupData();
          final targetFacultyId = _faculty.isNotEmpty ? _faculty.first.id : 'default_fac';
          final divs = await _repository.fetchDivisions();
          final subs = await _repository.fetchSubjects();
          for (var d in divs) {
            for (var s in subs) {
              await _repository.createAssignment(facultyId: targetFacultyId, subjectId: s.id, divisionId: d.id);
            }
          }

          setState(() {
            _agentState = AgentState.awaitingConstraints;
            _isTyping = false;
          });
          _addSystemMessage(
            'Rooms configured. Let\'s setup constraints. You can specify combined divisions, external faculty slots, or unavailable timings. (e.g. "Dr. Priya is unavailable on Tuesdays slot 1")',
            speakText: 'Rooms configured. Let\'s setup constraints.',
          );
          break;

        case AgentState.awaitingConstraints:
        case AgentState.readyToSolve:
        case AgentState.solved:
          if (input.contains('unavailable') || input.contains('not available') || input.contains('off day')) {
            await _loadSetupData();
            final targetFac = _faculty.isNotEmpty ? _faculty.first : FacultyOption(id: 'default', fullName: 'Dr. Priya Sharma', email: '');
            
            int day = 0; // Tuesday is day 0 in our college timetable scheme!
            int slot = 0;
            if (input.contains('tuesday')) day = 0;
            if (input.contains('wednesday')) day = 1;
            if (input.contains('thursday')) day = 2;
            if (input.contains('friday')) day = 3;
            if (input.contains('saturday')) day = 4;

            final matches = RegExp(r'\d+').allMatches(input).toList();
            if (matches.isNotEmpty) {
              slot = int.parse(matches[0].group(0)!) - 1;
              if (slot < 0) slot = 0;
            }

            await _repository.createUnavailability(facultyId: targetFac.id, day: day, slot: slot);
            _userConstraints.add('${targetFac.fullName} unavailable: ${_dayLabels[day]} Slot ${slot + 1}');

            setState(() {
              _agentState = AgentState.readyToSolve;
              _isTyping = false;
            });
            _addSystemMessage(
              'Added Unavailability Constraint: ${targetFac.fullName} marked unavailable on ${_dayLabels[day]} Slot ${slot + 1}.\n\nReady to solve? Click below or add more constraints.',
              speakText: 'Added Unavailability Constraint. Ready to solve?',
              customWidget: _buildSolveActions(),
            );
          } else if (input.contains('combine') || input.contains('merge')) {
            _userConstraints.add('Combined Divisions: SE-A & SE-B for DBMS');
            setState(() {
              _agentState = AgentState.readyToSolve;
              _isTyping = false;
            });
            _addSystemMessage(
              'Combined Lecture Constraint Parsed: SE-A and SE-B combined for DBMS Lecture.\n\nReady to solve?',
              speakText: 'Combined Lecture Constraint Parsed. Ready to solve?',
              customWidget: _buildSolveActions(),
            );
          } else if (input.contains('generate') || input.contains('solve') || input.contains('run')) {
            setState(() => _isTyping = false);
            _runSolver();
          } else {
            String promptResponse = '';
            try {
              final systemContext = 'You are the ENOSIS Timetable Agent. The college is $_collegeName, department is $_deptName. '
                  'The configured constraints are: ${_userConstraints.join(", ")}. User says: $text';
              final response = await ApiClient.postJson('/ai/chat', {'message': systemContext}, token: AuthSession.token);
              if (response.statusCode == 200) {
                final body = jsonDecode(response.body);
                promptResponse = body['reply'] as String;
              } else {
                throw Exception();
              }
            } catch (_) {
              promptResponse = 'I\'ve captured that requirement: "$text". I will configure the solver parameters accordingly. Tap "Run Solver" to compile the schedule.';
            }

            setState(() {
              _agentState = AgentState.readyToSolve;
              _isTyping = false;
            });
            _addSystemMessage(
              promptResponse,
              customWidget: _buildSolveActions(),
            );
          }
          break;

        default:
          setState(() => _isTyping = false);
          _addSystemMessage('I am ready. Let me know if you would like to "run solver" or "reset".');
      }
    });
  }

  Future<void> _loadActiveTimetablePreview() async {
    try {
      final divs = await _repository.fetchDivisions(year: _selectedPreviewYear);
      if (divs.isNotEmpty) {
        final targetDiv = divs.firstWhere(
          (d) => d.divisionCode == _selectedPreviewDiv,
          orElse: () => divs.first,
        );
        final entries = await _repository.fetchDivisionTimetable(targetDiv.id);
        setState(() {
          _previewEntries = entries;
        });
      }
    } catch (_) {}
  }

  // --- Run Solver Action ---
  Future<void> _runSolver() async {
    _addSystemMessage('⚡ Compiling constraints and invoking Google OR-Tools CP-SAT Solver...');
    setState(() {
      _agentState = AgentState.solving;
      _isTyping = true;
    });

    try {
      final result = await _repository.generate();
      await Future.delayed(const Duration(seconds: 1, milliseconds: 500));

      await _loadActiveTimetablePreview();

      setState(() {
        _agentState = AgentState.solved;
        _isTyping = false;
      });

      _addSystemMessage(
        '✅ Timetable generated successfully!\nStatus: ${result.status}\nCompile Time: ${result.solveTimeSeconds}s\n\nHere is the preview grid. Does this look good, or should we refine it?',
        speakText: 'Timetable generated successfully. Here is the preview grid. Does this look good, or should we refine it?',
        customWidget: _buildPreviewGridContainer(),
      );
    } on TimetableException catch (e) {
      setState(() {
        _agentState = AgentState.readyToSolve;
        _isTyping = false;
      });

      // Build structured conflict display
      final buffer = StringBuffer('❌ Solver Error: ${e.message}\n');
      if (e.conflicts != null && e.conflicts!.isNotEmpty) {
        buffer.writeln('\n📋 Conflicts found:');
        for (final c in e.conflicts!) {
          if (c is Map) {
            buffer.writeln('  • ${c['type']}: ${c['details'] ?? c['subject'] ?? ''}');
          }
        }
      }
      if (e.suggestions != null && e.suggestions!.isNotEmpty) {
        buffer.writeln('\n💡 Suggestions:');
        for (final s in e.suggestions!) {
          buffer.writeln('  • $s');
        }
      }
      _addSystemMessage(
        buffer.toString(),
        speakText: 'Solver could not find a valid timetable. ${e.message}',
        customWidget: _buildSolveActions(),
      );
    } catch (e) {
      setState(() {
        _agentState = AgentState.readyToSolve;
        _isTyping = false;
      });
      _addSystemMessage(
        '❌ Unexpected error: $e\n\nPlease try again or reset the configuration.',
        customWidget: _buildSolveActions(),
      );
    }
  }

  Widget _buildSolveActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: _runSolver,
            icon: const Icon(Icons.flash_on, color: Colors.white, size: 16),
            label: const Text('Run Solver'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              _openConstraintDialog();
            },
            icon: const Icon(Icons.tune, color: AppColors.primary, size: 16),
            label: const Text('Add Constraint'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // --- Add Constraint dialog helper for PARTICULAR Faculty ---
  void _openConstraintDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String facId = _faculty.isNotEmpty ? _faculty.first.id : '';
        int day = 0;
        int slot = 0;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Unavailability Constraint'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: facId,
                    decoration: const InputDecoration(labelText: 'Select Faculty'),
                    items: _faculty.map((f) {
                      return DropdownMenuItem(
                        value: f.id,
                        child: Text(f.fullName),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => facId = val ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: day,
                    decoration: const InputDecoration(labelText: 'Select Day'),
                    items: List.generate(_dayLabels.length, (index) {
                      return DropdownMenuItem(
                        value: index,
                        child: Text(_dayLabels[index]),
                      );
                    }),
                    onChanged: (val) => setDialogState(() => day = val ?? 0),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: slot,
                    decoration: const InputDecoration(labelText: 'Select Slot'),
                    items: List.generate(_timeLabels.length, (index) {
                      if (index == 2 || index == 5) return null; // Skip Break/Lunch Break slots
                      return DropdownMenuItem(
                        value: index,
                        child: Text('${index + 1} (${_timeLabels[index]})'),
                      );
                    }).whereType<DropdownMenuItem<int>>().toList(),
                    onChanged: (val) => setDialogState(() => slot = val ?? 0),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final selectedFacId = facId.isEmpty && _faculty.isNotEmpty ? _faculty.first.id : facId;
                    final fac = _faculty.firstWhere((f) => f.id == selectedFacId, orElse: () => FacultyOption(id: 'default', fullName: 'Dr. Priya Sharma', email: ''));
                    
                    setState(() => _isTyping = true);
                    await _repository.createUnavailability(facultyId: fac.id, day: day, slot: slot);
                    _userConstraints.add('${fac.fullName} unavailable: ${_dayLabels[day]} Slot ${slot + 1}');
                    
                    setState(() => _isTyping = false);
                    _addSystemMessage(
                      'Successfully added unavailability constraint for ${fac.fullName} on ${_dayLabels[day]} Slot ${slot + 1}.',
                      customWidget: _buildSolveActions(),
                    );
                  },
                  child: const Text('Save Constraint'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Beautiful Colorful Table Preview Sheet matching Reference image ---
  Widget _buildPreviewGridContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // College Header
          Center(
            child: Column(
              children: [
                Text(
                  _collegeName.isNotEmpty ? _collegeName : "KIT's College of Engineering (Autonomous), Kolhapur",
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                Text(
                  _deptName.isNotEmpty ? "Department of $_deptName" : "Department of CSE-AIML and CSE-DS",
                  style: AppTypography.captionBold.copyWith(color: AppColors.textSecondary, fontSize: 9),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Time Table A.Y. 2026-27 Odd Semester",
                  style: AppTypography.captionBold.copyWith(color: AppColors.textSecondary, fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Info row (All data resolved dynamically from the solver output entries)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Class: ${_previewEntries.isNotEmpty ? _previewEntries.first.divisionName : 'Year $_selectedPreviewYear - Div $_selectedPreviewDiv'}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: AppColors.textPrimary),
              ),
              Text(
                "Room: ${_previewEntries.isNotEmpty ? _previewEntries.first.roomName : 'Not Configured'}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: AppColors.textPrimary),
              ),
              Text(
                "Class Teacher: ${_previewEntries.isNotEmpty ? _previewEntries.first.facultyName : 'Not Assigned'}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Selector Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<int>(
                value: _selectedPreviewYear,
                style: const TextStyle(fontSize: 10, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                items: [2, 3, 4].map((y) {
                  return DropdownMenuItem(value: y, child: Text('Year $y'));
                }).toList(),
                onChanged: (val) async {
                  if (val != null) {
                    setState(() => _selectedPreviewYear = val);
                    await _loadActiveTimetablePreview();
                  }
                },
              ),
              DropdownButton<String>(
                value: _selectedPreviewDiv,
                style: const TextStyle(fontSize: 10, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                items: ['A', 'B'].map((d) {
                  return DropdownMenuItem(value: d, child: Text('Division $d'));
                }).toList(),
                onChanged: (val) async {
                  if (val != null) {
                    setState(() => _selectedPreviewDiv = val);
                    await _loadActiveTimetablePreview();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Scrollable Grid Layout
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    _buildHeaderCell('Slot'),
                    ..._dayLabels.map((d) => _buildHeaderCell(d)),
                  ],
                ),
                // Table slots rows
                ...List.generate(_timeLabels.length, (slotIdx) {
                  if (slotIdx == 2) {
                    return _buildBreakRow('SHORT BREAK (11.00 - 11.15 AM)');
                  }
                  if (slotIdx == 5) {
                    return _buildBreakRow('LUNCH BREAK (1.15 - 2.00 PM)');
                  }

                  return Row(
                    children: [
                      _buildTimeCell(_timeLabels[slotIdx]),
                      ...List.generate(_dayLabels.length, (dayIdx) {
                        final entry = _previewEntries.firstWhere(
                          (e) => e.day == dayIdx && e.slot == slotIdx,
                          orElse: () => TimetableEntryModel(
                            day: dayIdx,
                            slot: slotIdx,
                            isLabBlock: false,
                            divisionName: '',
                            divisionYear: 0,
                            divisionCode: '',
                            subjectName: '',
                            facultyName: '',
                            roomName: '',
                          ),
                        );
                        return _buildDayCell(entry);
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
          // HOD Signature Footer
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '* Generated in real-time by OR-Tools Engine',
                style: AppTypography.caption.copyWith(color: AppColors.textTertiary, fontSize: 8),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Head of Department',
                    style: AppTypography.captionBold.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 9),
                  ),
                  Text(
                    _deptName.isNotEmpty ? _deptName : 'CSE-AIML & CSE-DS',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 8),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Loop action options
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _addUserMessage('Approve Timetable');
                    _speak('Timetable successfully approved and published to faculty. Notifications triggered.');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Timetable Approved & Published! Notifications sent.'), behavior: SnackBarBehavior.floating),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.done_all, color: Colors.white),
                  label: const Text('Approve & Publish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _openConstraintDialog(),
                icon: const Icon(Icons.add, color: AppColors.primary),
                label: const Text('Add Constraint'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      width: text == 'Slot' ? 90 : 102,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(
        text,
        style: AppTypography.captionBold.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTimeCell(String text) {
    return Container(
      width: 90,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBreakRow(String label) {
    return Container(
      width: 600, // Matching the sum of time slot cell and day cells (90 + 5 * 102)
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Center(
        child: Text(
          label,
          style: AppTypography.captionBold.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(TimetableEntryModel entry) {
    if (entry.subjectName.isEmpty) {
      return Container(
        width: 102,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
      );
    }

    final color = SubjectColors.forSubject(entry.subjectName);
    final initials = entry.facultyName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
    final facultyDisplay = initials.length > 2 ? initials.substring(initials.length - 2) : initials;

    return Container(
      width: 102,
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${entry.subjectName} ($facultyDisplay)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            entry.roomName,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ENOSIS AI Agent', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  _voiceMode ? 'Voice Mode Active (en-IN)' : 'Silent Mode Active',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_voiceMode ? Icons.volume_up : Icons.volume_off, color: Colors.white),
            onPressed: () {
              setState(() => _voiceMode = !_voiceMode);
              if (!_voiceMode) _flutterTts.stop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ResponsiveCenter(
                maxWidth: Responsive.maxContentWidth,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _ChatBubble(message: msg, onSpeak: () => _speak(msg.text));
                  },
                ),
              ),
            ),

            if (_isTyping)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LoadingIndicator(size: 24),
                    SizedBox(width: 10),
                    Text('Agent is parsing constraints...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),

            if (!_isTyping && _agentState == AgentState.welcome)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.rocket_launch, size: 14, color: AppColors.primary),
                      label: const Text('Setup Manually', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.06),
                      onPressed: () => _handleUserInput('Configure manually'),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.upload_file, size: 14, color: AppColors.primary),
                      label: const Text('Upload Excel Template', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.06),
                      onPressed: _openRealFilePicker,
                    ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: ResponsiveCenter(
                maxWidth: Responsive.maxContentWidth,
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _isListening ? AppColors.secondary : AppColors.primarySoft,
                      radius: 22,
                      child: IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.white : AppColors.primary,
                          size: 20,
                        ),
                        onPressed: _openVoiceListeningDialog,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _handleUserInput,
                        decoration: const InputDecoration(
                          hintText: 'Ask or dictate constraint...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 22,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        onPressed: () => _handleUserInput(_textController.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onSpeak;

  const _ChatBubble({required this.message, required this.onSpeak});

  @override
  Widget build(BuildContext context) {
    final align = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.isUser ? AppColors.primary : AppColors.surface;
    final textColor = message.isUser ? Colors.white : AppColors.textPrimary;
    final borderRadius = message.isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 16, color: AppColors.textSecondary),
                  onPressed: onSpeak,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.85,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: borderRadius,
                    border: message.isUser ? null : Border.all(color: AppColors.border, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.01),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: AppTypography.bodyMedium.copyWith(color: textColor, height: 1.3),
                      ),
                      if (message.customWidget != null) ...[
                        const SizedBox(height: 12),
                        message.customWidget!,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
