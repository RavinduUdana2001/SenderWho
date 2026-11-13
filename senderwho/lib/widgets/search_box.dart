import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SearchBox extends StatelessWidget {
  const SearchBox({
    super.key,
    this.hint = 'Search emails and senders...',
    this.controller,
    this.onSubmitted,
    this.onChanged,
    this.onTap,
    this.trailing,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final field = Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        color: AppColors.trackFor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.borderFor(context).withValues(alpha: 0.86),
        ),
      ),
      child: controller == null
          ? Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: AppColors.primaryFor(context),
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
              onSubmitted: (value) {
                FocusScope.of(context).unfocus();
                onSubmitted?.call(value);
              },
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              keyboardAppearance: Theme.of(context).brightness,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              scrollPadding: const EdgeInsets.all(24),
              onChanged: onChanged,
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
                  color: AppColors.primaryFor(context),
                ),
                suffixIcon: trailing,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
              ),
            ),
    );
    if (onTap == null) return field;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: IgnorePointer(child: field),
      ),
    );
  }
}
