import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/attendance_repository.dart';

/// Screen 10 — Face Recognition Mark Attendance screen.
///
/// Ref image features:
/// - Screen title "Mark Attendance"
/// - Camera preview in a green-bordered circle (face match frame)
/// - Scan animation line across circle
/// - "Face Verified / Attendance Marked Successfully" success banner
/// - Details card (Check-in time, date)
/// - "Check Out" or "Check In" button at bottom
class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen>
    with SingleTickerProviderStateMixin {
  final _repository = AttendanceRepository();
  late final AnimationController _scanController;

  bool _isScanning = false;
  bool _isVerified = false;
  bool _isSubmitting = false;
  String? _errorMsg;

  AttendanceRecordModel? _activeSession;
  final String _mockLocation = '19.0760° N, 72.8777° E'; // Mumbai University Campus

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _checkActiveSession();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _checkActiveSession() async {
    final active = await _repository.fetchActiveAttendance();
    if (mounted) {
      setState(() {
        _activeSession = active;
        _isVerified = active != null; // if active session exists, already verified
      });
    }
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _isVerified = false;
      _errorMsg = null;
    });
    _scanController.repeat(reverse: true);

    // Simulate face scan process
    Future.delayed(const Duration(seconds: 2, milliseconds: 500), () async {
      if (!mounted) return;
      _scanController.stop();

      try {
        setState(() => _isSubmitting = true);
        final session = await _repository.checkIn(location: _mockLocation);
        if (mounted) {
          setState(() {
            _activeSession = session;
            _isScanning = false;
            _isVerified = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _errorMsg = 'Verification failed. Please try again.';
          });
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    });
  }

  Future<void> _handleCheckOut() async {
    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
    });

    try {
      await _repository.checkOut();
      if (mounted) {
        setState(() {
          _activeSession = null;
          _isVerified = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checked out successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'Failed to check out.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = _activeSession != null
        ? '${_activeSession!.checkInTime.hour.toString().padLeft(2, '0')}:${_activeSession!.checkInTime.minute.toString().padLeft(2, '0')} ${_activeSession!.checkInTime.hour >= 12 ? 'PM' : 'AM'}'
        : '--:--';
    final formattedDate = _activeSession != null
        ? '${_activeSession!.checkInTime.day.toString().padLeft(2, '0')} ${_getMonthName(_activeSession!.checkInTime.month)} ${_activeSession!.checkInTime.year}'
        : '-- --- ----';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mark Attendance'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: Responsive.maxContentWidth,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Face Verification',
                  style: AppTypography.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _activeSession != null
                      ? 'Attendance logged for today'
                      : 'Align your face inside the frame to scan',
                  style: AppTypography.bodySecondary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Camera Scanner Circular Frame
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Circular Frame Container
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isVerified
                                ? AppColors.success
                                : (_isScanning ? AppColors.primary : AppColors.border),
                            width: 4,
                          ),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        // Inside: Mock Camera feed or Avatar
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.face_retouching_natural,
                              size: 100,
                              color: AppColors.textSecondary,
                            ),
                            if (_isScanning)
                              AnimatedBuilder(
                                animation: _scanController,
                                builder: (context, child) {
                                  final yOffset = _scanController.value * 200;
                                  return Positioned(
                                    top: yOffset,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.secondary.withOpacity(0.5),
                                            blurRadius: 6,
                                            spreadRadius: 2,
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),

                      // Verification tick badge
                      if (_isVerified)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Success / Status message banner
                if (_isVerified) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Face Verified',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Attendance Marked Successfully',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (_errorMsg != null) ...[
                  Text(
                    _errorMsg!,
                    style: AppTypography.bodySecondary.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: 24),
                ],

                // Check-in Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Check-in Time', style: AppTypography.bodySecondary),
                            Text(
                              formattedTime,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Date', style: AppTypography.bodySecondary),
                            Text(
                              formattedDate,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Submit Button
                if (_isScanning)
                  const SizedBox(
                    height: 52,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_isSubmitting)
                  const SizedBox(
                    height: 52,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_activeSession != null)
                  PrimaryButton(
                    label: 'Check Out',
                    onPressed: _handleCheckOut,
                  )
                else
                  PrimaryButton(
                    label: 'Scan & Check In',
                    onPressed: _startScanning,
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
