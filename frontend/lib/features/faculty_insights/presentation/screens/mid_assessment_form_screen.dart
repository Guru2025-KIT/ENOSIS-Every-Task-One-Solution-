import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/mid_assessment_form.dart';
import '../providers/sli_mid_provider.dart';
import '../widgets/learning_barrier_chip_selector.dart';
import '../widgets/mid_pre_comparison_badge.dart';
import '../widgets/mid_topic_assessment_card.dart';
import '../widgets/rating_scale_picker.dart';
import '../widgets/skills_progress_card.dart';

/// 6-Step Guided Form Screen for Faculty-Driven MID-Semester Assessment.
class MidAssessmentFormScreen extends StatelessWidget {
  const MidAssessmentFormScreen({super.key});

  static const List<String> _stepTitles = [
    'Current Perception & Grasp',
    'Practical & Application',
    'Teaching Pace & Format',
    'Learning Barriers',
    'Target Skills Progress',
    'Topic-Level Progress',
  ];

  static const List<Map<String, String>> midLearningFormats = [
    {'key': 'INTERACTIVE_LECTURES', 'label': 'Interactive Lectures & Discussions'},
    {'key': 'PRACTICAL_LABS', 'label': 'Hands-on Labs & Practical Coding'},
    {'key': 'SELF_PACED_ONLINE', 'label': 'Self-Paced Online & Recorded Videos'},
    {'key': 'PEER_STUDY', 'label': 'Peer Study & Group Problem Solving'},
    {'key': 'HYBRID', 'label': 'Hybrid & Blended Learning'},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Consumer<SliMidProvider>(
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
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'MID',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      form != null ? form.studentName : 'MID-Semester Assessment',
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
                          'Loading assessment data...',
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
    SliMidProvider provider,
    MidAssessmentForm form,
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
                  // PRE Baseline Summary Banner (shown across all steps)
                  _buildPreBaselineBanner(form),
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

  Widget _buildStepHeader(BuildContext context, SliMidProvider provider, bool isMobile) {
    final current = provider.currentStep;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
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
                    color: const Color(0xFF7C3AED),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (current + 1) / _stepTitles.length,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreBaselineBanner(MidAssessmentForm form) {
    final baseline = form.preBaseline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0284C7).withOpacity(0.08),
            const Color(0xFF7C3AED).withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Color(0xFF0284C7), size: 18),
              const SizedBox(width: 8),
              Text(
                'PRE-Semester Baseline Reference',
                style: AppTypography.captionBold.copyWith(
                  color: const Color(0xFF0284C7),
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
                    'MID RECORDED',
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
          if (baseline.hasPreAssessment) ...[
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _BaselinePill(label: 'Confidence', value: '${baseline.learningConfidence ?? '-'}/5'),
                _BaselinePill(label: 'Interest', value: '${baseline.subjectInterest ?? '-'}/5'),
                _BaselinePill(label: 'Exp. Difficulty', value: '${baseline.expectedDifficulty ?? '-'}/5'),
                if (baseline.preferredLearningFormat != null)
                  _BaselinePill(label: 'Format', value: baseline.preferredLearningFormat!),
              ],
            ),
            if (baseline.skillsToImprove != null && baseline.skillsToImprove!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Target Skills from PRE: ${baseline.skillsToImprove}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ] else ...[
            Text(
              'No PRE-Semester baseline was recorded for this student. You are recording their mid-semester state directly.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveStep(
    BuildContext context,
    SliMidProvider provider,
    MidAssessmentForm form,
    bool isMobile,
  ) {
    switch (provider.currentStep) {
      case 0:
        return _buildStep1CurrentPerception(provider, form);
      case 1:
        return _buildStep2PracticalApplication(provider, form);
      case 2:
        return _buildStep3PaceAndFormat(provider, form);
      case 3:
        return _buildStep4LearningBarriers(provider, form);
      case 4:
        return _buildStep5SkillsProgress(provider, form);
      case 5:
        return _buildStep6TopicProgress(provider, form);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1: Current Perception & Grasp ──────────────────────────────────
  Widget _buildStep1CurrentPerception(SliMidProvider provider, MidAssessmentForm form) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Current Confidence & Understanding',
          'Measure the student\'s active grasp and subject enthusiasm halfway through the semester.',
        ),
        const SizedBox(height: 18),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Current Subject Confidence',
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  MidPreComparisonBadge(
                    label: 'Confidence',
                    preValue: form.preBaseline.learningConfidence,
                    midValue: form.currentConfidence,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Subject Confidence Level',
                selectedValue: form.currentConfidence,
                onChanged: provider.setCurrentConfidence,
                lowLabel: 'Low (1)',
                highLabel: 'Very High (5)',
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Current Subject Interest & Motivation',
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  MidPreComparisonBadge(
                    label: 'Interest',
                    preValue: form.preBaseline.subjectInterest,
                    midValue: form.currentInterest,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Interest & Engagement',
                selectedValue: form.currentInterest,
                onChanged: provider.setCurrentInterest,
                lowLabel: 'Low Interest (1)',
                highLabel: 'Highly Engaged (5)',
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Perceived Difficulty Encountered',
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  MidPreComparisonBadge(
                    label: 'Difficulty',
                    preValue: form.preBaseline.expectedDifficulty,
                    midValue: form.perceivedDifficulty,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              RatingScalePicker(
                title: 'Perceived Difficulty',
                selectedValue: form.perceivedDifficulty,
                onChanged: provider.setPerceivedDifficulty,
                lowLabel: 'Very Easy (1)',
                highLabel: 'Very Challenging (5)',
              ),

              const SizedBox(height: 24),

              RatingScalePicker(
                title: 'Overall Understanding Level',
                subtitle: 'Superficial grasp vs deep intuitive mental model',
                selectedValue: form.understandingLevel,
                onChanged: provider.setUnderstandingLevel,
                lowLabel: 'Superficial (1)',
                highLabel: 'Deep & Intuitive (5)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Practical & Application ─────────────────────────────────────
  Widget _buildStep2PracticalApplication(SliMidProvider provider, MidAssessmentForm form) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Practical Application & Satisfaction',
          'Evaluate how well the student can apply concepts in assignments, coding, or problem-solving.',
        ),
        const SizedBox(height: 18),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RatingScalePicker(
                title: 'Concept Application Ability',
                subtitle: 'Ability to solve unseen problems or design implementations independently',
                selectedValue: form.conceptApplicationAbility,
                onChanged: provider.setConceptApplicationAbility,
                lowLabel: 'Needs Heavy Guidance (1)',
                highLabel: 'Fully Independent (5)',
              ),

              const SizedBox(height: 24),

              RatingScalePicker(
                title: 'Practical / Lab Experience',
                subtitle: 'Quality of hands-on laboratory exercises, simulations, and tooling exposure',
                selectedValue: form.practicalLabExperience,
                onChanged: provider.setPracticalLabExperience,
                lowLabel: 'Poor (1)',
                highLabel: 'Excellent (5)',
              ),

              const SizedBox(height: 24),

              RatingScalePicker(
                title: 'Overall Learning Satisfaction',
                subtitle: 'Student\'s general satisfaction with current progress in this course',
                selectedValue: form.learningSatisfaction,
                onChanged: provider.setLearningSatisfaction,
                lowLabel: 'Unsatisfied (1)',
                highLabel: 'Highly Satisfied (5)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 3: Teaching Pace & Format ──────────────────────────────────────
  Widget _buildStep3PaceAndFormat(SliMidProvider provider, MidAssessmentForm form) {
    const paces = [
      {'key': 'TOO_SLOW', 'label': 'Too Slow', 'icon': Icons.slow_motion_video},
      {'key': 'JUST_RIGHT', 'label': 'Just Right (Optimal)', 'icon': Icons.check_circle_outline},
      {'key': 'TOO_FAST', 'label': 'Too Fast', 'icon': Icons.fast_forward},
    ];

    const formats = [
      {'key': 'INTERACTIVE_LECTURES', 'label': 'Interactive Lectures & Discussions'},
      {'key': 'PRACTICAL_LABS', 'label': 'Hands-on Labs & Practical Coding'},
      {'key': 'SELF_PACED_ONLINE', 'label': 'Self-Paced Online & Recorded Videos'},
      {'key': 'PEER_STUDY', 'label': 'Peer Study & Group Problem Solving'},
      {'key': 'HYBRID', 'label': 'Hybrid & Blended Learning'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Teaching Pace & Pedagogy',
          'Feedback on delivery speed and instructional formats found most helpful during the semester.',
        ),
        const SizedBox(height: 18),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pace of Teaching Delivery',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: paces.map((p) {
                  final isSelected = form.teachingPace == p['key'];
                  return ChoiceChip(
                    selected: isSelected,
                    avatar: Icon(
                      p['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                    label: Text(
                      p['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    backgroundColor: AppColors.background,
                    selectedColor: const Color(0xFF7C3AED),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF7C3AED) : AppColors.border,
                    ),
                    onSelected: (selected) {
                      provider.setTeachingPace(selected ? (p['key'] as String) : null);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              Text(
                'Most Useful Learning Format Experienced',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: formats.map((f) {
                  final isSelected = form.usefulLearningFormat == f['key'];
                  return ChoiceChip(
                    selected: isSelected,
                    label: Text(
                      f['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    backgroundColor: AppColors.background,
                    selectedColor: const Color(0xFF0284C7),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF0284C7) : AppColors.border,
                    ),
                    onSelected: (selected) {
                      provider.setUsefulLearningFormat(selected ? (f['key'] as String) : null);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              RatingScalePicker(
                title: 'Resource & Course Material Effectiveness',
                subtitle: 'Clarity and adequacy of notes, assignments, and slides',
                selectedValue: form.resourceEffectiveness,
                onChanged: provider.setResourceEffectiveness,
                lowLabel: 'Insufficient (1)',
                highLabel: 'Comprehensive (5)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 4: Learning Barriers ───────────────────────────────────────────
  Widget _buildStep4LearningBarriers(SliMidProvider provider, MidAssessmentForm form) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Learning Barriers & Obstacles',
          'Identify key friction points or bottlenecks hindering student mastery during the term.',
        ),
        const SizedBox(height: 18),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select All Active Learning Barriers',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'These signals feed directly into root cause diagnostics for faculty action.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              LearningBarrierChipSelector(
                selectedBarriers: form.learningBarriers,
                onToggle: provider.toggleLearningBarrier,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 5: Target Skills Progress ──────────────────────────────────────
  Widget _buildStep5SkillsProgress(SliMidProvider provider, MidAssessmentForm form) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Target Skills Progress',
          'Track tangible progress on specific skills identified during the PRE-Semester baseline.',
        ),
        const SizedBox(height: 18),

        SkillsProgressListWidget(
          skills: form.skillsProgress,
          onConfidenceChanged: provider.setSkillConfidence,
          onStatusChanged: provider.setSkillProgressStatus,
          onAddSkill: provider.addSkill,
          onRemoveSkill: provider.removeSkill,
        ),
      ],
    );
  }

  // ─── Step 6: Topic Progress & Coverage ───────────────────────────────────
  Widget _buildStep6TopicProgress(SliMidProvider provider, MidAssessmentForm form) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Topic-Level Grasp & Progress',
          'Evaluate each curriculum topic delivered so far, comparing against PRE baseline expectations.',
        ),
        const SizedBox(height: 18),

        if (form.topics.isEmpty)
          _buildCard(
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'No topics have been configured for this subject yet. You can submit the general MID assessment directly.',
                    style: AppTypography.bodySecondary,
                  ),
                ),
              ],
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
              return MidTopicAssessmentCard(
                index: index,
                topic: topic,
                onConfidenceChanged: (c) => provider.setTopicMidConfidence(topic.topicId, c),
                onDifficultyChanged: (d) => provider.setTopicMidDifficulty(topic.topicId, d),
                onStatusChanged: (s) => provider.setTopicProgressStatus(topic.topicId, s),
              );
            },
          ),
      ],
    );
  }

  // ─── Bottom Navigation & Submit Bar ──────────────────────────────────────
  Widget _buildBottomBar(
    BuildContext context,
    SliMidProvider provider,
    MidAssessmentForm form,
    bool isMobile,
  ) {
    final isLastStep = provider.currentStep == _stepTitles.length - 1;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ResponsiveCenter(
        maxWidth: 860,
        child: Row(
          children: [
            if (provider.currentStep > 0)
              OutlinedButton.icon(
                onPressed: provider.isSubmitting ? null : provider.previousStep,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            const Spacer(),
            if (!isLastStep)
              ElevatedButton.icon(
                onPressed: provider.nextStep,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Next Step'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              )
            else
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  form.isSubmitted ? 'Update MID Assessment' : 'Submit MID Assessment',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, SliMidProvider provider) {
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
              Text('MID Assessment Recorded'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The MID-Semester evaluation has been atomically saved for ${provider.form?.studentName}.',
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
  final String label;
  final String value;

  const _BaselinePill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0284C7),
            ),
          ),
        ],
      ),
    );
  }
}
