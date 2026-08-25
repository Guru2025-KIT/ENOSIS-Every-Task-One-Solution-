import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'time_slot_setup_screen.dart';
import 'upload_assignments_screen.dart';
import 'constraint_builder_screen.dart';
import 'generate_timetable_screen.dart';     // Added import
import 'timetable_display_screen.dart';       // Added import

class TimetableHubScreen extends StatelessWidget {
  const TimetableHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Management'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timetable Module', style: AppTypography.h2),
            const SizedBox(height: 8),
            Text(
              'Manage, constrain, and generate department timetables.',
              style: AppTypography.bodySecondary,
            ),
            const SizedBox(height: 32),
            
            // 1. Setup Time Structure
            _buildActionCard(
              context,
              icon: Icons.timer_outlined,
              title: 'Setup Time Structure',
              subtitle: 'Define lecture start/end times and breaks.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TimeSlotSetupScreen()),
                );
              },
            ),
            const SizedBox(height: 16),

            // 2. Upload Master Data
            _buildActionCard(
              context,
              icon: Icons.upload_file_outlined,
              title: 'Upload Master Data',
              subtitle: 'Upload Excel sheet of faculty subject assignments.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UploadAssignmentsScreen()),
                );
              },
            ),
            const SizedBox(height: 16),

            // 3. Manage Constraints
            _buildActionCard(
              context,
              icon: Icons.rule_folder_outlined,
              title: 'Manage Constraints',
              subtitle: 'Define fixed slots, OE timings, and faculty availability.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConstraintBuilderScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // 4. View Current Timetable
            _buildActionCard(
              context,
              icon: Icons.table_chart_outlined,
              title: 'View Current Timetable',
              subtitle: 'See the active schedule for all classes and faculty.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TimetableDisplayScreen()), // Navigates to display
                );
              },
            ),
            const SizedBox(height: 16),

            // 5. Generate New Timetable
            _buildActionCard(
              context,
              icon: Icons.auto_fix_high,
              title: 'Generate New Timetable',
              subtitle: 'Run the algorithm to create a clash-free schedule.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GenerateTimetableScreen()), // Navigates to generate
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build the cards
  Widget _buildActionCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTypography.caption.copyWith(color: Colors.grey[600])),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}