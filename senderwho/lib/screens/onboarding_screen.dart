import 'package:flutter/material.dart';

import '../screens/connect_email_screen.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_button.dart';
import '../widgets/responsive_entry_page.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveEntryPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _BrandMark(),
          SizedBox(height: context.verticalGap(24)),
          const _HeroTitle(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Text(
              'Know who is emailing you, clean inbox clutter, and stay protected from risky senders.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          SizedBox(height: context.verticalGap(26)),
          const _FeatureList(),
          SizedBox(height: context.verticalGap(24)),
          AppButton(
            label: 'Connect my inbox',
            icon: Icons.arrow_forward_rounded,
            onPressed: () =>
                Navigator.pushNamed(context, ConnectEmailScreen.routeName),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: AppColors.mutedFor(context),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Private by design. You remain in control.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final size = context.screenWidth <= 340 ? 148.0 : 168.0;
    return Semantics(
      label: 'SenderWho — Know who. Manage better.',
      image: true,
      child: ClipRRect(
        key: const ValueKey('onboarding-brand-icon'),
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/branding/senderwho_logo_lockup.jpg',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: context.screenWidth <= 340 ? 27 : 30,
      letterSpacing: -0.8,
    );
    return SizedBox(
      width: double.infinity,
      child: RichText(
        key: const ValueKey('onboarding-hero-title'),
        textAlign: TextAlign.center,
        text: TextSpan(
          style: style,
          children: const [
            TextSpan(text: 'See who’s '),
            TextSpan(
              text: 'really',
              style: TextStyle(color: AppColors.primary),
            ),
            TextSpan(text: '\nemailing you.'),
          ],
        ),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    const features = [
      (
        Icons.verified_user_outlined,
        'True sender detection',
        'Know who really sent each message before opening it.',
      ),
      (
        Icons.layers_outlined,
        'Smart categorization',
        'Organize real email metadata into useful groups.',
      ),
      (
        Icons.cleaning_services_outlined,
        'Bulk cleanup',
        'Review clutter and remove it safely in a few taps.',
      ),
      (
        Icons.gpp_good_outlined,
        'Spam protection',
        'Find risky senders and suspicious messages quickly.',
      ),
    ];
    return Column(
      children: [
        for (var index = 0; index < features.length; index++) ...[
          _FeatureRow(
            icon: features[index].$1,
            title: features[index].$2,
            subtitle: features[index].$3,
          ),
          if (index != features.length - 1) const SizedBox(height: 15),
        ],
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.softFill(context, AppColors.primary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: AppColors.primary),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
