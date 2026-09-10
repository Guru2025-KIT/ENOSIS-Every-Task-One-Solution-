import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import 'teaching_contexts_screen.dart';

/// Screen for the Faculty Insights Module.
///
/// Houses the 4-stage academic intelligence pipeline, beginning with
/// Stage 01: Student Perception & PRE-Semester Assessment.
class FacultyInsightsScreen extends StatelessWidget {
  const FacultyInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.psychology_outlined, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Faculty Insights',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 16 : 24,
          ),
          child: ResponsiveCenter(
            maxWidth: Responsive.maxDashboardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4338CA).withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF818CF8).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.4)),
                        ),
                        child: const Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Icon(Icons.auto_awesome, color: Color(0xFFA5B4FC), size: 14),
                            Text(
                              'STUDENT LEARNING INTELLIGENCE (SLI)',
                              style: TextStyle(
                                color: Color(0xFFE0E7FF),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Understand What Students Experience.\nDiscover What Actually Happens.',
                        style: (isMobile ? AppTypography.h3 : AppTypography.h2).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'ENOSIS bridges the critical gap between early student perception and end-of-semester verified CO-PO outcomes, recommending precise interventions.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: isMobile ? 13 : 14.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Active Stage 01 Focus Cards: PRE, MID & END Semester Assessments
                if (isMobile) ...[
                  _PreSemesterActionCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TeachingContextsScreen(stage: 'PRE'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _MidSemesterActionCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TeachingContextsScreen(stage: 'MID'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _EndSemesterActionCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TeachingContextsScreen(stage: 'END'),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PreSemesterActionCard(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TeachingContextsScreen(stage: 'PRE'),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MidSemesterActionCard(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TeachingContextsScreen(stage: 'MID'),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _EndSemesterActionCard(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TeachingContextsScreen(stage: 'END'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 28),

                // Core ML Pipeline Overview
                Text(
                  'Intelligent Academic Cycle Pipeline',
                  style: AppTypography.h3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Continuous feedback loop analyzing learning trends across course modules',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // 4 Stage Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stages = [
                      {
                        'step': '01',
                        'title': 'Student Perception',
                        'desc': 'Formative feedback & concept confidence before and during topic delivery.',
                        'icon': Icons.record_voice_over_outlined,
                        'color': const Color(0xFF0284C7),
                        'active': true,
                        'actionText': 'Open Student Perception',
                        'route': 'PRE',
                      },
                      {
                        'step': '02',
                        'title': 'Gap Detection',
                        'desc': 'ML models identify diverging trends between perceived grasp and continuous assessments.',
                        'icon': Icons.troubleshoot_outlined,
                        'color': const Color(0xFF7C3AED),
                        'active': true,
                        'actionText': 'Detect Learning Gaps',
                        'route': 'GAP_DETECTION',
                      },
                      {
                        'step': '03',
                        'title': 'Faculty Action',
                        'desc': 'Recommended pedagogical adjustments, remedial sessions, and lab emphasis.',
                        'icon': Icons.touch_app_outlined,
                        'color': const Color(0xFFF4791E),
                        'active': true,
                        'actionText': 'Take Action & Intervene',
                        'route': 'ACTION',
                      },
                      {
                        'step': '04',
                        'title': 'Verified Outcome',
                        'desc': 'End-term summative attainment matrix validates effectiveness for the next cycle.',
                        'icon': Icons.verified_outlined,
                        'color': const Color(0xFF16A34A),
                        'active': true,
                        'actionText': 'Verify Outcomes',
                        'route': 'END',
                      },
                    ];

                    if (isMobile) {
                      return Column(
                        children: stages.map((st) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _StageCard(
                              stage: st,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TeachingContextsScreen(
                                      stage: st['route'] as String,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: stages.map((st) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: _StageCard(
                              stage: st,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TeachingContextsScreen(
                                      stage: st['route'] as String,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // Status Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.insights_outlined,
                          color: Color(0xFF0284C7),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Full Academic Cycle Pipeline Active',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'All 4 stages are connected: Student Perception (PRE), Gap Detection (ML Analytics), Faculty Action (Interventions), and Verified Outcomes (END Assessment).',
                              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreSemesterActionCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PreSemesterActionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: Color(0xFF0284C7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STAGE 01 • STUDENT PERCEPTION',
                      style: AppTypography.captionBold.copyWith(
                        color: const Color(0xFF0284C7),
                        letterSpacing: 0.8,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PRE-Semester Student Assessment',
                      style: AppTypography.h4.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Capture students\' baseline understanding, learning preferences and goals before the semester begins.',
            style: AppTypography.bodySecondary.copyWith(height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text(
                'Manage & Record PRE Assessments',
                style: TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MidSemesterActionCard extends StatelessWidget {
  final VoidCallback onTap;

  const _MidSemesterActionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Color(0xFF7C3AED),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STAGE 01 • IN-PROGRESS GRASP',
                      style: AppTypography.captionBold.copyWith(
                        color: const Color(0xFF7C3AED),
                        letterSpacing: 0.8,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MID-Semester Student Assessment',
                      style: AppTypography.h4.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Track active grasp, pace feedback, learning barriers, and progress against baseline target skills.',
            style: AppTypography.bodySecondary.copyWith(height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text(
                'Manage & Record MID Assessments',
                style: TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndSemesterActionCard extends StatelessWidget {
  final VoidCallback onTap;

  const _EndSemesterActionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified_outlined,
                  color: Color(0xFF16A34A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STAGE 01 • FINAL OUTCOME',
                      style: AppTypography.captionBold.copyWith(
                        color: const Color(0xFF16A34A),
                        letterSpacing: 0.8,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'END-Semester Assessment',
                      style: AppTypography.h4.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Record final subject grasp, competency ratings, course experience, and topic/skills mastery outcomes.',
            style: AppTypography.bodySecondary.copyWith(height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text(
                'Manage & Record END Assessments',
                style: TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  final Map<String, dynamic> stage;
  final VoidCallback? onTap;

  const _StageCard({required this.stage, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = stage['color'] as Color;
    final bool isActive = stage['active'] == true;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? color.withOpacity(0.5) : AppColors.border,
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(stage['icon'] as IconData, color: color, size: 20),
                ),
                Text(
                  stage['step'] as String,
                  style: AppTypography.captionBold.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              stage['title'] as String,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stage['desc'] as String,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    (stage['actionText'] as String?) ?? 'Open Assessment',
                    style: AppTypography.captionBold.copyWith(
                      color: color,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 12, color: color),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
