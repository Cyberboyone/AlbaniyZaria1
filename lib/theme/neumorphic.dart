import 'package:flutter/material.dart';

/// Soft-UI (neumorphic) design tokens.
///
/// Everything is carved out of one background color using a light shadow
/// (top-left) and a dark shadow (bottom-right). "Raised" elements pop out;
/// "pressed" elements look carved in (used for the progress track).
class AppColors {
  static const background = Color(0xFFE9EAEA);
  static const accent = Color(0xFF2E5A46); // deep sage green
  static const textPrimary = Color(0xFF2E5A46);
  static const textSecondary = Color(0xFF5B6B63);

  static const shadowLight = Color(0xFFFFFFFF);
  static const shadowDark = Color(0xFFB6BEC2);
}

enum NeuStyle { raised, pressed, flat }

/// A container carved out of [AppColors.background] using dual soft shadows.
class Neumorphic extends StatelessWidget {
  final Widget? child;
  final double borderRadius;
  final NeuStyle style;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double? width;
  final double? height;
  final double intensity; // shadow blur/offset multiplier

  const Neumorphic({
    super.key,
    this.child,
    this.borderRadius = 24,
    this.style = NeuStyle.raised,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.width,
    this.height,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    if (style == NeuStyle.pressed) {
      return Container(
        width: width,
        height: height,
        padding: padding,
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.shadowDark.withValues(alpha: 0.55),
              AppColors.background,
              AppColors.shadowLight.withValues(alpha: 0.7),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: child,
      );
    }

    if (style == NeuStyle.flat) {
      return Container(
        width: width,
        height: height,
        padding: padding,
        margin: margin,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: radius,
        ),
        child: child,
      );
    }

    // Raised (default)
    return Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark.withValues(alpha: 0.55),
            offset: Offset(6 * intensity, 6 * intensity),
            blurRadius: 14 * intensity,
          ),
          BoxShadow(
            color: AppColors.shadowLight,
            offset: Offset(-6 * intensity, -6 * intensity),
            blurRadius: 14 * intensity,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A circular neumorphic button — used for the top icon buttons and the
/// transport controls (prev / play-pause / next).
class NeumorphicCircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;
  final NeuStyle style;
  final Color? iconColor;

  const NeumorphicCircleButton({
    super.key,
    required this.icon,
    this.size = 56,
    this.iconSize = 24,
    this.onTap,
    this.style = NeuStyle.raised,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Neumorphic(
        width: size,
        height: size,
        borderRadius: size / 2,
        style: style,
        child: Icon(icon, size: iconSize, color: iconColor ?? AppColors.accent),
      ),
    );
  }
}