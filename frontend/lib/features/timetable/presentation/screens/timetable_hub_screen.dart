import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/timetable_provider.dart';
import 'time_slot_setup_screen.dart';
import 'upload_assignments_screen.dart';
import 'manage_rooms_screen.dart';
import 'constraint_builder_screen.dart';
import 'interactive_slot_locking_workbench_screen.dart';
import 'generate_timetable_screen.dart';
import 'timetable_display_screen.dart';

class TimetableHubScreen extends StatefulWidget {
  const TimetableHubScreen({super.key});

  @override
  State<TimetableHubScreen> createState() => _TimetableHubScreenState();
}

class _TimetableHubScreenState extends State<TimetableHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimetableProvider>().initializeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();

    final roomCount = provider.roomModels.length;
    final assignCount = provider.assignments.length;
    final constraintCount = provider.constraints.length;
    final hasPublished = provider.publishedTimetable.isNotEmpty;
    final config = provider.scheduleConfig;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.calendar_month, color: Color(0xFFF97316), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Timetable Management',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (hasPublished)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: TextButton.icon(
                icon: const Icon(Icons.grid_view_rounded, color: Color(0xFFFB923C), size: 18),
                label: const Text(
                  'View Timetable',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C).withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TimetableDisplayScreen()),
                  );
                },
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HERO BANNER (DARK CARD WITH ORANGE TEXT & HIGHLIGHTS) ──────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFF97316)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Standard Academic Setup Flow',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      if (hasPublished)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: const Text(
                            'Active Schedule Ready',
                            style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Academic Schedule & Solver',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Complete the 5 guided steps below to configure your department structure, faculty workload, and solve clash-free schedules.',
                    style: TextStyle(color: Color(0xFFFB923C), fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 18),

                  // Stats row
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _buildHeaderBadge(
                        'Working Days',
                        '${config?.workingDays ?? 6} Days',
                        Icons.today_outlined,
                      ),
                      _buildHeaderBadge(
                        'Workloads',
                        '$assignCount Assigned',
                        Icons.assignment_turned_in_outlined,
                      ),
                      _buildHeaderBadge(
                        'Classrooms & Labs',
                        '$roomCount Rooms',
                        Icons.meeting_room_outlined,
                      ),
                      _buildHeaderBadge(
                        'Constraints',
                        '$constraintCount Rules',
                        Icons.gavel_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── STEPS PROGRESS SECTION ─────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'GUIDED TIMETABLE CREATION STEPS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // STEP 1: Time Slot Setup
            _buildStepCard(
              context: context,
              stepNumber: 1,
              title: 'Time Slots & Daily Schedule',
              subtitle: 'Configure college start & end timings, lecture duration, and break slots.',
              badgeText: '${config?.periodsPerDay ?? 8} Periods/Day',
              icon: Icons.schedule_rounded,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TimeSlotSetupScreen()),
                );
              },
            ),

            const SizedBox(height: 12),

            // STEP 2: Workload & Assignments
            _buildStepCard(
              context: context,
              stepNumber: 2,
              title: 'Faculty Workload & Assignments',
              subtitle: 'Upload Excel master data or manually assign theory/lab courses to faculty.',
              badgeText: '$assignCount Workloads',
              icon: Icons.upload_file_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UploadAssignmentsScreen()),
                );
              },
            ),

            const SizedBox(height: 12),

            // STEP 3: Classrooms & Labs
            _buildStepCard(
              context: context,
              stepNumber: 3,
              title: 'Classrooms & Lab Management',
              subtitle: 'Import or add lecture rooms, laboratory infrastructure, and seating capacities.',
              badgeText: '$roomCount Rooms Available',
              icon: Icons.door_front_door_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageRoomsScreen()),
                );
              },
            ),

            const SizedBox(height: 12),

            // STEP 4: Constraints & Unavailability
            _buildStepCard(
              context: context,
              stepNumber: 4,
              title: 'Department & Faculty Constraints',
              subtitle: 'Set faculty unavailability, fixed slots, spread rules, and lunch policies.',
              badgeText: '$constraintCount Active Rules',
              icon: Icons.rule_folder_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConstraintBuilderScreen()),
                );
              },
            ),

            const SizedBox(height: 12),

            // STEP 4.5: Interactive Slot Locking & AI Advisor Workbench
            _buildStepCard(
              context: context,
              stepNumber: 5,
              title: 'Interactive Slot Locking & Groq AI Workbench',
              subtitle: 'Drag-and-drop Open Electives, MDM courses, and lock slots with Groq AI advisor recommendations.',
              badgeText: 'Priority Locking 🔒',
              icon: Icons.lock_clock_outlined,
              isHighlighted: true,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InteractiveSlotLockingWorkbenchScreen()),
                );
              },
            ),

            const SizedBox(height: 12),

            // STEP 6: Generate & Publish Timetable
            _buildStepCard(
              context: context,
              stepNumber: 6,
              title: 'Generate & Publish Timetable',
              subtitle: 'Run CP-SAT solver with automated relaxation to produce a complete schedule.',
              badgeText: hasPublished ? 'Schedule Ready' : 'Ready to Solve',
              icon: Icons.auto_awesome,
              isHighlighted: false,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GenerateTimetableScreen()),
                );
              },
            ),

            const SizedBox(height: 24),

            // ── QUICK ACTIONS BANNER (DARK CARD WITH ORANGE HIGHLIGHTS) ────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFF97316)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.table_chart_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'View & Export Timetable',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Inspect published schedules by class, teacher, or classroom, and export to Excel/PDF.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFB923C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TimetableDisplayScreen()),
                      );
                    },
                    child: const Text('Open Grid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBadge(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFF97316), size: 14),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(color: Color(0xFFFB923C), fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required BuildContext context,
    required int stepNumber,
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return Card(
      elevation: isHighlighted ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isHighlighted ? const Color(0xFFF97316) : const Color(0xFF334155),
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      color: const Color(0xFF0F172A),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isHighlighted
                        ? [const Color(0xFFEA580C), const Color(0xFFF97316)]
                        : [const Color(0xFF1E293B), const Color(0xFF334155)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: isHighlighted ? const Color(0xFFFDBA74) : const Color(0xFF475569)),
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isHighlighted ? const Color(0xFFF97316) : const Color(0xFF334155),
                            ),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isHighlighted ? const Color(0xFFF97316) : const Color(0xFFFB923C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFB923C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isHighlighted ? const Color(0xFFF97316) : const Color(0xFFFB923C),
              ),
            ],
          ),
        ),
      ),
    );
  }

}