import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/firebase_providers.dart';
import '../theme/driver_theme.dart';

const String _kBuildStamp = 'PF UI BUILD: 2026-03-03-LIGHT';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _passVisible = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(firebaseAuthProvider).signInWithEmailAndPassword(
            email: _email.text.trim(),
            password: _pass.text,
          );
      if (mounted) context.go('/driver');
    } catch (e) {
      if (mounted) setState(() => _error = 'Incorrect username and/or password');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PFLightColors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  PFLightColors.primary.withValues(alpha: 0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  PFLightColors.gold.withValues(alpha: 0.06),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 56,
                          child: Image.asset(
                            'assets/logo/pink_fleets_logo.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'DRIVER PORTAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: PFLightColors.muted,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 36),
                        _LightCard(
                          email: _email,
                          pass: _pass,
                          loading: _loading,
                          error: _error,
                          passVisible: _passVisible,
                          subtitle: 'Sign in to access your dashboard.',
                          emailHint: 'driver@pinkfleets.co.za',
                          onTogglePass: () =>
                              setState(() => _passVisible = !_passVisible),
                          onSignIn: _signIn,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Pink Fleets · Driver Operations',
                          style: TextStyle(
                            fontSize: 11,
                            color: PFLightColors.muted.withValues(alpha: 0.65),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _LightCard extends StatelessWidget {
  final TextEditingController email;
  final TextEditingController pass;
  final bool loading;
  final String? error;
  final bool passVisible;
  final String subtitle;
  final String emailHint;
  final VoidCallback onTogglePass;
  final VoidCallback onSignIn;

  const _LightCard({
    required this.email,
    required this.pass,
    required this.loading,
    required this.error,
    required this.passVisible,
    required this.subtitle,
    required this.emailHint,
    required this.onTogglePass,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: PFLightColors.surface,
        borderRadius: BorderRadius.circular(PFSpacing.radiusCard),
        border: Border.all(color: PFLightColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: PFLightColors.primary.withValues(alpha: 0.04),
            blurRadius: 80,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: PFLightColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: PFLightColors.muted),
            ),
            const SizedBox(height: 28),
            _LightField(
              controller: email,
              label: 'Email',
              hint: emailHint,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            const SizedBox(height: 14),
            _LightField(
              controller: pass,
              label: 'Password',
              obscureText: !passVisible,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              enableSuggestions: false,
              autocorrect: false,
              onSubmitted: (_) => loading ? null : onSignIn(),
              suffixIcon: IconButton(
                onPressed: onTogglePass,
                icon: Icon(
                  passVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: PFLightColors.muted,
                ),
              ),
            ),
            if (error != null) ...[  
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: PFLightColors.dangerSoft,
                  borderRadius: BorderRadius.circular(PFSpacing.radius),
                  border: Border.all(
                      color: PFLightColors.danger.withValues(alpha: 0.3)),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: PFLightColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            _SignInButton(loading: loading, onTap: onSignIn),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                _kBuildStamp,
                style: TextStyle(
                  fontSize: 10,
                  color: PFLightColors.muted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final bool obscureText;
  final bool enableSuggestions;
  final bool autocorrect;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const _LightField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      enableSuggestions: enableSuggestions,
      autocorrect: autocorrect,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: PFLightColors.ink, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: PFLightColors.muted, fontSize: 13),
        hintStyle: TextStyle(
            color: PFLightColors.muted.withValues(alpha: 0.6), fontSize: 14),
        filled: true,
        fillColor: PFLightColors.surface,
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
          borderSide: const BorderSide(color: PFLightColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
          borderSide: const BorderSide(color: PFLightColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
          borderSide: const BorderSide(color: PFLightColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
          borderSide: const BorderSide(color: PFLightColors.danger, width: 1.5),
        ),
      ),
    );
  }
}

class _SignInButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SignInButton({required this.loading, required this.onTap});

  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          if (!widget.loading) widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : (_hovered ? 1.015 : 1.0),
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: PFLightColors.pinkGradient,
              borderRadius: BorderRadius.circular(PFSpacing.radius),
              boxShadow: widget.loading
                  ? []
                  : [
                      BoxShadow(
                        color: PFLightColors.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
