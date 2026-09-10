import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/achievement_repository.dart';

/// Screen for Faculty Career Advancement.
///
/// Features:
/// - Summary Metrics Header (Total, Certifications, FDPs, Publications)
/// - Primary CTA: "+ Add Achievement"
/// - Search & Category Filter chips
/// - Compact, professional achievement cards with badges, date, organization, and document view
/// - Modal document detail viewer (showing Cloudinary secure storage link & path)
/// - Responsive Add Achievement Form (Dialog on Desktop/Tablet, BottomSheet on Mobile)
/// - File Upload Area with Choose File, format hints, file name display, and remove/change options
class CareerAdvancementScreen extends StatefulWidget {
  const CareerAdvancementScreen({super.key});

  @override
  State<CareerAdvancementScreen> createState() => _CareerAdvancementScreenState();
}

class _CareerAdvancementScreenState extends State<CareerAdvancementScreen> {
  final _repository = AchievementRepository();
  late Future<List<AchievementModel>> _future;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _repository.fetchMyAchievements();
    });
  }

  Future<void> _deleteAchievement(AchievementModel achievement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Achievement', style: AppTypography.h3),
        content: Text(
          'Are you sure you want to remove "${achievement.title}" from your career records? This will permanently delete the record and its uploaded document.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteAchievement(achievement.id);
        _refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Achievement removed successfully.'),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openAddDialog() async {
    final isMobile = Responsive.isMobile(context);

    bool? added;
    if (isMobile) {
      added = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _AddAchievementSheet(),
      );
    } else {
      added = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _AddAchievementDialog(),
        ),
      );
    }

    if (added == true) {
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Achievement saved to your Career records!'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _viewDocumentModal(AchievementModel achievement) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: achievement.categoryOption.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(achievement.categoryOption.icon, color: achievement.categoryOption.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(achievement.categoryOption.label, style: AppTypography.captionBold.copyWith(color: achievement.categoryOption.color)),
                  Text(achievement.title, style: AppTypography.h3.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (achievement.organization != null && achievement.organization!.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.apartment_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Issuing Organization: ${achievement.organization}',
                        style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (achievement.dateAchieved != null) ...[
                Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Date: ${_formatDate(achievement.dateAchieved!)}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (achievement.description != null && achievement.description!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    achievement.description!,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder_zip_outlined, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Document Reference',
                          style: AppTypography.captionBold.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.attach_file, size: 15, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            achievement.fileName ?? 'certificate_document.pdf',
                            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (achievement.fileSize != null)
                          Text(
                            achievement.fileSize!,
                            style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Storage Path: ${achievement.enosisStoragePath}',
                      style: AppTypography.caption.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    if (achievement.hasCloudinaryUrl) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_done_outlined, size: 14, color: AppColors.success),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Cloudinary Secured Document Storage',
                                style: AppTypography.captionBold.copyWith(color: AppColors.success, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          if (achievement.hasCloudinaryUrl)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Document'),
              onPressed: () async {
                final uri = Uri.parse(achievement.filePath!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open document URL.')),
                    );
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Career Advancement',
          style: AppTypography.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Achievements',
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<AchievementModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allAchievements = snapshot.data ?? [];

            // Apply filter & search
            final filteredAchievements = allAchievements.where((item) {
              final matchesFilter = _selectedFilter == 'all' || item.achievementType == _selectedFilter;
              final q = _searchQuery.toLowerCase().trim();
              final matchesSearch = q.isEmpty ||
                  item.title.toLowerCase().contains(q) ||
                  (item.organization?.toLowerCase().contains(q) ?? false) ||
                  (item.description?.toLowerCase().contains(q) ?? false);
              return matchesFilter && matchesSearch;
            }).toList();

            // Compute summary metrics
            final certsCount = allAchievements.where((a) => a.achievementType == 'certification' || a.achievementType == 'course').length;
            final fdpCount = allAchievements.where((a) => a.achievementType == 'fdp' || a.achievementType == 'workshop' || a.achievementType == 'webinar').length;
            final pubCount = allAchievements.where((a) => a.achievementType == 'publication' || a.achievementType == 'research' || a.achievementType == 'conference').length;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 24,
                vertical: isMobile ? 14 : 20,
              ),
              child: ResponsiveCenter(
                maxWidth: Responsive.maxWideContentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Header Section (Title + Subtitle + Primary CTA) ────
                    Container(
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.workspace_premium_outlined,
                                        color: AppColors.secondary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Career Advancement',
                                        style: (isMobile ? AppTypography.h3 : AppTypography.h1).copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Track your professional achievements and growth.',
                                  style: AppTypography.bodySecondary.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: isMobile ? 13 : 14.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _openAddDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              isMobile ? 'Add' : '+ Add Achievement',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 14 : 20,
                                vertical: isMobile ? 10 : 14,
                              ),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ─── Summary Metric Cards ──────────────────────────────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final statItems = [
                          _StatCardData(
                            title: 'Total Logged',
                            count: '${allAchievements.length}',
                            subtitle: 'All milestones',
                            icon: Icons.emoji_events_outlined,
                            accentColor: AppColors.primary,
                          ),
                          _StatCardData(
                            title: 'Certifications',
                            count: '$certsCount',
                            subtitle: 'Courses & certificates',
                            icon: Icons.card_membership_outlined,
                            accentColor: AppColors.secondary,
                          ),
                          _StatCardData(
                            title: 'FDPs & Workshops',
                            count: '$fdpCount',
                            subtitle: 'Development programs',
                            icon: Icons.school_outlined,
                            accentColor: const Color(0xFF6366F1),
                          ),
                          _StatCardData(
                            title: 'Research & Pubs',
                            count: '$pubCount',
                            subtitle: 'Papers & patents',
                            icon: Icons.menu_book_outlined,
                            accentColor: const Color(0xFF16A34A),
                          ),
                        ];

                        if (isMobile) {
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.4,
                            ),
                            itemCount: statItems.length,
                            itemBuilder: (context, index) => _StatCard(data: statItems[index]),
                          );
                        } else if (isTablet) {
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 2.3,
                            ),
                            itemCount: statItems.length,
                            itemBuilder: (context, index) => _StatCard(data: statItems[index]),
                          );
                        } else {
                          return Row(
                            children: statItems
                                .map((item) => Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: _StatCard(data: item),
                                      ),
                                    ))
                                .toList(),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 22),

                    // ─── Search & Category Filter Bar ───────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search field
                          TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Search achievements by title, organization or topic...',
                              hintStyle: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Category filter pills
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterPill(
                                  label: 'All (${allAchievements.length})',
                                  isSelected: _selectedFilter == 'all',
                                  onTap: () => setState(() => _selectedFilter = 'all'),
                                ),
                                ...achievementTypeOptions.map((opt) {
                                  final count = allAchievements.where((a) => a.achievementType == opt.key).length;
                                  return _FilterPill(
                                    label: '${opt.shortLabel}${count > 0 ? ' ($count)' : ''}',
                                    isSelected: _selectedFilter == opt.key,
                                    onTap: () => setState(() => _selectedFilter = opt.key),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─── Achievement List / Empty State ─────────────────────
                    if (filteredAchievements.isEmpty) ...[
                      _EmptyStateView(
                        isFiltered: _searchQuery.isNotEmpty || _selectedFilter != 'all',
                        onAddTap: _openAddDialog,
                        onResetFilter: () {
                          _searchController.clear();
                          setState(() {
                            _selectedFilter = 'all';
                            _searchQuery = '';
                          });
                        },
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredAchievements.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final achievement = filteredAchievements[index];
                          return _AchievementItemCard(
                            achievement: achievement,
                            onViewDocument: () => _viewDocumentModal(achievement),
                            onDelete: () => _deleteAchievement(achievement),
                            formatDate: _formatDate,
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Stat Card Widget ───────────────────────────────────────────────────
class _StatCardData {
  final String title;
  final String count;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _StatCardData({
    required this.title,
    required this.count,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: AppTypography.captionBold.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: data.accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.accentColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.count,
            style: AppTypography.h2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.subtitle,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Filter Pill Widget ─────────────────────────────────────────────────
class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? AppColors.primary : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Compact Achievement Item Card ──────────────────────────────────────
class _AchievementItemCard extends StatelessWidget {
  final AchievementModel achievement;
  final VoidCallback onViewDocument;
  final VoidCallback onDelete;
  final String Function(DateTime) formatDate;

  const _AchievementItemCard({
    required this.achievement,
    required this.onViewDocument,
    required this.onDelete,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final opt = achievement.categoryOption;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: opt.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(opt.icon, color: opt.color, size: 24),
          ),
          const SizedBox(width: 14),

          // Core content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge + Date row
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: opt.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        opt.shortLabel,
                        style: TextStyle(
                          color: opt.color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (achievement.dateAchieved != null)
                      Text(
                        formatDate(achievement.dateAchieved!),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Title
                Text(
                  achievement.title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                  ),
                ),

                // Organization
                if (achievement.organization != null && achievement.organization!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.apartment_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          achievement.organization!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Description (truncated snippet if provided)
                if (achievement.description != null && achievement.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    achievement.description!,
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // Bottom Action: View Document / Details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: onViewDocument,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              achievement.fileName != null ? Icons.attach_file : Icons.info_outline,
                              size: 15,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              achievement.fileName != null ? 'View Document →' : 'View Details →',
                              style: AppTypography.captionBold.copyWith(
                                color: AppColors.secondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textTertiary),
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Clean Empty State View ─────────────────────────────────────────────
class _EmptyStateView extends StatelessWidget {
  final bool isFiltered;
  final VoidCallback onAddTap;
  final VoidCallback onResetFilter;

  const _EmptyStateView({
    required this.isFiltered,
    required this.onAddTap,
    required this.onResetFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFiltered ? 'No matching achievements found' : 'No achievements added yet',
            style: AppTypography.h3.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              isFiltered
                  ? 'Try clearing your search query or selecting a different category filter.'
                  : 'Add your certificates, webinars, FDPs, workshops and other professional accomplishments.',
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          if (isFiltered)
            OutlinedButton(
              onPressed: onResetFilter,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Clear Filters'),
            )
          else
            ElevatedButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('+ Add Achievement', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Add Achievement Dialog (Desktop & Tablet) ──────────────────────────
class _AddAchievementDialog extends StatelessWidget {
  const _AddAchievementDialog();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 560,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const _AddAchievementForm(isDialog: true),
    );
  }
}

// ─── Add Achievement BottomSheet (Mobile) ───────────────────────────────
class _AddAchievementSheet extends StatelessWidget {
  const _AddAchievementSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const _AddAchievementForm(isDialog: false),
    );
  }
}

// ─── Reusable Add Achievement Form ──────────────────────────────────────
class _AddAchievementForm extends StatefulWidget {
  final bool isDialog;
  const _AddAchievementForm({required this.isDialog});

  @override
  State<_AddAchievementForm> createState() => _AddAchievementFormState();
}

class _AddAchievementFormState extends State<_AddAchievementForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _organizationController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'certification';
  DateTime? _dateAchieved = DateTime.now();
  bool _isSaving = false;

  // File Upload State
  String? _selectedFileName;
  String? _selectedFileSize;
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;

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
      initialDate: _dateAchieved ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateAchieved = picked);
    }
  }

  Future<void> _chooseFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 10 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size exceeds the 10MB maximum limit.')),
          );
          return;
        }

        final sizeKb = (file.size / 1024).round();
        final sizeStr = sizeKb > 1024
            ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
            : '$sizeKb KB';

        setState(() {
          _selectedFileName = file.name;
          _selectedFileSize = sizeStr;
          // On Flutter Web, PlatformFile.path is unavailable and throws.
          // Use bytes (loaded via withData: true) for upload instead.
          _selectedFilePath = kIsWeb ? null : file.path;
          _selectedFileBytes = file.bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file picker: $e')),
      );
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFileName = null;
      _selectedFileSize = null;
      _selectedFilePath = null;
      _selectedFileBytes = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await AchievementRepository().createAchievement(
        title: _titleController.text.trim(),
        achievementType: _selectedCategory,
        organization: _organizationController.text.trim().isNotEmpty
            ? _organizationController.text.trim()
            : null,
        dateAchieved: _dateAchieved,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        fileName: _selectedFileName,
        filePath: _selectedFilePath,
        fileBytes: _selectedFileBytes,
        fileSize: _selectedFileSize,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDateDisplay(DateTime? d) {
    if (d == null) return 'Select date';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Title & Close icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.workspace_premium_outlined, color: AppColors.secondary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('Add Achievement', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 20),

            // 1. Achievement Type Dropdown (10 required types)
            Text('Achievement Type *', style: AppTypography.captionBold.copyWith(color: AppColors.primary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              items: achievementTypeOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt.key,
                  child: Row(
                    children: [
                      Icon(opt.icon, size: 18, color: opt.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          opt.label,
                          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),

            const SizedBox(height: 16),

            // 2. Title / Name
            Text('Title / Name *', style: AppTypography.captionBold.copyWith(color: AppColors.primary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleController,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the achievement title' : null,
              decoration: InputDecoration(
                hintText: 'e.g. AWS Certified Solutions Architect, FDP on AI/ML',
                hintStyle: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Organization / Issuing Institution
            Text('Organization / Issuing Institution', style: AppTypography.captionBold.copyWith(color: AppColors.primary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _organizationController,
              decoration: InputDecoration(
                hintText: 'e.g. Amazon Web Services, IIT Bombay, IEEE, Coursera',
                hintStyle: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Date
            Text('Date of Achievement', style: AppTypography.captionBold.copyWith(color: AppColors.primary)),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.secondary),
                        const SizedBox(width: 10),
                        Text(
                          _formatDateDisplay(_dateAchieved),
                          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 5. Description
            Text('Description / Abstract (Optional)', style: AppTypography.captionBold.copyWith(color: AppColors.primary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add notes about topics covered, skills learned, or recognition details...',
                hintStyle: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 6. Professional Certificate / Document Upload UI
            Text('Certificate / Document Upload', style: AppTypography.captionBold.copyWith(color: AppColors.primary)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: _selectedFileName == null
                  ? Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 32,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Upload Certificate / Document',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Supported file types: PDF, PNG, JPG, JPEG (Max 10MB)',
                          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _chooseFile,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('Choose File'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.verified, color: AppColors.success, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFileName!,
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_selectedFileSize != null)
                                    Text(
                                      _selectedFileSize!,
                                      style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: _chooseFile,
                                  child: const Text('Change', style: TextStyle(fontSize: 12)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                                  tooltip: 'Remove File',
                                  onPressed: _removeFile,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Target: ENOSIS Storage/Faculty/{ID}/Career_Advancement/${getCategoryOption(_selectedCategory).storageFolder}/$_selectedFileName',
                            style: AppTypography.caption.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 24),

            // Form Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Achievement', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
