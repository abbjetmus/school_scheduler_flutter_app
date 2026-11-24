import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sidrubrik som i webben (PageHeader.vue): titel, undertext, knappar till höger.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: pageTitleStyle(context)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: const TextStyle(fontSize: 15, color: AppColors.ink2)),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

/// Tom lista — samma utseende överallt.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.text, this.action});

  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.lineStrong),
            const SizedBox(height: 16),
            Text(title, style: sectionTitleStyle(context), textAlign: TextAlign.center),
            if (text != null) ...[
              const SizedBox(height: 6),
              Text(text!, style: const TextStyle(color: AppColors.ink2), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Liten färgad etikett — "Finns", "Utlånad", "Försenad".
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color = AppColors.ink2, this.background = AppColors.surfaceLight});

  final String label;
  final Color color;
  final Color background;

  factory StatusPill.success(String label) =>
      StatusPill(label, color: AppColors.success, background: AppColors.successLight);
  factory StatusPill.primary(String label) =>
      StatusPill(label, color: AppColors.onPrimaryLight, background: AppColors.primaryLight);
  factory StatusPill.warning(String label) =>
      StatusPill(label, color: AppColors.onSunLight, background: AppColors.sunLight);
  factory StatusPill.error(String label) =>
      StatusPill(label, color: AppColors.error, background: AppColors.errorLight);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
  }
}

/// Kort med rubrik — som `<v-card variant="flat" border>` med v-card-title.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.icon, this.trailing, required this.child, this.padding = const EdgeInsets.all(20)});

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 4),
              child: Row(
                children: [
                  if (icon != null) ...[Icon(icon, color: AppColors.primary, size: 22), const SizedBox(width: 10)],
                  Expanded(child: Text(title!, style: sectionTitleStyle(context))),
                  ?trailing,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.ink,
    ));
}
