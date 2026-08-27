import 'package:flutter/material.dart';
import '../constants/app_strings.dart';

/// Shows the app icon (`assets/icons/app_icon.png`) in a soft rounded
/// container. Falls back to a gradient glyph if the asset isn't found —
/// so the app never crashes or shows Flutter's red-X placeholder even
/// if the asset path isn't declared in pubspec.yaml yet.
///
/// IMPORTANT: for `assets/icons/app_icon.png` to actually load, add this
/// to pubspec.yaml under `flutter:`:
///   assets:
///     - assets/icons/app_icon.png
class AppLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final bool rounded;

  const AppLogo({
    super.key,
    this.size = 64,
    this.showWordmark = false,
    this.rounded = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rounded ? size * 0.28 : 0),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primary.withOpacity(0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/icons/app_icon.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.forum_rounded,
          size: size * 0.52,
          color: Colors.white,
        ),
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
