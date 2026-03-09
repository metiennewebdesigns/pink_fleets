import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';
import '../pf_typography.dart';

/// Shared top header bar used across all Pink Fleets apps.
///
/// Implements [PreferredSizeWidget] so it can be used directly as an [AppBar]
/// replacement, or as a plain [Widget] in a [Column].
///
/// ```dart
/// PFHeaderBar(
///   logo: Image.asset('assets/logo/pink_fleets_logo.png', height: 32),
///   subtitle: 'Admin Dashboard',
///   actions: [
///     IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _signOut),
///   ],
/// )
/// ```
class PFHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? logo;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBack;
  final double height;
  final Color? backgroundColor;

  const PFHeaderBar({
    super.key,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.logo,
    this.actions,
    this.showBackButton = false,
    this.onBack,
    this.height = 64,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? PFColors.surface;

    Widget titleSection;
    if (titleWidget != null) {
      titleSection = titleWidget!;
    } else if (logo != null) {
      titleSection = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logo!,
          if (subtitle != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                subtitle!,
                style: PFTypography.bodySmall.copyWith(color: PFColors.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    } else {
      titleSection = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(title!, style: PFTypography.titleLarge, overflow: TextOverflow.ellipsis),
          if (subtitle != null)
            Text(
              subtitle!,
              style: PFTypography.bodySmall.copyWith(color: PFColors.muted),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          bottom: BorderSide(color: PFColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: PFSpacing.base),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
              color: PFColors.muted,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
              visualDensity: VisualDensity.compact,
            ),
          Expanded(child: titleSection),
          if (actions != null) ...actions!,
          const SizedBox(width: PFSpacing.xs),
        ],
      ),
    );
  }
}
