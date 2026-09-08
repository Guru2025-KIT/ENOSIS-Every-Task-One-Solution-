import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/pre_assessment_form.dart';
import '../providers/sli_pre_provider.dart';
import '../widgets/content_type_chip_selector.dart';
import '../widgets/rating_scale_picker.dart';
import '../widgets/topic_assessment_card.dart';

/// Multi-step form for recording or editing a student's PRE-Semester Assessment.
class PreAssessmentFormScreen extends StatelessWidget {
  const PreAssessmentFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Consumer<SliPreProvider>(
      builder: (context, provider, child) {
        final form = provider.form;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              form != null
                  ? (form.isSubmitted ? 'Edit PRE Assessment' : 'Record PRE Assessment')
                  : 'PRE Assessment',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
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
                          'Loading student assessment form...',
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
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load form',
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Go Back to Roster'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : form == null
                        ? const Center(child: Text('No assessment form available.'))
                        : _buildFormContent(context, provider, form, isMobile),
          ),
        );
      },
    );
  }

  Widget _buildFormContent(
    BuildContext context,
    SliPreProvider provider,
    PreAssessmentForm form,
    bool isMobile,
  ) {
    return Column(
      children: [
        // Stepper Navigation Indicator
        _buildStepProgressBar(provider),

        // Existing Assessment Notification Banner
        if (form.isSubmitted)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFE8F0FE),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Existing assessment recorded on ${_formatDate(form.submittedAt)}. Submitting will update this assessment.',
                    style: AppTypography.captionBold.copyWith(
                      color: AppColors.info,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Scrollable Active Step Content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: isMobile ? 16 : 24,
            ),
            child: ResponsiveCenter(
              maxWidth: Responsive.maxDashboardWidth,
              child: _buildCurrentStep(context, provider, form, isMobile),
            ),
          ),
        ),

        // Bottom Navigation Action Bar
        _buildBottomActionBar(context, provider, form),
      ],
    );
  }

  Widget _buildStepProgressBar(SliPreProvider provider) {
    final stepTitles = [
      'Overview',
      'Subject',
      'Preferences',
      'Career',
      'Topics',
      'Review',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: List.generate(stepTitles.length, (index) {
          final isCurrent = provider.currentStep == index;
          final isDone = provider.currentStep > index;

          return Expanded(
            child: InkWell(
              onTap: () => provider.setStep(index),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 3,
                          color: index == 0
                              ? Colors.transparent
                              : (isDone || isCurrent
                                  ? AppColors.primary
                                  : AppColors.border),
                        ),
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppColors.success
                              : isCurrent
                                  ? AppColors.primary
                                  : AppColors.surfaceVariant,
                          border: Border.all(
                            color: isDone
                                ? AppColors.success
                                : isCurrent
                                    ? AppColors.primary
                                    : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: isDone
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                      ),
                      Expanded(
                        child: Container(
                          height: 3,
                          color: index == stepTitles.length - 1
                              ? Colors.transparent
                              : (isDone
                                  ? AppColors.primary
                                  : AppColors.border),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stepTitles[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? AppColors.primary : AppColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep(
    BuildContext context,
    SliPreProvider provider,
    PreAssessmentForm form,
    bool isMobile,
  ) {
    switch (provider.currentStep) {
      case 0:
        return _buildStep1StudentSubject(form);
      case 1:
        return _buildStep2SubjectRatings(provider, form);
      case 2:
        return _buildStep3LearningPreferences(provider, form);
      case 3:
        return _buildStep4CareerGoals(provider, form);
      case 4:
        return _buildStep5TopicAssessment(provider, form);
      case 5:
        return _buildStep6ReviewSubmit(provider, form);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── STEP 1: Student & Subject Info ───────────────────────────────────────
  Widget _buildStep1StudentSubject(PreAssessmentForm form) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: 1,
          title: 'Student & Academic Context',
          subtitle:
              'Verify the student profile and enrolled subject details before recording baseline feedback.',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Information',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Full Name', form.studentName),
              _buildDetailRow('Student ID / PRN', form.studentId),
              _buildDetailRow('Class', form.className),
              _buildDetailRow('Year & Division', '${form.yearDisplay} • Div ${form.division}'),
              const Divider(color: AppColors.divider, height: 24),
              Text(
                'Subject & Semester Context',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Subject', form.subjectName),
              if (form.subjectCode != null)
                _buildDetailRow('Subject Code', form.subjectCode!),
              _buildDetailRow('Semester', 'Semester ${form.semesterNumber}'),
              if (form.academicYear != null)
                _buildDetailRow('Academic Year', form.academicYear!),
              _buildDetailRow('Semester Status', form.semesterStatus),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STEP 2: Subject-Level Ratings ────────────────────────────────────────
  Widget _buildStep2SubjectRatings(SliPreProvider provider, PreAssessmentForm form) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: 2,
          title: 'Subject Baseline Perception',
          subtitle:
              'Rate the student\'s baseline readiness, interest, and expected difficulty for this subject (1 to 5).',
        ),
        const SizedBox(height: 18),
        RatingScalePicker(
          title: 'Subject Interest',
          subtitle: 'How interested is the student in learning this subject?',
          selectedValue: form.subjectInterest,
          lowLabel: '1 = Low interest',
          highLabel: '5 = Highly passionate',
          onChanged: (val) => provider.setSubjectInterest(val),
        ),
        const SizedBox(height: 14),
        RatingScalePicker(
          title: 'Self-Assessed Skill Level',
          subtitle: 'Prior prerequisite knowledge and foundational skill level.',
          selectedValue: form.selfAssessedSkill,
          lowLabel: '1 = Absolute beginner',
          highLabel: '5 = Advanced knowledge',
          onChanged: (val) => provider.setSelfAssessedSkill(val),
        ),
        const SizedBox(height: 14),
        RatingScalePicker(
          title: 'Learning Confidence',
          subtitle: 'Confidence in grasping course concepts and achieving good grades.',
          selectedValue: form.learningConfidence,
          lowLabel: '1 = Not confident',
          highLabel: '5 = Extremely confident',
          onChanged: (val) => provider.setLearningConfidence(val),
        ),
        const SizedBox(height: 14),
        RatingScalePicker(
          title: 'Expected Difficulty',
          subtitle: 'How difficult does the student anticipate this subject to be?',
          selectedValue: form.expectedDifficulty,
          lowLabel: '1 = Very easy',
          highLabel: '5 = Extremely challenging',
          onChanged: (val) => provider.setExpectedDifficulty(val),
        ),
      ],
    );
  }

  // ─── STEP 3: Learning Preferences ─────────────────────────────────────────
  Widget _buildStep3LearningPreferences(
    SliPreProvider provider,
    PreAssessmentForm form,
  ) {
    const formats = [
      'Interactive Classroom Lectures',
      'Hands-on Lab & Practical Sessions',
      'Self-Paced Online Learning',
      'Group Discussions & Peer Learning',
      'Hybrid / Blended Learning',
    ];

    const costOptions = [
      {'val': 'FREE', 'label': 'Free Open Resources'},
      {'val': 'PAID', 'label': 'Paid Certifications & Platforms'},
      {'val': 'BOTH', 'label': 'Both Free & Paid Resources'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: 3,
          title: 'Learning Preferences & Formats',
          subtitle:
              'Capture preferred delivery channels and study formats to tailor instructional methods.',
        ),
        const SizedBox(height: 18),
        // Preferred Format
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preferred Learning Delivery Format',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Primary format through which the student learns most effectively',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: formats.contains(form.preferredLearningFormat)
                    ? form.preferredLearningFormat
                    : null,
                decoration: InputDecoration(
                  hintText: 'Select preferred delivery format',
                  hintStyle: AppTypography.bodySmall,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: formats.map((f) {
                  return DropdownMenuItem(value: f, child: Text(f));
                }).toList(),
                onChanged: (val) => provider.setPreferredLearningFormat(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Multi-select Content Types
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ContentTypeChipSelector(
            selectedTypes: form.preferredContentTypes ?? [],
            onChanged: (types) => provider.setPreferredContentTypes(types),
          ),
        ),
        const SizedBox(height: 14),

        // Free vs Paid Resources
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Learning Resource Preference',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Student preference towards free open resources vs paid platforms',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: costOptions.map((opt) {
                  final code = opt['val']!;
                  final label = opt['label']!;
                  final isSelected = form.freeVsPaidPreference == code;

                  return ChoiceChip(
                    label: Text(label),
                    labelStyle: AppTypography.captionBold.copyWith(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      provider.setFreeVsPaidPreference(selected ? code : null);
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STEP 4: Career & Placement ───────────────────────────────────────────
  Widget _buildStep4CareerGoals(
    SliPreProvider provider,
    PreAssessmentForm form,
  ) {
    const careerOptions = [
      'Software Engineering & Full Stack',
      'Artificial Intelligence & Data Science',
      'Cloud Architecture & DevOps',
      'Cybersecurity & Networking',
      'Core Systems & Embedded',
      'Higher Studies (MS / M.Tech / PhD)',
      'Entrepreneurship & Product Management',
    ];

    const placementGoals = [
      'Top Product Companies / FAANG+',
      'High-growth Tech Startups',
      'Core Engineering & R&D Labs',
      'IT Services & Enterprise Consulting',
      'Government / Public Sector Careers',
      'Higher Education Admission',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: 4,
          title: 'Career Aspirations & Skill Goals',
          subtitle:
              'Understand the student\'s professional targets to align course relevance with career outcomes.',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Career Domain Interest',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: careerOptions.contains(form.careerInterest)
                    ? form.careerInterest
                    : null,
                decoration: InputDecoration(
                  hintText: 'Select career domain interest',
                  hintStyle: AppTypography.bodySmall,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: careerOptions.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (val) => provider.setCareerInterest(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Placement / Post-Graduation Goal',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: placementGoals.contains(form.placementGoal)
                    ? form.placementGoal
                    : null,
                decoration: InputDecoration(
                  hintText: 'Select placement target',
                  hintStyle: AppTypography.bodySmall,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: placementGoals.map((g) {
                  return DropdownMenuItem(value: g, child: Text(g));
                }).toList(),
                onChanged: (val) => provider.setPlacementGoal(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Key Skills Desired to Improve',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Specific concepts, practical competencies, or tools (e.g. Memory management, System calls)',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: form.skillsToImprove,
                maxLength: 255,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter specific skill targets...',
                  hintStyle: AppTypography.bodySmall,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (val) => provider.setSkillsToImprove(val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STEP 5: Topic Assessment ─────────────────────────────────────────────
  Widget _buildStep5TopicAssessment(
    SliPreProvider provider,
    PreAssessmentForm form,
  ) {
    final topics = form.topics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: 5,
          title: 'Topic-Level Perception',
          subtitle:
              'Score the student\'s baseline familiarity and expected difficulty for each syllabus topic (1 to 5).',
        ),
        const SizedBox(height: 18),
        if (topics.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'No syllabus topics are configured for this subject yet. You can still submit the subject-level PRE assessment.',
                    style: AppTypography.bodySecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topic = topics[index];
              return TopicAssessmentCard(
                index: index,
                topic: topic,
                onConfidenceChanged: (conf) {
                  provider.setTopicConfidence(topic.topicId, conf);
                },
                onDifficultyChanged: (diff) {
                  provider.setTopicDifficulty(topic.topicId, diff);
                },
              );
            },
          ),
      ],
    );
  }

  // ─── STEP 6: Review & Submit ──────────────────────────────────────────────
  Widget _buildStep6ReviewSubmit(
    SliPreProvider provider,
    PreAssessmentForm form,
  ) {
    final completedTopicsCount = form.topics
        .where((t) => t.confidenceLevel != null && t.difficultyLevel != null)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: 6,
          title: 'Review & Submit Assessment',
          subtitle:
              'Please review all recorded responses before submitting to the academic intelligence registry.',
        ),
        const SizedBox(height: 18),
        if (provider.submissionError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    provider.submissionError!,
                    style: AppTypography.captionBold.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assessment Summary',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Student Name', form.studentName),
              _buildDetailRow('Student ID', form.studentId),
              _buildDetailRow('Subject', form.subjectName),
              _buildDetailRow('Class & Division', '${form.yearDisplay} • Div ${form.division}'),
              const Divider(color: AppColors.divider, height: 24),
              Text(
                'Subject Perception Scores',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Subject Interest', '${form.subjectInterest ?? 'Not rated'} / 5'),
              _buildDetailRow('Self-Assessed Skill', '${form.selfAssessedSkill ?? 'Not rated'} / 5'),
              _buildDetailRow('Learning Confidence', '${form.learningConfidence ?? 'Not rated'} / 5'),
              _buildDetailRow('Expected Difficulty', '${form.expectedDifficulty ?? 'Not rated'} / 5'),
              const Divider(color: AppColors.divider, height: 24),
              Text(
                'Preferences & Career',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Delivery Format',
                form.preferredLearningFormat ?? 'Not specified',
              ),
              _buildDetailRow(
                'Content Formats',
                form.preferredContentTypes != null && form.preferredContentTypes!.isNotEmpty
                    ? form.preferredContentTypes!.join(', ')
                    : 'None selected',
              ),
              _buildDetailRow(
                'Resource Preference',
                form.freeVsPaidPreference ?? 'Not specified',
              ),
              _buildDetailRow(
                'Career Interest',
                form.careerInterest ?? 'Not specified',
              ),
              _buildDetailRow(
                'Placement Goal',
                form.placementGoal ?? 'Not specified',
              ),
              _buildDetailRow(
                'Skills to Improve',
                form.skillsToImprove ?? 'Not specified',
              ),
              const Divider(color: AppColors.divider, height: 24),
              Text(
                'Topic Assessments',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Topics Scored',
                '$completedTopicsCount / ${form.topics.length} topics scored',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Bottom Action Bar ────────────────────────────────────────────────────
  Widget _buildBottomActionBar(
    BuildContext context,
    SliPreProvider provider,
    PreAssessmentForm form,
  ) {
    final isFirstStep = provider.currentStep == 0;
    final isLastStep = provider.currentStep == 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous / Cancel Button
          if (!isFirstStep)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: const BorderSide(color: AppColors.border),
              ),
              onPressed: () => provider.previousStep(),
              icon: const Icon(Icons.arrow_back, size: 16, color: AppColors.textPrimary),
              label: const Text(
                'Back',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            )
          else
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: const BorderSide(color: AppColors.border),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),

          // Next / Submit Button
          if (!isLastStep)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => provider.nextStep(),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Next Step'),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: provider.isSubmitting
                  ? null
                  : () async {
                      final success = await provider.submitAssessment();
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              form.isSubmitted
                                  ? 'PRE Assessment updated successfully for ${form.studentName}'
                                  : 'PRE Assessment recorded successfully for ${form.studentName}',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        Navigator.of(context).pop();
                      }
                    },
              icon: provider.isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check, size: 16),
              label: Text(
                provider.isSubmitting
                    ? 'Submitting...'
                    : (form.isSubmitted ? 'Update Assessment' : 'Submit Assessment'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepHeader({
    required int stepNumber,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Step $stepNumber of 6',
                style: AppTypography.captionBold.copyWith(
                  color: AppColors.primary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: AppTypography.captionBold.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
