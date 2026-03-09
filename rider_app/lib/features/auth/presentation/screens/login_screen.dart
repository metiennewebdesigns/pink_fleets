import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../theme/pink_fleets_theme.dart';

const String _kBuildStamp = 'PF UI BUILD: 2026-03-03-LIGHT';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const String _googleWebClientId =
      '93607564611-7u32e6fsg0jj11brh19tmuv2ru98chu.apps.googleusercontent.com';

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  bool _isLogin = true;
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
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final email = _email.text.trim();
      final pass = _password.text;
      final displayName = _name.text.trim();
      final phone = _phone.text.trim();

      if (email.isEmpty || pass.isEmpty) {
        throw Exception('Please enter email and password.');
      }

      if (_isLogin) {
        if (auth.currentUser?.isAnonymous == true) await auth.signOut();
        await auth.signInWithEmailAndPassword(email: email, password: pass);
      } else {
        if (displayName.isEmpty) throw Exception('Please enter your name.');
        final cred = EmailAuthProvider.credential(email: email, password: pass);
        UserCredential userCred;
        if (auth.currentUser?.isAnonymous == true) {
          userCred = await auth.currentUser!.linkWithCredential(cred);
        } else {
          userCred =
              await auth.createUserWithEmailAndPassword(email: email, password: pass);
        }
        if (displayName.isNotEmpty) {
          await userCred.user?.updateDisplayName(displayName);
        }
        await FirebaseFirestore.instance
            .collection('riders')
            .doc(userCred.user!.uid)
            .set({
          'name': displayName,
          'email': email,
          'phone': phone,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      context.go('/booking');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Incorrect username and/or password');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser?.isAnonymous == true) await auth.signOut();

      UserCredential userCred;
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        userCred = await auth.signInWithPopup(provider);
      } else {
        final googleUser = await GoogleSignIn(
          clientId: _googleWebClientId == 'YOUR_WEB_CLIENT_ID'
              ? null
              : _googleWebClientId,
        ).signIn();
        if (googleUser == null) {
          setState(() => _loading = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCred = await auth.signInWithCredential(credential);
      }

      final user = userCred.user;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('riders')
            .doc(user.uid)
            .set({
          'name': user.displayName ?? '',
          'email': (user.email ?? '').toLowerCase(),
          'phone': user.phoneNumber ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      context.go('/booking');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Incorrect username and/or password');
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
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  PFLightColors.primary.withValues(alpha: 0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -80,
            child: Container(
              width: 340,
              height: 340,
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
                    constraints: const BoxConstraints(maxWidth: 480),
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
                            errorBuilder: (_, __, ___) => const Text(
                              'PINK FLEETS',
                              style: TextStyle(
                                color: PFLightColors.ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'LUXURY CHAUFFEUR BOOKING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: PFLightColors.muted,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _ModeToggle(
                          isLogin: _isLogin,
                          onChanged: (v) => setState(() => _isLogin = v),
                        ),
                        const SizedBox(height: 20),
                        _FormCard(
                          isLogin: _isLogin,
                          email: _email,
                          password: _password,
                          name: _name,
                          phone: _phone,
                          loading: _loading,
                          error: _error,
                          passVisible: _passVisible,
                          onTogglePass: () =>
                              setState(() => _passVisible = !_passVisible),
                          onSubmit: _submit,
                          onGoogleSignIn: _signInWithGoogle,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'By continuing you agree to our Terms & Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: PFLightColors.muted.withValues(alpha: 0.7),
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

class _ModeToggle extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({required this.isLogin, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PFLightColors.surfaceHigh,
        borderRadius: BorderRadius.circular(PFSpacing.radiusMd),
        border: Border.all(color: PFLightColors.border),
      ),
      child: Row(
        children: [
          _tab('Sign in', isLogin, () => onChanged(true)),
          _tab('Create account', !isLogin, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _tab(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? PFLightColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(PFSpacing.radius),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : PFLightColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final bool isLogin;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController name;
  final TextEditingController phone;
  final bool loading;
  final String? error;
  final bool passVisible;
  final VoidCallback onTogglePass;
  final VoidCallback onSubmit;
  final VoidCallback onGoogleSignIn;

  const _FormCard({
    required this.isLogin,
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
    required this.loading,
    required this.error,
    required this.passVisible,
    required this.onTogglePass,
    required this.onSubmit,
    required this.onGoogleSignIn,
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
            Text(
              isLogin ? 'Welcome back' : 'Create your account',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: PFLightColors.ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isLogin
                  ? 'Sign in to continue your booking.'
                  : 'Luxury chauffeured booking starts here.',
              style: const TextStyle(fontSize: 13, color: PFLightColors.muted),
            ),
            const SizedBox(height: 28),
            if (!isLogin) ...[
              _LightField(
                controller: name,
                label: 'Full name',
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 14),
              _LightField(
                controller: phone,
                label: 'Phone (optional)',
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 14),
            ],
            _LightField(
              controller: email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            const SizedBox(height: 14),
            _LightField(
              controller: password,
              label: 'Password',
              obscureText: !passVisible,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              enableSuggestions: false,
              autocorrect: false,
              onSubmitted: (_) => loading ? null : onSubmit(),
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
            _ActionButton(
              label: loading
                  ? 'Please wait\u2026'
                  : (isLogin ? 'Sign in' : 'Create account'),
              loading: loading,
              onTap: onSubmit,
            ),
            const SizedBox(height: 12),
            _GoogleButton(loading: loading, onTap: onGoogleSignIn),
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
  // final String? hint; // Removed: unused field
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
    // this.hint, // Removed: unused parameter
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
        // hintText: hint, // Removed: undefined variable
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

class _ActionButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.label, required this.loading, required this.onTap});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
                  : Text(
                      widget.label,
                      style: const TextStyle(
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

class _GoogleButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleButton({required this.loading, required this.onTap});

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          decoration: BoxDecoration(
            color: _hovered ? PFLightColors.surfaceHigh : PFLightColors.surface,
            borderRadius: BorderRadius.circular(PFSpacing.radius),
            border: Border.all(color: PFLightColors.borderStrong),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.g_mobiledata_rounded,
                  size: 22, color: PFLightColors.muted),
              const SizedBox(width: 8),
              Text(
                'Continue with Google',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PFLightColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
