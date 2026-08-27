import 'package:flutter/material.dart';

/// Central color palette. Keep the app minimalist — one accent color,
/// neutral surfaces, and clear light/dark pairs.
class AppColors {
  AppColors._();

  // Brand accent (indigo/violet — modern, not a Teams-purple clone)
  static const Color primary = Color(0xFF5B5FEF);
  static const Color primaryDark = Color(0xFF7B7FFF);

  static const Color success = Color(0xFF34C759);
  static const Color danger = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFFB020);

  // Light theme
  static const Color lightBackground = Color(0xFFF7F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBubbleMine = Color(0xFF5B5FEF);
  static const Color lightBubbleOther = Color(0xFFEFEFF5);
  static const Color lightTextPrimary = Color(0xFF16171B);
  static const Color lightTextSecondary = Color(0xFF6B6D76);
  static const Color lightBorder = Color(0xFFE7E7EF);

  // Dark theme
  static const Color darkBackground = Color(0xFF0E0F13);
  static const Color darkSurface = Color(0xFF1A1B22);
  static const Color darkBubbleMine = Color(0xFF7B7FFF);
  static const Color darkBubbleOther = Color(0xFF23242E);
  static const Color darkTextPrimary = Color(0xFFF5F5F7);
  static const Color darkTextSecondary = Color(0xFFA0A1AC);
  static const Color darkBorder = Color(0xFF2A2B35);

  // Playful gradient pairs used for avatar placeholders — picked
  // deterministically per-user so the same person always gets the same
  // colors across the app.
  static const List<List<Color>> avatarGradients = [
    [Color(0xFFFF6B6B), Color(0xFFFFA36B)],
    [Color(0xFF6B8CFF), Color(0xFF6BD8FF)],
    [Color(0xFF9B6BFF), Color(0xFFFF6BE0)],
    [Color(0xFF2FD08A), Color(0xFF34E0C7)],
    [Color(0xFFFFC542), Color(0xFFFF8A42)],
    [Color(0xFF42B7FF), Color(0xFF428CFF)],
    [Color(0xFFFF7AC6), Color(0xFFFF9A8B)],
  ];

  static List<Color> gradientFor(String seed) {
    if (seed.isEmpty) return avatarGradients.first;
    final sum = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    return avatarGradients[sum % avatarGradients.length];
  }

  // ---- Premium touches -----------------------------------------------
  // Additive — nothing above this line changes, so nothing that already
  // references AppColors breaks.

  /// Soft ambient shadow used on hero containers / elevated cards where
  /// we want depth without the flat Material `elevation` look.
  static List<BoxShadow> softShadow(Color tint) => [
        BoxShadow(
          color: tint.withOpacity(0.18),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  /// Subtle brand gradient for hero sections / onboarding backgrounds —
  /// deliberately understated (barely-there tint) rather than a loud
  /// poster gradient, so it reads as premium rather than gaudy.
  static LinearGradient heroGradient(Color primary, {required bool isDark}) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [primary.withOpacity(0.16), Colors.transparent]
          : [primary.withOpacity(0.10), Colors.transparent],
    );
  }
}
