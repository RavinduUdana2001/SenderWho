import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.textFor(context),
        letterSpacing: 0,
      ),
    );
    final action = actionLabel == null
        ? null
        : TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(actionLabel!),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 400 &&
            MediaQuery.textScalerOf(context).scale(14) > 18;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (action != null)
                Align(alignment: Alignment.centerRight, child: action),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            if (action != null) Flexible(child: action),
          ],
        );
      },
    );
  }
}
