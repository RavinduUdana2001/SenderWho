import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A single flat surface for mailbox rows, without separate raised cards.
class MailListSurface extends StatelessWidget {
  const MailListSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.transparent, child: child);
  }
}

/// Simple mailbox pills with a clear active state.
class MailFilterTab extends StatelessWidget {
  const MailFilterTab({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Container(
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : AppColors.trackFor(context),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 13,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : AppColors.textFor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
