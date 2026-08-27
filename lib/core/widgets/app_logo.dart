import 'package:flutter/material.dart';

import '../constants/app_strings.dart';

/// Shows the app icon (`assets/icon/app_icon.png`).
/// Falls back to the app icon glyph if the asset isn't found.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const AppLogo({
    super.key,
    this.size = 64,
    this.showWordmark = false,
  });

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      'assets/icon/app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.forum_rounded,
        size: size,
        color: Theme.of(context).primaryColor,
      ),
    );

    if (!showWordmark) return mark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: 14),
        Text(
          AppStrings.appName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
      ],
    );
  }
}