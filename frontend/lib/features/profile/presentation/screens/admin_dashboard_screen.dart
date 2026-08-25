import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../copo/presentation/screens/copo_progress_screen.dart';
import '../../../timetable/presentation/screens/timetable_hub_screen.dart';

class _PendingRequest {
  final String id;
  final String facultyName;
  final String type; // "FDP" | "Leave"
  final String title;

  _PendingRequest({
    required this.id,
    required this.facultyName,
    required this.type,
    required this.title,
  });
}

/// Screen 16 — Admin Dashboard.
///
/// Ref image features:
/// - Grid of KPI stat counters (Total Faculty, Pending Requests, Timetables, Tasks)
/// - Pending list cards with Approve/Reject text button pairs
/// - Redirect shortcuts (Generate Timetable, CO-PO Progress)
/// - Responsive grid scaling for laptop web
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final List<_PendingRequest> _requests = [
    _PendingRequest(id: 'r_1', facultyName: 'Dr. Priya Sharma', type: 'CAS', title: 'CAS Portfolio Verification Request - Tier II Promotion'),
    _PendingRequest(id: 'r_2', facultyName: 'Prof. Rajesh Kumar', type: 'Leave', title: 'Medical Leave Request: 14 Aug - 18 Aug (5 days)'),
    _PendingRequest(id: 'r_3', facultyName: 'Dr. Anil Mehta', type: 'FDP', title: 'FDP Attendance Approval: National Workshop on AI/ML'),
    _PendingRequest(id: 'r_4', facultyName: 'Prof. Sunita Rao', type: 'CAS', title: 'CAS Research Paper Validation: IEEE Communications'),
  ];

  void _handleAction(String id, bool approve) {
    setState(() {
      _requests.removeWhere((r) => r.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approve ? 'Request approved.' : 'Request rejected.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    // KPI Stat Grid
    final statsGrid = GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.3 : 1.5,
      children: [
        _buildStatCard('Total Faculty', '102', Icons.people_outline, AppColors.primary),
        _buildStatCard('Pending Approvals', '18', Icons.pending_actions, AppColors.warning),
        _buildStatCard('Timetables Generated', '14', Icons.event_note, AppColors.success),
        _buildStatCard('To-Do Overdue', '7', Icons.warning_amber_outlined, AppColors.error),
      ],
    );

    // Recent requests
    final requestsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Pending Approvals'),
        const SizedBox(height: 12),
        if (_requests.isEmpty)
          const AppCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No pending requests to verify.'),
              ),
            ),
          )
        else
          ..._requests.map((request) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          request.facultyName,
                          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                        AppChip(
                          label: request.type.toUpperCase(),
                          color: request.type == 'Leave'
                              ? AppColors.warning
                              : request.type == 'CAS'
                                  ? AppColors.primary
                                  : AppColors.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(request.title, style: AppTypography.bodySecondary),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _handleAction(request.id, false),
                          child: const Text('Reject', style: TextStyle(color: AppColors.error)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => _handleAction(request.id, true),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(90, 36)),
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );

    // Sidebar quick access shortcuts (web layout)
    final shortcutSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Management Tools'),
        const SizedBox(height: 12),
        AppCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TimetableHubScreen()),
            );
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Generate Timetable', style: TextStyle(fontWeight: FontWeight.w600)),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CopoProgressScreen()),
            );
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CO-PO Progress Tracker', style: TextStyle(fontWeight: FontWeight.w600)),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: Responsive.maxWideContentWidth,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                statsGrid,
                const SizedBox(height: 32),
                if (isMobile) ...[
                  requestsSection,
                  const SizedBox(height: 24),
                  shortcutSection,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: requestsSection),
                      const SizedBox(width: 24),
                      Expanded(flex: 4, child: shortcutSection),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: AppTypography.statNumber.copyWith(color: color, fontSize: 26),
                ),
                Icon(icon, color: color, size: 22),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppTypography.captionBold.copyWith(color: AppColors.textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
