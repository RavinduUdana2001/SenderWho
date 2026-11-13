import 'package:flutter/material.dart';
import 'connect_email_screen.dart';
import '../widgets/entry_artwork.dart';
import '../widgets/entry_reveal.dart';
import '../widgets/responsive_entry_page.dart';
import '../widgets/senderwho_brand.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.animateEntrance = true});
  final bool animateEntrance;

  @override
  Widget build(BuildContext context) {
    final introduction = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const EntryBrandScene(),
        const SizedBox(height: 22),
        const SenderWhoWordmark(size: 26),
        const SizedBox(height: 14),
        Text(
          'Know your senders.\nLove your inbox.',
          key: const ValueKey('onboarding-hero-title'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            height: 1.17,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Less noise. More of what matters.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
    return ResponsiveEntryPage(
      maxWidth: 400,
      bottomPadding: 28,
      contentAlignment: const Alignment(0, -.12),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EntryPrimaryButton(
            onPressed: () =>
                Navigator.pushNamed(context, ConnectEmailScreen.routeName),
          ),
          const SizedBox(height: 16),
          Text(
            'Private by design.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      child: animateEntrance ? EntryReveal(child: introduction) : introduction,
    );
  }
}
