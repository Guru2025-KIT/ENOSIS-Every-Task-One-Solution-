import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/end_assessment_form.dart';
import '../providers/sli_end_provider.dart';
import '../widgets/end_pre_mid_comparison_badge.dart';
import '../widgets/end_topic_assessment_card.dart';
import '../widgets/rating_scale_picker.dart';
import '../widgets/skills_progress_card.dart';

/// 6-Step Guided Form Screen for Faculty-Driven END-Semester Assessment.
class EndAssessmentFormScreen extends StatelessWidget {
  const EndAssessmentFormScreen({super.key});

  static const List<String> _stepTitles = [
    'Final Grasp & Understanding',
    'Final Competency & Application',
    'End-of-Course Experience',
    'Target Skills Mastery',
    'Final Topic-Level Mastery',
    'Review & Submit',
  ];

  static const List<Map<String, String>> endLearningFormats = [
    {'key': 'INTERACTIVE_LECTURES', 'label': 'Interactive Lectures & Discussions'},
    {'key': 'PRACTICAL_LABS', 'label': 'Hands-on Labs & Practical Coding'},
    {'key': 'SELF_PACED_ONLINE', 'label': 'Self-Paced Online & Recorded Videos'},
    {'key': 'PEER_STUDY', 'label': 'Peer Study & Group Problem Solving'},
    {'key': 'HYBRID', 'label': 'Hybrid & Blended Learning'},
  ];

