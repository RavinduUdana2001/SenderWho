import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/emails_screen.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  static const routeName = '/categories';

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<CategoryItem>> _categoriesFuture = senderWhoRepository
      .getCategories();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoryItem>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <CategoryItem>[];
        return AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeader(
                title: 'Categories',
                subtitle: 'Browse real Gmail messages by sender type',
              ),
              SizedBox(height: context.gap(18)),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                AppAsyncError(
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: () => setState(() {
                    _categoriesFuture = senderWhoRepository.getCategories();
                  }),
                )
              else
                for (var i = 0; i < items.length; i++) ...[
                  AppCard(
                    padding: EdgeInsets.zero,
                    onTap: () => Navigator.pushNamed(
                      context,
                      EmailsScreen.routeName,
                      arguments: EmailListArguments(
                        mailbox: 'ALL',
                        category: items[i].id.toUpperCase(),
                        title: items[i].title,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          IconBubble(
                            icon: items[i].icon,
                            size: 42,
                            iconSize: 20,
                            color: items[i].color,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              items[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.trackFor(context),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              items[i].count,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.mutedFor(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i != items.length - 1) const SizedBox(height: 9),
                ],
            ],
          ),
        );
      },
    );
  }
}
