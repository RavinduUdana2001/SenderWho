import 'package:flutter/material.dart';

/// One logo and wordmark for launch, welcome, and sign-in.
class SenderWhoLogo extends StatelessWidget {
  const SenderWhoLogo({super.key, this.size = 80});
  final double size;
  // One cache key avoids another image decode when the logo changes size.
  static const image = ResizeImage(
    AssetImage('assets/branding/senderwho_app_icon_master.png'),
    width: 384,
  );

  @override
  Widget build(BuildContext context) => Hero(
    tag: 'senderwho-logo',
    child: Semantics(
      label: 'SenderWho logo',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: Image(
          image: image,
          width: size,
          height: size,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    ),
  );
}

class SenderWhoWordmark extends StatelessWidget {
  const SenderWhoWordmark({super.key, this.size = 32, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    'SenderWho',
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.1,
    ),
  );
}
