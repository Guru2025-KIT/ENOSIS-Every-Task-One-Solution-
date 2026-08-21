import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/achievement_repository.dart';

/// Career Advancement — real backend (POST/GET/DELETE /achievements),
/// not a placeholder. Certificate/document upload isn't wired into this
/// form yet — that needs your Cloudinary credentials configured first
/// (see docs/CONNECTING_FRONTEND_BACKEND.md); the backend already
/// supports attaching a document_id once you add that.
class CareerAdvancementScreen extends StatefulWidget {
  const CareerAdvancementScreen({super.key});

  @override
  State<CareerAdvancementScreen> createState() => _CareerAdvancementScreenState();
}

class _CareerAdvancementScreenState extends State<CareerAdvancementScreen> {
  final _repository = AchievementRepository();
  late Future<List<AchievementModel>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = _repository.fetchMyAchievements());

  Future<void> _deleteAchievement(AchievementModel achievement) async {
    try {
      await _repository.deleteAchievement(achievement.id);
      _refresh();
    } on AchievementException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openAddSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _AddAchievementSheet(),
    );
    if (added == true) _refresh();
  }

  String _categoryLabel(String value) {
    return achievementCategories.firstWhere((c) => c.$1 == value, orElse: () => (value, value)).$2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Achievements')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<AchievementModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final message = snapshot.error is AchievementException
                ? (snapshot.error as AchievementException).message
                : 'Something went wrong.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, style: AppTypography.bodySecondary, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }

          final achievements = snapshot.data ?? [];
          if (achievements.isEmpty) {
            return const EmptyState(
              icon: Icons.workspace_premium_outlined,
              title: 'No achievements yet',
              message: 'Tap + to log an FDP, publication, certification, or award.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final achievement = achievements[index];
                final isFirst = index == 0;
                final isLast = index == achievements.length - 1;

                return Dismissible(
                  key: ValueKey(achievement.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline, color: AppColors.error),
                  ),
                  onDismissed: (_) => _deleteAchievement(achievement),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Timeline node
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              Container(
                                width: 2,
                                height: 16,
                                color: isFirst ? Colors.transparent : AppColors.border,
                              ),
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: isLast ? Colors.transparent : AppColors.border,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Right Card content
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AppCard(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.workspace_premium_outlined, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(achievement.title, style: AppTypography.body),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            _categoryLabel(achievement.category),
                                            if (achievement.organization != null && achievement.organization!.isNotEmpty)
                                              achievement.organization!,
                                            if (achievement.dateAchieved != null)
                                              '${achievement.dateAchieved!.day}/${achievement.dateAchieved!.month}/${achievement.dateAchieved!.year}',
                                          ].join(' · '),
                                          style: AppTypography.bodySecondary,
                                        ),
                                        if (achievement.documentUrl != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.attach_file, size: 14, color: AppColors.textSecondary),
                                              const SizedBox(width: 4),
                                              Text('Certificate attached', style: AppTypography.caption),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AddAchievementSheet extends StatefulWidget {
  const _AddAchievementSheet();

  @override
  State<_AddAchievementSheet> createState() => _AddAchievementSheetState();
}

class _AddAchievementSheetState extends State<_AddAchievementSheet> {
  final _titleController = TextEditingController();
  final _organizationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _repository = AchievementRepository();
  String _category = 'other';
  DateTime? _dateAchieved;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _organizationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateAchieved = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _repository.createAchievement(
        title: title,
        category: _category,
        dateAchieved: _dateAchieved,
        organization: _organizationController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AchievementException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Log an Achievement', style: AppTypography.h3),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Title, e.g. Completed FDP on Machine Learning'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: achievementCategories
                  .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? 'other'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _organizationController,
              decoration: const InputDecoration(hintText: 'Organization (optional)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                _dateAchieved == null
                    ? 'Date (optional)'
                    : '${_dateAchieved!.day}/${_dateAchieved!.month}/${_dateAchieved!.year}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Description (optional)'),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Save Achievement', isLoading: _isSaving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
