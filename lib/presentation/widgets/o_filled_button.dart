import 'package:flutter/material.dart';
import '../../core/theme/open_file_colors.dart';

class OFilledButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isHero;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const OFilledButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isHero = false,
    this.isFullWidth = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<OFilledButton> createState() => _OFilledButtonState();
}

class _OFilledButtonState extends State<OFilledButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEnabled = widget.onPressed != null;

    final double height = widget.isHero ? 56.0 : 40.0;
    final Color effectiveBg = !isEnabled
        ? colors.surfaceInput
        : _isPressed
            ? (widget.backgroundColor ?? colors.accentPrimaryDim)
            : (widget.backgroundColor ?? colors.accentPrimary);
    final Color effectiveFg = !isEnabled
        ? colors.textDisabled
        : (widget.foregroundColor ?? colors.accentOnAccent);

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 24, color: effectiveFg),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: effectiveFg,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );

    return AnimatedScale(
      scale: _isPressed && isEnabled ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: SizedBox(
        height: height,
        width: widget.isFullWidth ? double.infinity : null,
        child: Material(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(100),
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: widget.onPressed,
            onHighlightChanged: (highlighted) {
              if (mounted) setState(() => _isPressed = highlighted);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
