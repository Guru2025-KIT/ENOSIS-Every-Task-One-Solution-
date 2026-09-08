import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/faculty_teaching_context.dart';
import '../../data/models/sli_assessment.dart';
import '../../data/services/sli_service.dart';
import 'student_assessment_portal_screen.dart';

/// Screen allowing faculty to create, configure, preview, publish, copy links,
/// share assessments, and monitor live student submissions.
class AssessmentManagementScreen extends StatefulWidget {
  final FacultyTeachingContext teachingContext;

  const AssessmentManagementScreen({
    super.key,
    required this.teachingContext,
  });

  @override
  State<AssessmentManagementScreen> createState() => _AssessmentManagementScreenState();
}

class _AssessmentManagementScreenState extends State<AssessmentManagementScreen> {
  final SliService _sliService = SliService();
  bool _isLoading = true;
  String? _errorMessage;
  List<SliAssessment> _assessments = [];

  @override
  void initState() {
    super.initState();
    _loadAssessments();
  }

  Future<void> _loadAssessments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _sliService.listAssessmentsForContext(
        classId: widget.teachingContext.classId ?? 0,
        subjectId: widget.teachingContext.subjectId,
        semesterId: widget.teachingContext.semesterId ?? 0,
      );
      if (!mounted) return;
      setState(() {
        _assessments = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createAssessment(String type, {int questionCount = 20}) async {
    try {
      await _sliService.createAssessment(
        classId: widget.teachingContext.classId ?? 0,
        subjectId: widget.teachingContext.subjectId,
        semesterId: widget.teachingContext.semesterId ?? 0,
        assessmentType: type,
        questionCount: questionCount,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$type Assessment created in DRAFT ($questionCount dynamic questions).'),
          backgroundColor: AppColors.success,
        ),
      );

      _loadAssessments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create assessment: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _updateStatus(SliAssessment assessment, String newStatus) async {
    if (newStatus == 'PUBLISHED' && (assessment.questions.length < 15 || assessment.questions.length > 20)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot publish: Assessment must contain between 15 and 20 questions (currently ${assessment.questions.length}).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    try {
      await _sliService.updateAssessmentStatus(
        assessmentId: assessment.assessmentId,
        status: newStatus,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${assessment.assessmentType} Assessment is now $newStatus.'),
          backgroundColor: AppColors.success,
        ),
      );

      _loadAssessments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _copyAssessmentLink(SliAssessment assessment) {
    final link = ApiClient.getAssessmentShareUrl(assessment.accessToken);
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Assessment link copied:\n$link', style: const TextStyle(fontSize: 12))),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _shareAssessment(SliAssessment assessment) {
    final subjectName = assessment.subjectName ?? widget.teachingContext.subjectName;
    final link = ApiClient.getAssessmentShareUrl(assessment.accessToken);
    final shareMessage = '$subjectName — ${assessment.assessmentType} Assessment\n\nComplete your assessment using this link:\n$link';

    Clipboard.setData(ClipboardData(text: shareMessage));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.share_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Share ${assessment.assessmentType} Assessment', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share text & link copied to clipboard! You can paste it directly to WhatsApp, Teams, Google Classroom, or Email:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                shareMessage,
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Again'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: shareMessage));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Assessment share message copied!'), backgroundColor: AppColors.success),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showQuestionPreview(SliAssessment assessment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${assessment.assessmentType} Assessment Blueprint',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Text(
                    'Subject: ${assessment.subjectName ?? widget.teachingContext.subjectName} (${assessment.questionCount} questions)',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: assessment.questions.length,
                      itemBuilder: (context, index) {
                        final q = assessment.questions[index] as Map<String, dynamic>;
                        final type = q['type'] ?? 'QUESTION';
                        final title = q['title'] ?? q['section'] ?? 'Question ${index + 1}';
                        final text = q['description'] ?? q['question_text'] ?? q['prompt'] ?? '';
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Q${index + 1} • $type',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                    if (q['section'] != null) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          q['section'],
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                if (text.isNotEmpty && text != title) ...[
                                  const SizedBox(height: 4),
                                  Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                                if (q['topics'] is List && (q['topics'] as List).isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: (q['topics'] as List).map((t) {
                                      return Chip(
                                        label: Text(t['topic_name'] ?? '', style: const TextStyle(fontSize: 11)),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showQuestionBuilderDialog(SliAssessment assessment) {
    final List<Map<String, dynamic>> editableQuestions = List<Map<String, dynamic>>.from(
      assessment.questions.map((q) => Map<String, dynamic>.from(q as Map)),
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isAtMax = editableQuestions.length >= 20;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Configure ${assessment.assessmentType} Questions (${editableQuestions.length} / 20 max, min 15)',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: 480,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Custom Question', style: TextStyle(fontSize: 12)),
                          onPressed: isAtMax
                              ? null
                              : () {
                                  _showAddCustomQuestionDialog(context, assessment, (newQ) {
                                    setDialogState(() {
                                      if (editableQuestions.length < 20) {
                                        editableQuestions.add(newQ);
                                      }
                                    });
                                  });
                                },
                        ),
                        if (isAtMax)
                          const Text(
                            'Maximum 20 questions reached',
                            style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: editableQuestions.length,
                        itemBuilder: (context, index) {
                          final q = editableQuestions[index];
                          final title = q['title'] ?? 'Question ${index + 1}';
                          final desc = q['description'] ?? q['question_text'] ?? '';
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: ListTile(
                              dense: true,
                              title: Text('Q${index + 1}: $title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: desc.isNotEmpty ? Text(desc, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis) : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                                tooltip: 'Remove Question',
                                onPressed: () {
                                  setDialogState(() {
                                    editableQuestions.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (editableQuestions.length < 15 || editableQuestions.length > 20) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Assessment must have between 15 and 20 questions (currently ${editableQuestions.length}).'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    try {
                      await _sliService.updateAssessmentQuestions(
                        assessmentId: assessment.assessmentId,
                        questions: editableQuestions,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Questions configuration saved.'), backgroundColor: AppColors.success),
                      );
                      _loadAssessments();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save questions: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddCustomQuestionDialog(
    BuildContext parentContext,
    SliAssessment assessment,
    Function(Map<String, dynamic>) onAdd,
  ) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final sectionCtrl = TextEditingController(text: 'Custom Competency Section');

    showDialog(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Question', style: TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Question Title / Concept *', isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Question Prompt / Description *', isDense: true),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: sectionCtrl,
              decoration: const InputDecoration(labelText: 'Section Category / Skill', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) return;
              final cleanSection = sectionCtrl.text.trim();
              final skillTag = cleanSection.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_]'), '_');
              onAdd({
                'question_id': 'CUSTOM_${DateTime.now().millisecondsSinceEpoch}',
                'subject_id': widget.teachingContext.subjectId,
                'topic_id': null,
                'skill_id': skillTag.isNotEmpty ? skillTag : 'CUSTOM_SKILL',
                'difficulty': 3,
                'marks': 1,
                'assessment_stage': assessment.assessmentType,
                'section': cleanSection,
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'type': 'LIKERT_1_5',
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.teachingContext;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assessment Management',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            Text(
              '${ctx.subjectName} (${ctx.yearDisplay} • Div ${ctx.divisionCode})',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadAssessments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator(size: 40))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadAssessments, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${ctx.subjectName} (${ctx.subjectCode ?? 'Course'})',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          '${ctx.yearDisplay} • Division ${ctx.divisionCode} • ${ctx.academicYear ?? '2025-26'}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Create Dynamic Assessment Stage:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _buildCreateButton('PRE', Colors.indigo, 'Baseline / Readiness')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildCreateButton('MID', Colors.teal, 'Progress / Barriers')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildCreateButton('END', Colors.deepOrange, 'Mastery / Outcomes')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Assessments Overview',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),

                      if (_assessments.isEmpty)
                        const EmptyState(
                          title: 'No Assessments Created Yet',
                          message: 'Create a PRE, MID, or END assessment above to generate dynamic subject questions.',
                          icon: Icons.assignment_outlined,
                        )
                      else
                        ..._assessments.map(_buildAssessmentCard),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCreateButton(String type, Color color, String subtitle) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      ),
      onPressed: () => _createAssessment(type),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline, size: 14),
              const SizedBox(width: 4),
              Text('Create $type', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildAssessmentCard(SliAssessment a) {
    Color statusColor = Colors.grey;
    if (a.isPublished) statusColor = AppColors.success;
    if (a.isDraft) statusColor = Colors.amber.shade800;
    if (a.isClosed) statusColor = AppColors.error;

    final shareUrl = ApiClient.getAssessmentShareUrl(a.accessToken);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${a.assessmentType} ASSESSMENT',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        a.status,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${a.questionCount} Questions',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Shareable Link & Token Card (for Published assessments)
            if (a.isPublished)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Direct Shareable Assessment Link:', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SelectableText(
                      shareUrl,
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),

            if (a.isPublished) const SizedBox(height: 12),

            // Submissions Statistics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Student Responses: ${a.submissionCount} ${a.totalStudents > 0 ? '/ ${a.totalStudents}' : 'submitted'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (a.totalStudents > 0)
                  Text(
                    '${((a.submissionCount / a.totalStudents) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: a.totalStudents > 0 ? (a.submissionCount / a.totalStudents).clamp(0.0, 1.0) : 0,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),

            // Primary Faculty Actions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // DRAFT State Actions
                if (a.isDraft) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Configure Questions', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showQuestionBuilderDialog(a),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Preview', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showQuestionPreview(a),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.publish_rounded, size: 16, color: Colors.white),
                    label: const Text('Publish', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _updateStatus(a, 'PUBLISHED'),
                  ),
                ],

                // PUBLISHED State Actions
                if (a.isPublished) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                    label: const Text('Copy Link', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _copyAssessmentLink(a),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                    label: const Text('Share', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _shareAssessment(a),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Preview', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showQuestionPreview(a),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.error),
                    label: const Text('Close', style: TextStyle(fontSize: 12, color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _updateStatus(a, 'CLOSED'),
                  ),
                  // Secondary dev test helper
                  IconButton(
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18, color: AppColors.textSecondary),
                    tooltip: 'Test Student View',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentAssessmentPortalScreen(initialToken: a.accessToken),
                        ),
                      );
                    },
                  ),
                ],

                // CLOSED State Actions
                if (a.isClosed) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Preview', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showQuestionPreview(a),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text('Re-open Assessment', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _updateStatus(a, 'PUBLISHED'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
