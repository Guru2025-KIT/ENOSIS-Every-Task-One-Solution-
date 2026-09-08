import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/attendance_models.dart';
import '../../data/models/dashboard_summary_model.dart';
import '../providers/attendance_provider.dart';

class LectureAttendanceSheet extends StatefulWidget {
  final TodayScheduleSlotModel slot;
  final DateTime sessionDate;
  final VoidCallback? onAttendanceSaved;

  const LectureAttendanceSheet({
    super.key,
    required this.slot,
    required this.sessionDate,
    this.onAttendanceSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required TodayScheduleSlotModel slot,
    required DateTime sessionDate,
    AttendanceProvider? provider,
    VoidCallback? onAttendanceSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        if (provider != null) {
          return ChangeNotifierProvider<AttendanceProvider>.value(
            value: provider,
            child: LectureAttendanceSheet(
              slot: slot,
              sessionDate: sessionDate,
              onAttendanceSaved: onAttendanceSaved,
            ),
          );
        }
        return ChangeNotifierProvider(
          create: (_) => AttendanceProvider(),
          child: LectureAttendanceSheet(
            slot: slot,
            sessionDate: sessionDate,
            onAttendanceSaved: onAttendanceSaved,
          ),
        );
      },
    );
  }

  @override
  State<LectureAttendanceSheet> createState() => _LectureAttendanceSheetState();
}

class _LectureAttendanceSheetState extends State<LectureAttendanceSheet> {
  late TextEditingController _topicController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController();
    _notesController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AttendanceProvider>();
      provider
          .loadSessionForSlot(
        timetableEntryId: widget.slot.timetableEntryId,
        sessionDate: widget.sessionDate,
      )
          .then((_) {
        if (mounted && provider.currentSession != null) {
          _topicController.text = provider.currentSession!.topicTaught ?? '';
          _notesController.text = provider.currentSession!.notes ?? '';
        }
      });
    });
  }

  @override
  void dispose() {
    _topicController.disposeRecursive();
    _notesController.disposeRecursive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final session = provider.currentSession;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fact_check_outlined, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.slot.subjectName,
                              style: AppTypography.h3.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (session != null && session.isRecorded)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                'Recorded',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.slot.divisionName} • Slot ${widget.slot.slotNumber} (${widget.slot.timeRange}) • ${widget.slot.roomName}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 24),

          // Body Content
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.errorMessage != null && session == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(
                                provider.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  provider.loadSessionForSlot(
                                    timetableEntryId: widget.slot.timetableEntryId,
                                    sessionDate: widget.sessionDate,
                                  );
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : session == null || session.records.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.group_off_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No students enrolled in this subject context.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              // Topic taught & notes row
                              TextField(
                                controller: _topicController,
                                onChanged: (v) => provider.updateTopicTaught(v),
                                decoration: InputDecoration(
                                  labelText: 'Topic Taught',
                                  hintText: 'e.g., Chapter 4: Concurrency & Semaphores',
                                  prefixIcon: const Icon(Icons.menu_book_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Quick Mark All bar
                              Row(
                                children: [
                                  Text(
                                    'Quick Actions:',
                                    style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => provider.markAll(AttendanceStatusType.present),
                                    icon: const Icon(Icons.done_all, size: 16, color: Colors.green),
                                    label: const Text('All Present', style: TextStyle(color: Colors.green, fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      side: BorderSide(color: Colors.green.shade300),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => provider.markAll(AttendanceStatusType.absent),
                                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
                                    label: const Text('All Absent', style: TextStyle(color: Colors.red, fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      side: BorderSide(color: Colors.red.shade300),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Student Roster
                              Text(
                                'Student Roster (${session.records.length})',
                                style: AppTypography.h3.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),

                              ...session.records.map((r) => _buildStudentAttendanceTile(r, provider, isMobile)),
                            ],
                          ),
          ),

          // Bottom Submission Bar
          if (session != null && session.records.isNotEmpty) _buildBottomBar(provider, session),
        ],
      ),
    );
  }

  Widget _buildStudentAttendanceTile(
    StudentAttendanceItemModel item,
    AttendanceProvider provider,
    bool isMobile,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              item.studentName.isNotEmpty ? item.studentName[0] : 'S',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  item.rollNumber ?? item.studentId,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          // 3-way toggle (P / A / L)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusButton(
                label: 'P',
                isSelected: item.status == AttendanceStatusType.present,
                selectedColor: Colors.green,
                onTap: () => provider.updateStudentStatus(item.enrollmentId, AttendanceStatusType.present),
              ),
              const SizedBox(width: 6),
              _buildStatusButton(
                label: 'L',
                isSelected: item.status == AttendanceStatusType.late,
                selectedColor: Colors.amber.shade700,
                onTap: () => provider.updateStudentStatus(item.enrollmentId, AttendanceStatusType.late),
              ),
              const SizedBox(width: 6),
              _buildStatusButton(
                label: 'A',
                isSelected: item.status == AttendanceStatusType.absent,
                selectedColor: Colors.red,
                onTap: () => provider.updateStudentStatus(item.enrollmentId, AttendanceStatusType.absent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(AttendanceProvider provider, AttendanceSessionModel session) {
    final presentCount = session.records.where((r) => r.status == AttendanceStatusType.present).length;
    final lateCount = session.records.where((r) => r.status == AttendanceStatusType.late).length;
    final absentCount = session.records.where((r) => r.status == AttendanceStatusType.absent).length;
    final total = session.records.length;
    final pct = total > 0 ? (((presentCount + lateCount) / total) * 100).toStringAsFixed(1) : '0.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Present: $presentCount | Late: $lateCount | Absent: $absentCount',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$pct% Attended',
                  style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: provider.isSubmitting
                    ? null
                    : () async {
                        final success = await provider.submitAttendance(
                          timetableEntryId: widget.slot.timetableEntryId,
                          sessionDate: widget.sessionDate,
                          slotNumber: widget.slot.slotNumber,
                        );
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Attendance saved successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          widget.onAttendanceSaved?.call();
                          Navigator.of(context).pop();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: provider.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        session.isRecorded ? 'Update Attendance' : 'Save Attendance',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension TextEditingControllerExtension on TextEditingController {
  void disposeRecursive() {
    dispose();
  }
}
