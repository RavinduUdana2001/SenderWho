import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SenderWhoWordmark extends StatelessWidget {
  const SenderWhoWordmark({
    super.key,
    this.fontSize = 24,
    this.alignment = MainAxisAlignment.start,
  });

  final double fontSize;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: AppColors.textFor(context),
      fontSize: fontSize,
      height: 1,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.9,
    );
    return Semantics(
      label: 'SenderWho',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment == MainAxisAlignment.center
              ? Alignment.center
              : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: alignment,
            children: [
              Text('sender', style: style),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: AppColors.brandSpectrum,
                ).createShader(bounds),
                child: Text('who', style: style.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SenderWhoTagline extends StatelessWidget {
  const SenderWhoTagline({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'KNOW WHO. MANAGE BETTER.',
      maxLines: 1,
      overflow: TextOverflow.fade,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.primary,
        fontSize: 8,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.35,
      ),
    );
  }
}
