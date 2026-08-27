import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/primary_button.dart';
import '../home/home_screen.dart';
import 'auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final t = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      await auth.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      _goHome();
    } catch (e) {
      setState(() => _error = _friendlyError(e, t));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogle() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      final result = await auth.signInWithGoogle();
      if (result != null) _goHome();
    } catch (e) {
      setState(() => _error = _friendlyError(e, t));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGuest() async {
    final t = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      await auth.signInAnonymously();
      _goHome();
    } catch (e) {
      setState(() => _error = _friendlyError(e, t));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e, AppLocalizations t) {
    final msg = e.toString();
    if (msg.contains('user-not-found') || msg.contains('wrong-password')) {
      return t.incorrectCredentials;
    }
    if (msg.contains('network')) return t.networkError;
    return t.somethingWentWrong;
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 440 : double.infinity),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Center(child: AppLogo(size: 68)),
                    const SizedBox(height: 28),
                    Text(t.welcomeBack,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text(t.signInToContinue,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 32),
                    if (_error != null) ...[
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          InputDecoration(hintText: t.email),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? t.enterValidEmail
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: t.password,
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? t.minSixChars
                          : null,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: t.signIn,
                      loading: _loading,
                      onPressed: _handleEmailLogin,
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(t.orDivider,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: t.continueWithGoogle,
                      icon: Icons.g_mobiledata_rounded,
                      outlined: true,
                      loading: _loading,
                      onPressed: _handleGoogle,
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: t.joinAnonymously,
                      icon: Icons.person_outline_rounded,
                      outlined: true,
                      loading: _loading,
                      onPressed: _handleGuest,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.noAccount),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SignupScreen()),
                          ),
                          child: Text(
                            t.signUp,
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
