import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/primary_button.dart';

class _FaqItem {
  final String question;
  final String answer;

  _FaqItem({required this.question, required this.answer});
}

/// Screen 22 — Help & Support screen.
///
/// Ref image features:
/// - Screen title "Help & Support"
/// - Subtitle search bar or descriptions
/// - Accordion list (FAQ questions with dropdown explanation answers)
/// - "Raise a Ticket" action button at bottom
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final List<_FaqItem> _faqs = [
    _FaqItem(
      question: 'How to edit mapping cells?',
      answer: 'Tap any cell inside the CO-PO Mapping matrix grid. Each tap cycles the mapping strength value: 0 (No mapping) -> 1 (Low) -> 2 (Medium) -> 3 (High) -> 0.',
    ),
    _FaqItem(
      question: 'Where to view generated timetables?',
      answer: 'Go to the Timetable tab from the bottom navigation. regular faculty can look up schedule details. Admins and coordinators can access the Generate console to rebuild sheets.',
    ),
    _FaqItem(
      question: 'Is attendance verification automatic?',
      answer: 'Yes! The face verification scan checks user face alignments in real time, confirming coordinates before logging check-ins on our servers.',
    ),
    _FaqItem(
      question: 'Can I log achievements without documents?',
      answer: 'Documents are optional. You can specify FDP names, organization sources, and certification dates, then click Save directly.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: Responsive.maxContentWidth,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Support Hub', style: AppTypography.h2),
                const SizedBox(height: 6),
                Text(
                  'Search Frequently Asked Questions or log a support ticket.',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: 24),

                // Search field
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search help articles...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) {
                    // Mute for now
                  },
                ),
                const SizedBox(height: 24),

                // FAQ Accordion Card
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                        child: Text(
                          'Frequently Asked Questions',
                          style: AppTypography.captionBold.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      ..._faqs.map((faq) {
                        return Column(
                          children: [
                            ExpansionTile(
                              title: Text(
                                faq.question,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                  child: Text(
                                    faq.answer,
                                    style: AppTypography.bodySecondary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Raise Ticket Button
                PrimaryButton(
                  label: 'Raise a Ticket',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Support ticket raised. Admins will review soon.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