  static const List<Map<String, String>> teachingPaces = [
    {'key': 'TOO_SLOW', 'label': 'Too Slow'},
    {'key': 'JUST_RIGHT', 'label': 'Just Right / Optimal'},
    {'key': 'TOO_FAST', 'label': 'Too Fast'},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Consumer<SliEndProvider>(
      builder: (context, provider, child) {
        final form = provider.form;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'END',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      form != null ? form.studentName : 'END-Semester Assessment',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (form != null)
                  Text(
                    '${form.studentId} • ${form.subjectName} (${form.divisionName})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: SafeArea(
            child: provider.isLoadingForm
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LoadingIndicator(size: 44),
                        SizedBox(height: 16),
                        Text(
                          'Loading END assessment data...',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : provider.formError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load assessment',
                                style: AppTypography.h4.copyWith(color: AppColors.error),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                provider.formError!,
                                style: AppTypography.bodySecondary,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  if (provider.selectedStudent != null) {
                                    provider.loadAssessmentForStudent(provider.selectedStudent!);
                                  }
                                },
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : form == null
                        ? const Center(child: Text('No student selected'))
                        : _buildFormContent(context, provider, form, isMobile),
          ),
        );
      },
    );
  }

  Widget _buildFormContent(
    BuildContext context,
    SliEndProvider provider,
    EndAssessmentForm form,
    bool isMobile,
  ) {
    return Column(
      children: [
        // Stepper Progress Header
        _buildStepHeader(context, provider, isMobile),

        // Scrollable Step Body
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: 20,
            ),
            child: ResponsiveCenter(
              maxWidth: 860,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lifecycle / Read-only notice for non-ACTIVE semesters (COMPLETED, ARCHIVED, CANCELLED)
                  if (form.semesterStatus != 'ACTIVE') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, color: Color(0xFFD97706), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Semester ${form.semesterStatus} — Read-Only Mode',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'This semester is ${form.semesterStatus.toLowerCase()}. Historical assessment data can be reviewed, but further modifications are locked.',
                                  style: AppTypography.caption.copyWith(
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // PRE & MID Longitudinal Baseline Reference Banner
                  _buildLongitudinalBaselineBanner(form),
                  const SizedBox(height: 18),

                  // Active Step Content
                  _buildActiveStep(context, provider, form, isMobile),

                  if (provider.submissionError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              provider.submissionError!,
                              style: AppTypography.caption.copyWith(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),

        // Bottom Navigation & Submit Bar
        _buildBottomBar(context, provider, form, isMobile),
      ],
    );
  }

  Widget _buildStepHeader(BuildContext context, SliEndProvider provider, bool isMobile) {
    final current = provider.currentStep;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ResponsiveCenter(
        maxWidth: 860,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Step ${current + 1} of ${_stepTitles.length}: ${_stepTitles[current]}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '${((current + 1) / _stepTitles.length * 100).toInt()}% Complete',
                  style: AppTypography.caption.copyWith(
                    color: const Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (current + 1) / _stepTitles.length,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLongitudinalBaselineBanner(EndAssessmentForm form) {
    final pre = form.preBaseline;
    final mid = form.midBaseline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0284C7).withOpacity(0.06),
            const Color(0xFF7C3AED).withOpacity(0.06),
            const Color(0xFF16A34A).withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 8),
              Text(
                'LONGITUDINAL BASELINE TRAJECTORY',
                style: AppTypography.captionBold.copyWith(
                  color: const Color(0xFF16A34A),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (form.isSubmitted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'END RECORDED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (pre.hasPreAssessment) ...[
                _BaselinePill(
                  stage: 'PRE',
                  label: 'Conf',
                  value: '${pre.learningConfidence ?? '-'}/5',
                  color: const Color(0xFF0284C7),
                ),
                _BaselinePill(
                  stage: 'PRE',
                  label: 'Interest',
                  value: '${pre.subjectInterest ?? '-'}/5',
                  color: const Color(0xFF0284C7),
                ),
                _BaselinePill(
                  stage: 'PRE',
                  label: 'Exp. Diff',
                  value: '${pre.expectedDifficulty ?? '-'}/5',
                  color: const Color(0xFF0284C7),
                ),
              ] else
                _NoBaselinePill(stage: 'PRE'),

              if (mid.hasMidAssessment) ...[
                _BaselinePill(
                  stage: 'MID',
                  label: 'Conf',
                  value: '${mid.currentConfidence ?? '-'}/5',
                  color: const Color(0xFF7C3AED),
                ),
                _BaselinePill(
                  stage: 'MID',
                  label: 'Interest',
                  value: '${mid.currentInterest ?? '-'}/5',
                  color: const Color(0xFF7C3AED),
                ),
                _BaselinePill(
                  stage: 'MID',
                  label: 'Perc. Diff',
                  value: '${mid.perceivedDifficulty ?? '-'}/5',
                  color: const Color(0xFF7C3AED),
                ),
              ] else
                _NoBaselinePill(stage: 'MID'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStep(
    BuildContext context,
    SliEndProvider provider,
    EndAssessmentForm form,
    bool isMobile,
  ) {
    final isReadOnly = form.semesterStatus != 'ACTIVE';

    switch (provider.currentStep) {
      case 0:
        return _buildStep1FinalGrasp(provider, form, isReadOnly);
      case 1:
        return _buildStep2FinalCompetency(provider, form, isReadOnly);
      case 2:
        return _buildStep3EndOfCourseExperience(provider, form, isReadOnly);
      case 3:
        return _buildStep4SkillsMastery(provider, form, isReadOnly);
      case 4:
        return _buildStep5TopicMastery(provider, form, isReadOnly);
      case 5:
        return _buildStep6ReviewAndSubmit(context, provider, form, isReadOnly);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1: Final Grasp & Understanding ─────────────────────────────────
  Widget _buildStep1FinalGrasp(
    SliEndProvider provider,
    EndAssessmentForm form,
    bool isReadOnly,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Final Subject Understanding & Perception',
          'Assess the student\'s final grasp, retrospective difficulty, and learning satisfaction upon course completion.',
        ),
        const SizedBox(height: 18),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Final Confidence
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Final Subject Confidence & Mastery',
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  EndPreMidComparisonBadge(
                    label: 'Confidence',
                    preValue: form.preBaseline.learningConfidence,
                    midValue: form.midBaseline.currentConfidence,
                    endValue: form.finalConfidence,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Subject Confidence Level',
                selectedValue: form.finalConfidence,
                onChanged: isReadOnly ? (_) {} : provider.setFinalConfidence,
                lowLabel: 'Low Confidence (1)',
                highLabel: 'Mastered / High (5)',
              ),

              const SizedBox(height: 24),

              // Final Interest
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Final Subject Interest & Engagement',
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  EndPreMidComparisonBadge(
                    label: 'Interest',
                    preValue: form.preBaseline.subjectInterest,
                    midValue: form.midBaseline.currentInterest,
                    endValue: form.finalInterest,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Subject Interest & Enthusiasm',
                selectedValue: form.finalInterest,
                onChanged: isReadOnly ? (_) {} : provider.setFinalInterest,
                lowLabel: 'Low Interest (1)',
                highLabel: 'Passionate / High (5)',
              ),

              const SizedBox(height: 24),

              // Perceived Difficulty (Retrospective)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Final Retrospective Subject Difficulty',
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  EndPreMidComparisonBadge(
                    label: 'Difficulty',
                    preValue: form.preBaseline.expectedDifficulty,
                    midValue: form.midBaseline.perceivedDifficulty,
                    endValue: form.perceivedDifficulty,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Final/retrospective perceived difficulty after completing the course.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Course Difficulty Encountered',
                selectedValue: form.perceivedDifficulty,
                onChanged: isReadOnly ? (_) {} : provider.setPerceivedDifficulty,
                lowLabel: 'Very Easy (1)',
                highLabel: 'Very Difficult (5)',
              ),

              const SizedBox(height: 24),

              // Understanding Level
              Text(
                'Overall Conceptual Understanding Level',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Depth of Subject Understanding',
                selectedValue: form.understandingLevel,
                onChanged: isReadOnly ? (_) {} : provider.setUnderstandingLevel,
                lowLabel: 'Surface Level (1)',
                highLabel: 'Comprehensive (5)',
              ),

              const SizedBox(height: 24),

              // Concept Application Ability
              Text(
                'Concept Application & Synthesis',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Ability to Apply Concepts in New Contexts',
                selectedValue: form.conceptApplicationAbility,
                onChanged: isReadOnly ? (_) {} : provider.setConceptApplicationAbility,
                lowLabel: 'Struggles (1)',
                highLabel: 'Highly Fluent (5)',
              ),

              const SizedBox(height: 24),

              // Learning Satisfaction
              Text(
                'Overall Learning Satisfaction',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Satisfaction with Course Outcomes',
                selectedValue: form.learningSatisfaction,
                onChanged: isReadOnly ? (_) {} : provider.setLearningSatisfaction,
                lowLabel: 'Dissatisfied (1)',
                highLabel: 'Extremely Satisfied (5)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Final Competency & Application ──────────────────────────────
  Widget _buildStep2FinalCompetency(
    SliEndProvider provider,
    EndAssessmentForm form,
    bool isReadOnly,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Final Competency & Application',
          'Evaluate the student\'s demonstrated capabilities across five key competency dimensions.',
        ),
        const SizedBox(height: 18),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Core Concepts Mastery
              Text(
                '1. Core Concepts Mastery',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                'Grasp of foundational principles, definitions, and core theoretical structures.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Core Concepts Mastery',
                selectedValue: form.coreConceptsMastery,
                onChanged: isReadOnly ? (_) {} : provider.setCoreConceptsMastery,
                lowLabel: 'Novice (1)',
                highLabel: 'Mastery (5)',
              ),

              const SizedBox(height: 24),

              // Problem Solving Ability
              Text(
                '2. Problem-Solving Ability',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                'Analytical thinking, problem formulation, and systematic solution design.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Problem-Solving Competence',
                selectedValue: form.problemSolvingAbility,
                onChanged: isReadOnly ? (_) {} : provider.setProblemSolvingAbility,
                lowLabel: 'Limited (1)',
                highLabel: 'Exceptional (5)',
              ),

              const SizedBox(height: 24),

              // Practical / Lab Competence
              Text(
                '3. Practical & Lab Competence',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                'Hands-on execution, code implementation, experimentation, and tool usage.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Practical Lab Competence',
                selectedValue: form.practicalLabCompetence,
                onChanged: isReadOnly ? (_) {} : provider.setPracticalLabCompetence,
                lowLabel: 'Dependent (1)',
                highLabel: 'Autonomous / Fluent (5)',
              ),

              const SizedBox(height: 24),

              // Independent Learning Ability
              Text(
                '4. Independent Learning Ability',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                'Self-directed research, debugging skills, and learning from technical documentation.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Independent Learning Ability',
                selectedValue: form.independentLearningAbility,
                onChanged: isReadOnly ? (_) {} : provider.setIndependentLearningAbility,
                lowLabel: 'Low (1)',
                highLabel: 'Strong Self-Learner (5)',
              ),

              const SizedBox(height: 24),

              // Real-World Application
              Text(
                '5. Real-World Application & Project Readiness',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                'Connecting academic theory to industry practices, case studies, and engineering projects.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Real-World Application Ability',
                selectedValue: form.realWorldApplication,
                onChanged: isReadOnly ? (_) {} : provider.setRealWorldApplication,
                lowLabel: 'Theoretical Only (1)',
                highLabel: 'Production Ready (5)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 3: End-of-Course Experience ────────────────────────────────────
  Widget _buildStep3EndOfCourseExperience(
    SliEndProvider provider,
    EndAssessmentForm form,
    bool isReadOnly,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'End-of-Course Learning Experience',
          'Review pedagogical delivery, teaching pace, and resource effectiveness over the full term.',
        ),
        const SizedBox(height: 18),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Effective Learning Format
              Text(
                'Most Effective Learning Format for this Student',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: endLearningFormats.map((fmt) {
                  final isSelected = form.effectiveLearningFormat == fmt['key'];
                  return ChoiceChip(
                    selected: isSelected,
                    label: Text(
                      fmt['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    backgroundColor: AppColors.background,
                    selectedColor: const Color(0xFF16A34A),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF16A34A) : AppColors.border,
                    ),
                    onSelected: isReadOnly
                        ? null
                        : (selected) {
                            provider.setEffectiveLearningFormat(selected ? fmt['key'] : null);
                          },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Resource Effectiveness
              Text(
                'Course Resources & Study Materials Effectiveness',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Resource & Material Quality',
                selectedValue: form.resourceEffectiveness,
                onChanged: isReadOnly ? (_) {} : provider.setResourceEffectiveness,
                lowLabel: 'Ineffective (1)',
                highLabel: 'Highly Effective (5)',
              ),

              const SizedBox(height: 24),

              // Practical Lab Experience
              Text(
                'Practical / Lab Experience Quality',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Lab & Hands-On Experience Quality',
                selectedValue: form.practicalLabExperience,
                onChanged: isReadOnly ? (_) {} : provider.setPracticalLabExperience,
                lowLabel: 'Inadequate (1)',
                highLabel: 'Excellent (5)',
              ),

              const SizedBox(height: 24),

              // Teaching Pace
              Text(
                'Course Delivery & Teaching Pace Suitability',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: teachingPaces.map((pace) {
                  final isSelected = form.teachingPace == pace['key'];
                  return ChoiceChip(
                    selected: isSelected,
                    label: Text(
                      pace['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    backgroundColor: AppColors.background,
                    selectedColor: const Color(0xFF16A34A),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF16A34A) : AppColors.border,
                    ),
                    onSelected: isReadOnly
                        ? null
                        : (selected) {
                            provider.setTeachingPace(selected ? pace['key'] : null);
                          },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Overall Learning Experience
              Text(
                'Overall Learning Experience Rating',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Overall Educational Experience',
                selectedValue: form.overallLearningExperience,
                onChanged: isReadOnly ? (_) {} : provider.setOverallLearningExperience,
                lowLabel: 'Poor (1)',
                highLabel: 'Outstanding (5)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 4: Target Skills Mastery ───────────────────────────────────────
  Widget _buildStep4SkillsMastery(
    SliEndProvider provider,
    EndAssessmentForm form,
    bool isReadOnly,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Target Skills Mastery',
          'Evaluate the final mastery level for skills identified during PRE and tracked in MID.',
        ),
        const SizedBox(height: 18),

        SkillsProgressListWidget(
          skills: form.skillsProgress,
          onConfidenceChanged: isReadOnly ? (_, __) {} : provider.updateSkillConfidence,
          onStatusChanged: isReadOnly ? (_, __) {} : provider.updateSkillStatus,
          onAddSkill: isReadOnly ? (_) {} : provider.addSkill,
          onRemoveSkill: isReadOnly ? (_) {} : provider.removeSkill,
        ),
      ],
    );
  }

  // ─── Step 5: Final Topic-Level Mastery ───────────────────────────────────
  Widget _buildStep5TopicMastery(
    SliEndProvider provider,
    EndAssessmentForm form,
    bool isReadOnly,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Final Topic-Level Mastery',
          'Record final mastery, retrospective difficulty, and status for each syllabus topic.',
        ),
        const SizedBox(height: 18),

        if (form.topics.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'No syllabus topics available for this subject.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: form.topics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final topic = form.topics[index];
              return EndTopicAssessmentCard(
                index: index,
                topic: topic,
                readOnly: isReadOnly,
                onConfidenceChanged: (c) => provider.setTopicConfidence(topic.topicId, c),
                onDifficultyChanged: (d) => provider.setTopicDifficulty(topic.topicId, d),
                onStatusChanged: (s) => provider.setTopicStatus(topic.topicId, s),
              );
            },
          ),
      ],
    );
  }

  // ─── Step 6: Review & Submit ─────────────────────────────────────────────
  Widget _buildStep6ReviewAndSubmit(
    BuildContext context,
    SliEndProvider provider,
    EndAssessmentForm form,
    bool isReadOnly,
  ) {
    final assessedTopics = form.topics.where((t) => t.endConfidence != null).length;
    final masteredSkills = form.skillsProgress.where((s) => s.progressStatus == 'MASTERED').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Review & Final Assessment Summary',
          'Review the complete END-Semester assessment profile before recording the final outcome.',
        ),
        const SizedBox(height: 18),

        // Summary KPI Row
        Row(
          children: [
            Expanded(
              child: _buildSummaryKpiCard(
                'Final Confidence',
                '${form.finalConfidence ?? '-'}/5',
                const Color(0xFF16A34A),
                Icons.star,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryKpiCard(
                'Topics Assessed',
                '$assessedTopics / ${form.topics.length}',
                const Color(0xFF0284C7),
                Icons.checklist,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryKpiCard(
                'Skills Mastered',
                '$masteredSkills / ${form.skillsProgress.length}',
                const Color(0xFF7C3AED),
                Icons.emoji_events,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Final Competency Breakdown
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Final Competency Profile',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildReviewRow('Core Concepts Mastery', '${form.coreConceptsMastery ?? '-'}/5'),
              _buildReviewRow('Problem Solving Ability', '${form.problemSolvingAbility ?? '-'}/5'),
              _buildReviewRow('Practical / Lab Competence', '${form.practicalLabCompetence ?? '-'}/5'),
              _buildReviewRow('Independent Learning Ability', '${form.independentLearningAbility ?? '-'}/5'),
              _buildReviewRow('Real-World Application', '${form.realWorldApplication ?? '-'}/5'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Course Experience Breakdown
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Course Experience & Delivery',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildReviewRow(
                'Effective Format',
                form.effectiveLearningFormat ?? 'Not specified',
              ),
              _buildReviewRow(
                'Teaching Pace',
                form.teachingPace ?? 'Not specified',
              ),
              _buildReviewRow('Resource Effectiveness', '${form.resourceEffectiveness ?? '-'}/5'),
              _buildReviewRow('Practical Lab Experience', '${form.practicalLabExperience ?? '-'}/5'),
              _buildReviewRow('Overall Learning Experience', '${form.overallLearningExperience ?? '-'}/5'),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Bottom Navigation Bar ───────────────────────────────────────────────
  Widget _buildBottomBar(
    BuildContext context,
    SliEndProvider provider,
    EndAssessmentForm form,
    bool isMobile,
  ) {
    final current = provider.currentStep;
    final isLast = current == _stepTitles.length - 1;
    final isReadOnly = form.semesterStatus != 'ACTIVE';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ResponsiveCenter(
        maxWidth: 860,
        child: Row(
          children: [
            if (current > 0)
              OutlinedButton.icon(
                onPressed: provider.isSubmitting ? null : provider.previousStep,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            const Spacer(),
            if (!isLast)
              ElevatedButton.icon(
                onPressed: provider.nextStep,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Next Step'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
              )
            else if (!isReadOnly)
              ElevatedButton.icon(
                onPressed: provider.isSubmitting
                    ? null
                    : () async {
                        final success = await provider.submitAssessment();
                        if (success && context.mounted) {
                          _showSuccessDialog(context, provider);
                        }
                      },
                icon: provider.isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle, size: 18),
                label: Text(provider.isSubmitting ? 'Saving...' : 'Save END Assessment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Semester ${form.semesterStatus} (Read-Only)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, SliEndProvider provider) {
    final res = provider.lastSubmissionResponse;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 28),
              SizedBox(width: 10),
              Text('END Assessment Recorded'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The END-Semester assessment has been atomically saved for ${provider.form?.studentName}.',
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildMetricRow('Topic Evaluations Recorded', '${res?.topicsRecorded ?? 0}'),
                    const SizedBox(height: 4),
                    _buildMetricRow('Skills Tracked', '${res?.skillsRecorded ?? 0}'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // dismiss dialog
                Navigator.of(context).pop(); // return to roster screen
              },
              child: const Text('Back to Roster'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryKpiCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.h3.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.caption),
          Text(
            value,
            style: AppTypography.captionBold.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.caption),
        Text(
          value,
          style: AppTypography.captionBold.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.h3.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.bodySecondary,
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _BaselinePill extends StatelessWidget {
  final String stage;
  final String label;
  final String value;
  final Color color;

  const _BaselinePill({
    required this.stage,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              stage,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoBaselinePill extends StatelessWidget {
  final String stage;

  const _NoBaselinePill({required this.stage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'No $stage Baseline',
        style: const TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
