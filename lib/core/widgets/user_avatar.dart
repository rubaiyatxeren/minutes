import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';

/// A circular avatar that shows a network photo when available, or a
/// deterministic gradient with the person's initial otherwise. Optionally
/// draws a small online/status dot in the bottom-right corner.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final bool isGroup;
  final bool? online; // null = don't show a status dot
  final BoxBorder? border;

  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
    this.isGroup = false,
    this.online,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.gradientFor(name.isNotEmpty ? name : 'U');
    final size = radius * 2;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
        gradient: (photoUrl == null || photoUrl!.isEmpty)
            ? LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: (photoUrl != null && photoUrl!.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                ),
              ),
              errorWidget: (_, __, ___) => _InitialFallback(
                  name: name, isGroup: isGroup, size: size, gradient: gradient),
            )
          : _InitialFallback(
              name: name, isGroup: isGroup, size: size, gradient: gradient),
    );

    if (online == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.32,
            height: size * 0.32,
            decoration: BoxDecoration(
              color: online! ? AppColors.success : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InitialFallback extends StatelessWidget {
  final String name;
  final bool isGroup;
  final double size;
  final List<Color> gradient;

  const _InitialFallback({
    required this.name,
    required this.isGroup,
    required this.size,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isGroup
          ? Icon(Icons.groups_rounded, color: Colors.white, size: size * 0.5)
          : Text(
              name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.4,
              ),
            ),
    );
  }
}
