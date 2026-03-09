import 'package:flutter/material.dart';
import '../pf_colors.dart';
import '../pf_spacing.dart';
import '../pf_typography.dart';

/// Standardised Pink Fleets text field.
///
/// Wraps [TextFormField] with the PF dark-surface token set so every form in
/// every app looks identical out of the box.
///
/// ```dart
/// PFTextField(
///   label: 'Email',
///   hint: 'you@pinkfleets.co.za',
///   controller: _emailCtrl,
///   prefixIcon: Icons.email_outlined,
/// )
/// ```
class PFTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final IconData? prefixIcon;
  final Widget? suffix;
  final Widget? suffixIcon;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final String? initialValue;
  final bool readOnly;

  const PFTextField({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onTap,
    this.prefixIcon,
    this.suffix,
    this.suffixIcon,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.initialValue,
    this.readOnly = false,
  });

  @override
  State<PFTextField> createState() => _PFTextFieldState();
}

class _PFTextFieldState extends State<PFTextField> {
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      focusNode: widget.focusNode,
      obscureText: _obscure,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      autofocus: widget.autofocus,
      textCapitalization: widget.textCapitalization,
      style: PFTypography.bodyLarge.copyWith(color: PFColors.ink),
      cursorColor: PFColors.primary,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        errorText: widget.errorText,
        filled: true,
        fillColor: PFColors.surfaceHigh,
        labelStyle: PFTypography.bodyMedium.copyWith(color: PFColors.muted),
        hintStyle: PFTypography.bodyMedium.copyWith(color: PFColors.muted),
        helperStyle: PFTypography.bodySmall,
        errorStyle: PFTypography.bodySmall.copyWith(color: PFColors.danger),
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 20, color: PFColors.muted)
            : null,
        suffix: widget.suffix,
        suffixIcon: widget.obscureText
            ? GestureDetector(
                onTap: () => setState(() => _obscure = !_obscure),
                child: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: PFColors.muted,
                ),
              )
            : widget.suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PFSpacing.base,
          vertical: PFSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
          borderSide: const BorderSide(color: PFColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
          borderSide: const BorderSide(color: PFColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
          borderSide: const BorderSide(color: PFColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
          borderSide: const BorderSide(color: PFColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
          borderSide: const BorderSide(color: PFColors.danger, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
          borderSide: BorderSide(
            color: PFColors.border.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
