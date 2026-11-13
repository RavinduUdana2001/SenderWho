import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/emails_screen.dart';
import '../services/senderwho_repository.dart';
import '../services/repository_scope.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, this.repository});
  final SenderWhoRepository? repository;

  static const routeName = '/categories';

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);

  late Future<List<CategoryItem>> _categoriesFuture = _repository
      .getCategories();

  Future<void> _reload() async {
    setState(() {
      _categoriesFuture = _repository.getCategories();
    });
    try {
      await _categoriesFuture;
    } on Object {
      // FutureBuilder keeps the retry state visible.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoryItem>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <CategoryItem>[];
        return AppPage(
          onRefresh: _reload,
          header: const AppHeader(
            title: 'Categories',
            subtitle: 'Find messages by category',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: context.gap(18)),
              if (snapshot.connectionState == ConnectionState.waiting)
                const AppAsyncLoading(message: 'Loading categories…')
              else if (snapshot.hasError)
                AppAsyncError(
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: _reload,
                )
              else if (items.isEmpty)
                const AppEmptyState(
                  icon: Icons.category_outlined,
                  title: 'No categories yet',
                  message: 'Categories appear after your first mailbox scan.',
                )
              else
                for (var i = 0; i < items.length; i++) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      items[i].icon,
                      size: 24,
                      color: AppColors.textFor(context),
                    ),
                    title: Text(
                      items[i].title,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          items[i].count,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                    onTap: () => Navigator.pushNamed(
                      context,
                      EmailsScreen.routeName,
                      arguments: EmailListArguments(
                        mailbox: 'ALL',
                        category: items[i].id.toUpperCase(),
                        title: items[i].title,
                      ),
                    ),
                  ),
                  if (i != items.length - 1) const Divider(height: 1),
                ],
            ],
          ),
        );
      },
    );
  }
}
