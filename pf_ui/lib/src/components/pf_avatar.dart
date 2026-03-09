import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_typography.dart';

/// Circular avatar with optional online-status dot.
class PFAvatar extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final double radius;
  final bool online;
  final bool showStatus;
  final Color? backgroundColor;

  const PFAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.radius = 22,
    this.online = false,
    this.showStatus = false,
    this.backgroundColor,
  });

  String get _initials {
    final n = (name ?? '').trim();
    if (n.isEmpty) return '?';
    final parts = n.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? PFColors.primarySoft;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: !hasImage
          ? Text(
              _initials,
              style: PFTypography.labelMedium.copyWith(
                color: PFColors.primary,
                fontSize: radius * 0.65,
              ),
            )
          : null,
    );

    if (showStatus) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: online ? PFColors.success : PFColors.muted,
                shape: BoxShape.circle,
                border: Border.all(color: PFColors.surface, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }
}
