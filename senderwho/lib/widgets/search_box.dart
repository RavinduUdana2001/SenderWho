import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SearchBox extends StatelessWidget {
  const SearchBox({
    super.key,
    this.hint = 'Search emails and senders...',
    this.controller,
    this.onSubmitted,
    this.onTap,
    this.trailing,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final field = Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppColors.borderFor(context).withValues(alpha: 0.62),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFor(context),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: controller == null
          ? Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: AppColors.mutedFor(context),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                ?trailing,
                const SizedBox(width: 8),
              ],
            )
          : TextField(
              controller: controller,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: hint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: AppColors.mutedFor(context),
                ),
                suffixIcon: trailing,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
    );
    if (onTap == null) return field;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: IgnorePointer(child: field),
      ),
    );
  }
}
