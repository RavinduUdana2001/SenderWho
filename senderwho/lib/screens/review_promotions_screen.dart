import 'package:flutter/material.dart';

import '../services/senderwho_repository.dart';
import 'emails_screen.dart';

/// Uses the canonical, paginated Gmail list and mutation flow so promotion
/// review has the same partial-failure, retry, selection, and detail behavior
/// as every other mailbox.
class ReviewPromotionsScreen extends StatelessWidget {
  const ReviewPromotionsScreen({super.key, this.repository});

  static const routeName = '/review-promotions';
  final SenderWhoRepository? repository;

  @override
  Widget build(BuildContext context) {
    return EmailsScreen(
      repository: repository,
      initialArguments: const EmailListArguments(
        mailbox: 'ALL',
        category: 'PROMOTIONS',
        title: 'Review Promotions',
      ),
    );
  }
}
