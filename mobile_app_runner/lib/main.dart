import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'agreement_video_capture_page.dart';
import 'liveness_capture_page.dart';

const bg = Color(0xFF0B1110);
const panel = Color(0xFF151D1B);
const green = Color(0xFF88B44A);
const blue = Color(0xFF2D2B50);
const sky = Color(0xFF43B5D4);
const muted = Color(0xFFAAC0B7);
const _phoneNotificationChannel = MethodChannel(
  'et.mekenet.mekenet_mobile/notifications',
);

class _MekenetPalette extends ThemeExtension<_MekenetPalette> {
  const _MekenetPalette({
    required this.panel,
    required this.muted,
    required this.border,
    required this.track,
    required this.profileStart,
  });

  final Color panel;
  final Color muted;
  final Color border;
  final Color track;
  final Color profileStart;

  @override
  _MekenetPalette copyWith({
    Color? panel,
    Color? muted,
    Color? border,
    Color? track,
    Color? profileStart,
  }) => _MekenetPalette(
    panel: panel ?? this.panel,
    muted: muted ?? this.muted,
    border: border ?? this.border,
    track: track ?? this.track,
    profileStart: profileStart ?? this.profileStart,
  );

  @override
  _MekenetPalette lerp(ThemeExtension<_MekenetPalette>? other, double t) {
    if (other is! _MekenetPalette) return this;
    return _MekenetPalette(
      panel: Color.lerp(panel, other.panel, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      track: Color.lerp(track, other.track, t)!,
      profileStart: Color.lerp(profileStart, other.profileStart, t)!,
    );
  }
}

extension _MekenetPaletteContext on BuildContext {
  _MekenetPalette get palette => Theme.of(this).extension<_MekenetPalette>()!;
}

ThemeData _makeTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final palette = _MekenetPalette(
    panel: dark ? panel : const Color(0xFFFFFFFF),
    muted: dark ? const Color(0xFFABB0BF) : const Color(0xFF77798B),
    border: dark ? const Color(0xFF2B342F) : const Color(0xFFE9E9EF),
    track: dark ? const Color(0xFF343B35) : const Color(0xFFE8E9ED),
    profileStart: dark ? const Color(0xFF202333) : const Color(0xFFF0F3E9),
  );
  final scheme = ColorScheme.fromSeed(
    seedColor: green,
    brightness: brightness,
    primary: green,
    secondary: sky,
    surface: dark ? bg : const Color(0xFFF8F8FB),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? bg : const Color(0xFFF8F8FB),
    extensions: [palette],
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? bg : Colors.white,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: palette.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: green, width: 1.5),
      ),
      labelStyle: TextStyle(color: palette.muted),
      hintStyle: TextStyle(color: palette.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.panel,
      indicatorColor: green.withAlpha(dark ? 38 : 28),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? green : palette.muted,
        ),
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  runApp(MekenetApp(api: api));
}

class MekenetApp extends StatefulWidget {
  const MekenetApp({super.key, required this.api});
  final ApiClient api;

  @override
  State<MekenetApp> createState() => _MekenetAppState();
}

class _MekenetAppState extends State<MekenetApp> {
  Map<String, dynamic>? user;
  bool loading = true;
  ThemeMode themeMode = ThemeMode.light;
  final themeStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final savedTheme = await themeStorage.read(key: 'mekenet_theme_mode');
      if (savedTheme == 'light') themeMode = ThemeMode.light;
      if (savedTheme == 'dark') themeMode = ThemeMode.dark;
    } catch (_) {}
    if (await widget.api.hasToken()) {
      try {
        user = _map(
          (await widget.api
              .get('/me')
              .timeout(const Duration(seconds: 8)))['user'],
        );
      } catch (_) {
        await widget.api.clearToken();
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _toggleTheme() async {
    final next = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() => themeMode = next);
    try {
      await themeStorage.write(
        key: 'mekenet_theme_mode',
        value: next == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {}
  }

  Future<void> _signOut() async {
    try {
      await widget.api.post('/auth/logout');
    } catch (_) {}
    await widget.api.clearToken();
    if (mounted) setState(() => user = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mekenet Ekub',
      debugShowCheckedModeBanner: false,
      theme: _makeTheme(Brightness.light),
      darkTheme: _makeTheme(Brightness.dark),
      themeMode: themeMode,
      home: loading
          ? const _BrandedSplash()
          : user == null
          ? AuthPage(
              api: widget.api,
              onSignedIn: (value) => setState(() => user = value),
              isDark: themeMode == ThemeMode.dark,
              onToggleTheme: _toggleTheme,
            )
          : MemberPage(
              api: widget.api,
              user: user!,
              onSignOut: _signOut,
              themeMode: themeMode,
              onToggleTheme: _toggleTheme,
            ),
    );
  }
}

class _BrandedSplash extends StatelessWidget {
  const _BrandedSplash();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned(
          top: -90,
          right: -70,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sky.withAlpha(18),
            ),
          ),
        ),
        Positioned(
          bottom: -120,
          left: -90,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: green.withAlpha(18),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: green.withAlpha(100), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: green.withAlpha(25),
                        blurRadius: 26,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/mekenet-ekub-logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 19),
                Text(
                  'Mekenet Ekub',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Build your future together',
                  style: TextStyle(color: context.palette.muted),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.api,
    required this.onSignedIn,
    required this.isDark,
    required this.onToggleTheme,
  });
  final ApiClient api;
  final ValueChanged<Map<String, dynamic>> onSignedIn;
  final bool isDark;
  final Future<void> Function() onToggleTheme;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final login = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final username = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final confirmation = TextEditingController();

  bool registering = false;
  bool busy = false;
  bool acceptedTerms = false;
  String? challengeId;
  String? emailHint;
  String? emailNotice;
  String method = 'email';
  List<String> methods = [];
  String? error;
  String? notice;

  @override
  void dispose() {
    for (final controller in [
      login,
      password,
      code,
      firstName,
      lastName,
      username,
      phone,
      email,
      confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (registering && !acceptedTerms) {
      setState(
        () => error =
            'Accept the Terms & Conditions and Privacy Policy to create your account.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      if (registering) {
        final response = await widget.api.post(
          '/auth/register',
          authenticated: false,
          body: {
            'first_name': firstName.text.trim(),
            'last_name': lastName.text.trim(),
            'username': username.text.trim(),
            'phone': phone.text.trim(),
            'email': email.text.trim(),
            'password': password.text,
            'password_confirmation': confirmation.text,
            'terms_accepted': '1',
            'device_name': 'Mekenet mobile',
          },
        );
        setState(() {
          registering = false;
          login.text = username.text.trim();
          password.clear();
          confirmation.clear();
          notice = response['message']?.toString();
        });
      } else {
        final response = await widget.api.post(
          '/auth/login',
          authenticated: false,
          body: {
            'login': login.text.trim(),
            'password': password.text,
            'device_name': 'Mekenet mobile',
          },
        );
        if (response['two_factor_required'] == true) {
          methods = (response['methods'] as List? ?? const [])
              .map((value) => value.toString())
              .toList();
          challengeId = response['challenge_id']?.toString();
          emailHint = response['email_hint']?.toString();
          emailNotice = response['email_notice']?.toString();
          method = methods.contains('email') ? 'email' : 'authenticator';
          setState(() => notice = emailNotice);
        } else {
          await _acceptToken(response);
        }
      }
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } catch (_) {
      setState(() => error = 'Could not complete this request.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verifyCode() async {
    if (challengeId == null || code.text.trim().isEmpty) {
      setState(() => error = 'Enter the verification code.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await widget.api.post(
        '/auth/2fa/verify',
        authenticated: false,
        body: {
          'challenge_id': challengeId,
          'method': method,
          'code': code.text.trim(),
        },
      );
      await _acceptToken(response);
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resendCode() async {
    if (challengeId == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await widget.api.post(
        '/auth/2fa/resend',
        authenticated: false,
        body: {'challenge_id': challengeId},
      );
      setState(() => notice = response['message']?.toString());
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _acceptToken(Map<String, dynamic> response) async {
    final token = response['access_token']?.toString() ?? '';
    if (token.isEmpty) {
      setState(() => error = 'The site did not return a sign-in token.');
      return;
    }
    await widget.api.saveToken(token);
    widget.onSignedIn(_map(response['user']));
  }

  Future<void> _openForgotPassword() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ForgotPasswordPage(api: widget.api)),
    );
    if (mounted && updated == true)
      setState(() {
        error = null;
        notice = 'Password reset. Sign in with your new password.';
      });
  }

  Future<void> _openLegal(bool privacy) => Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => LegalDocumentPage(privacy: privacy)),
  );

  @override
  Widget build(BuildContext context) {
    final checkingCode = challengeId != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton.filledTonal(
                        tooltip: widget.isDark
                            ? 'Switch to light theme'
                            : 'Switch to dark theme',
                        onPressed: widget.onToggleTheme,
                        icon: Icon(
                          widget.isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: green.withAlpha(110),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/mekenet-ekub-logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      checkingCode
                          ? 'Verify your account'
                          : registering
                          ? 'Sign up'
                          : 'Login',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: blue, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      checkingCode
                          ? 'Enter the code sent to your account to continue.'
                          : registering
                          ? 'Create your Mekenet Ekub account and start saving together.'
                          : 'Manage your Ekubs and track your contributions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.palette.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.palette.panel,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: context.palette.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(
                              widget.isDark ? 12 : 9,
                            ),
                            blurRadius: 24,
                            offset: const Offset(0, 9),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (checkingCode)
                            _verificationFields()
                          else if (registering)
                            _registrationFields()
                          else
                            _loginFields(),
                          if (registering) ...[
                            const SizedBox(height: 4),
                            CheckboxListTile(
                              value: acceptedTerms,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: busy
                                  ? null
                                  : (value) => setState(() {
                                      acceptedTerms = value == true;
                                      error = null;
                                    }),
                              title: const Text(
                                'I have read and agree to the Terms & Conditions and Privacy Policy.',
                                style: TextStyle(fontSize: 13, height: 1.35),
                              ),
                            ),
                            Wrap(
                              alignment: WrapAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () => _openLegal(false),
                                  child: const Text('Read Terms & Conditions'),
                                ),
                                TextButton(
                                  onPressed: () => _openLegal(true),
                                  child: const Text('Read Privacy Policy'),
                                ),
                              ],
                            ),
                          ],
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            _Message(text: error!, isError: true),
                          ],
                          if (notice != null) ...[
                            const SizedBox(height: 12),
                            _Message(text: notice!, isError: false),
                          ],
                          const SizedBox(height: 13),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 3,
                              ),
                              onPressed: busy
                                  ? null
                                  : checkingCode
                                  ? _verifyCode
                                  : submit,
                              child: busy
                                  ? const SizedBox(
                                      width: 19,
                                      height: 19,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      checkingCode
                                          ? 'Verify and continue'
                                          : registering
                                          ? 'Create account'
                                          : 'Log In',
                                    ),
                            ),
                          ),
                          if (checkingCode) ...[
                            if (methods.length > 1)
                              Wrap(
                                alignment: WrapAlignment.center,
                                children: methods.map((value) {
                                  final label = value == 'email'
                                      ? 'email code'
                                      : 'authenticator';
                                  return TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => setState(() {
                                            method = value;
                                            code.clear();
                                            notice = value == 'email'
                                                ? emailNotice
                                                : 'Enter the current code from your authenticator app.';
                                          }),
                                    child: Text(
                                      method == value
                                          ? 'Using $label'
                                          : 'Use $label',
                                    ),
                                  );
                                }).toList(),
                              ),
                            if (method == 'email')
                              TextButton(
                                onPressed: busy ? null : _resendCode,
                                child: const Text('Resend email code'),
                              ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      challengeId = null;
                                      methods = [];
                                      code.clear();
                                      error = null;
                                      notice = null;
                                    }),
                              child: const Text('Back to sign in'),
                            ),
                          ] else
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    registering
                                        ? 'Already have an account? '
                                        : 'Don’t have an account? ',
                                    style: TextStyle(
                                      color: context.palette.muted,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => setState(() {
                                            registering = !registering;
                                            acceptedTerms = false;
                                            error = null;
                                            notice = null;
                                          }),
                                    child: Text(
                                      registering ? 'Log In' : 'Sign Up',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'By continuing, please review our ',
                          style: TextStyle(
                            color: context.palette.muted,
                            fontSize: 12,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openLegal(false),
                          child: const Text('Terms & Conditions'),
                        ),
                        Text(
                          'and',
                          style: TextStyle(
                            color: context.palette.muted,
                            fontSize: 12,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openLegal(true),
                          child: const Text('Privacy Policy'),
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

  Widget _loginFields() => Column(
    children: [
      TextFormField(
        controller: login,
        decoration: const InputDecoration(
          labelText: 'Phone number, username, or email',
          prefixIcon: Icon(Icons.phone_iphone_outlined),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter your sign-in details.'
            : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: password,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Password',
          prefixIcon: Icon(Icons.lock_outline),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? 'Enter your password.' : null,
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: busy ? null : _openForgotPassword,
          icon: const Icon(Icons.lock_reset_rounded, size: 18),
          label: const Text('Forgot password?'),
        ),
      ),
    ],
  );

  Widget _registrationFields() => Column(
    children: [
      Row(
        children: [
          Expanded(child: _field(firstName, 'First name')),
          const SizedBox(width: 9),
          Expanded(child: _field(lastName, 'Last name')),
        ],
      ),
      const SizedBox(height: 10),
      _field(username, 'Username'),
      const SizedBox(height: 10),
      _field(phone, 'Phone number', keyboard: TextInputType.phone),
      const SizedBox(height: 10),
      TextFormField(
        controller: email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email address'),
        validator: (value) {
          final address = (value ?? '').trim();
          if (address.isEmpty) return 'Enter your email address.';
          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
            return 'Enter a valid email address.';
          }
          return null;
        },
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: password,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Password',
          helperText: '8+ characters, uppercase, number, and symbol',
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Enter a password.';
          if (value.length < 8 ||
              !RegExp(r'[A-Z]').hasMatch(value) ||
              !RegExp(r'\d').hasMatch(value) ||
              !RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
            return 'Use the required password format.';
          }
          return null;
        },
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: confirmation,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Confirm password'),
        validator: (value) =>
            value != password.text ? 'Passwords do not match.' : null,
      ),
    ],
  );

  Widget _verificationFields() => Column(
    children: [
      if (method == 'email' && emailHint != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Code sent to $emailHint',
            style: TextStyle(color: context.palette.muted),
          ),
        ),
      TextFormField(
        controller: code,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: method == 'email'
              ? 'Email verification code'
              : 'Authenticator code',
        ),
      ),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    TextInputType? keyboard,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboard,
    decoration: InputDecoration(labelText: label),
    validator: (value) => required && (value == null || value.trim().isEmpty)
        ? 'Enter $label.'
        : null,
  );
}

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.privacy});

  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final title = privacy ? 'Privacy Policy' : 'Terms & Conditions';
    final sections = privacy
        ? const [
            (
              'Information we collect',
              'Your name, username, phone number and email; identity verification details and images; payment records, transaction references and receipt images; and payout accounts you save.',
            ),
            (
              'How we use it',
              'We use this information to verify identity, operate Ekub groups, review contributions, send payment and security notices, pay winners, and prevent fraud or abuse.',
            ),
            (
              'Who can see it',
              'Authorised Mekenet Ekub administrators and partners with matching permissions can review identity and payment information. Members cannot see other members’ private documents or payout account details.',
            ),
            (
              'Security',
              'Keep your password and one-time verification codes private. If you enable two-step verification, a second code is required after your password at sign-in.',
            ),
            (
              'Retention and account deletion',
              'You can request account deletion in Settings when you are not part of a running Ekub. Contribution and payout records may be retained in anonymised form for accounting and audit purposes.',
            ),
            (
              'Your choices',
              'You can update your profile, password, saved payout accounts and two-step verification settings. Contact Mekenet Ekub support with privacy questions.',
            ),
          ]
        : const [
            (
              'Using Mekenet Ekub',
              'Provide accurate account information, protect your sign-in credentials and use the service lawfully. Keep your email and phone number current so we can send account and payment notices.',
            ),
            (
              'Joining an Ekub',
              'Review an Ekub’s contribution, frequency, duration, capacity and status before joining. Identity verification approval is required before joining an active Ekub.',
            ),
            (
              'Contributions and payment review',
              'Submit the correct amount using the payment instructions shown in the app. Include the transaction reference and receipt. A submitted payment remains pending until an administrator verifies it.',
            ),
            (
              'Service fee and payout',
              'A 2% service fee is deducted from the approved gross pool when a member wins a period. The winner receives the remaining 98%, subject to the group’s payment records.',
            ),
            (
              'Late payment',
              'Payments submitted after the applicable due date may receive a late-payment penalty according to the Ekub configuration shown in the service.',
            ),
            (
              'Support',
              'Contact Mekenet Ekub support if you notice an incorrect payment record, account issue or security concern.',
            ),
          ];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: blue,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            privacy
                ? 'How Mekenet Ekub handles account and payment information.'
                : 'Please review these service rules before creating an account or joining an Ekub.',
            style: TextStyle(color: context.palette.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          ...sections.map(
            (section) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.$1,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      section.$2,
                      style: TextStyle(
                        color: context.palette.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool codeSent = false, busy = false;
  String? error, notice;
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (email.text.trim().isEmpty || !email.text.contains('@')) {
      setState(() => error = 'Enter the email address on your account.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final response = await widget.api.post(
        '/auth/forgot-password',
        authenticated: false,
        body: {'email': email.text.trim()},
      );
      if (mounted)
        setState(() {
          codeSent = true;
          notice = response['message']?.toString();
        });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not request a reset code.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reset() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await widget.api.post(
        '/auth/reset-password',
        authenticated: false,
        body: {
          'email': email.text.trim(),
          'code': code.text.trim(),
          'password': password.text,
          'password_confirmation': confirmation.text,
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not update the password.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [green, sky]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Get back into your account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Enter the email address linked to your account. We’ll send a short-lived verification code. If you signed up without an email, contact support for help.',
                  style: TextStyle(color: context.palette.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: email,
                  enabled: !codeSent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Account email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email address.'
                      : null,
                ),
                if (codeSent) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Email verification code',
                      prefixIcon: Icon(Icons.password_rounded),
                    ),
                    validator: (v) => v == null || v.trim().length != 6
                        ? 'Enter the 6-digit code.'
                        : null,
                  ),
                  const SizedBox(height: 5),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      helperText:
                          '8+ characters, uppercase, number, and symbol',
                    ),
                    validator: (v) =>
                        v == null ||
                            v.length < 8 ||
                            !RegExp(r'[A-Z]').hasMatch(v) ||
                            !RegExp(r'[0-9]').hasMatch(v) ||
                            !RegExp(r'[^A-Za-z0-9]').hasMatch(v)
                        ? 'Use the required password format.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmation,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                    validator: (v) =>
                        v != password.text ? 'Passwords do not match.' : null,
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  _Message(text: error!, isError: true),
                ],
                if (notice != null) ...[
                  const SizedBox(height: 12),
                  _Message(text: notice!, isError: false),
                ],
                const SizedBox(height: 17),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : codeSent
                      ? _reset
                      : _sendCode,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          codeSent ? Icons.check_rounded : Icons.email_outlined,
                        ),
                  label: Text(codeSent ? 'Reset password' : 'Send reset code'),
                ),
                if (codeSent)
                  TextButton.icon(
                    onPressed: busy ? null : _sendCode,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Send another code'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MemberPage extends StatefulWidget {
  const MemberPage({
    super.key,
    required this.api,
    required this.user,
    required this.onSignOut,
    required this.themeMode,
    required this.onToggleTheme,
  });
  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;
  final ThemeMode themeMode;
  final Future<void> Function() onToggleTheme;

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> with WidgetsBindingObserver {
  int selected = 0;
  int unreadNotificationCount = 0;
  Timer? _winnerPoll;
  Timer? _notificationPoll;
  bool _checkingNewEkubs = false;
  bool _checkingWinners = false;
  bool _notificationsPrimed = false;
  final Set<int> _seenNotificationIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runLoginPrompts();
    });
    _winnerPoll = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkWinnerCelebrations();
    });
    _notificationPoll = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkNewNotifications();
    });
  }

  Future<void> _runLoginPrompts() async {
    await _requestPhoneNotificationPermission();
    await _checkNewNotifications();
    await _checkNewEkubAnnouncements();
    await _checkWinnerCelebrations();
  }

  Future<void> _requestPhoneNotificationPermission() async {
    try {
      await _phoneNotificationChannel.invokeMethod<bool>('requestPermission');
    } on PlatformException catch (_) {
      // Device notification settings should not block sign-in.
    } on MissingPluginException catch (_) {}
  }

  Future<void> _showPhoneNotification(Map<String, dynamic> row) async {
    try {
      await _phoneNotificationChannel.invokeMethod<bool>('show', {
        'id': _int(row['id']),
        'title': (row['title'] ?? 'Mekenet Ekub update').toString(),
        'body': (row['body'] ?? '').toString(),
      });
    } on PlatformException catch (_) {
      // Keep in-app notifications available if the OS blocks tray alerts.
    } on MissingPluginException catch (_) {}
  }

  Future<void> _checkNewEkubAnnouncements() async {
    if (!mounted || _checkingNewEkubs) return;
    _checkingNewEkubs = true;
    final accountKey =
        (widget.user['id'] ?? widget.user['username'] ?? 'member').toString();
    final storageKey = 'mekenet_seen_new_ekubs_$accountKey';
    final storage = const FlutterSecureStorage();
    try {
      final response = await widget.api
          .get('/ekubs')
          .timeout(const Duration(seconds: 12));
      final saved = await storage.read(key: storageKey);
      final lastSeenId = saved == null ? null : int.tryParse(saved);
      final allEkubs = (response['data'] as List? ?? const [])
          .map(_map)
          .where((item) => item['created_at'] != null)
          .toList();
      final ids = allEkubs.map((item) => _int(item['id'])).toList();
      final marker = ids.isEmpty
          ? lastSeenId
          : ids.reduce((a, b) => a > b ? a : b);
      final available =
          allEkubs.where((item) {
            final id = _int(item['id']);
            return lastSeenId == null || id > lastSeenId;
          }).toList()..sort((a, b) {
            final aDate = DateTime.tryParse(a['created_at'].toString());
            final bDate = DateTime.tryParse(b['created_at'].toString());
            return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
          });
      final announcements = lastSeenId == null
          ? available.take(5).toList()
          : available;
      if (announcements.isNotEmpty && mounted) {
        final selectedEkubId = await showDialog<int>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _NewEkubsDialog(items: announcements),
        );
        if (marker != null) {
          await storage.write(key: storageKey, value: marker.toString());
        }
        if (selectedEkubId != null && mounted) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => EkubDetails(api: widget.api, id: selectedEkubId),
            ),
          );
        }
      } else {
        if (marker != null) {
          await storage.write(key: storageKey, value: marker.toString());
        }
      }
    } catch (_) {
      // Announcement failures should not interrupt the signed-in experience.
    } finally {
      _checkingNewEkubs = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _winnerPoll?.cancel();
    _notificationPoll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWinnerCelebrations();
      _checkNewNotifications();
    }
  }

  Future<void> _checkNewNotifications() async {
    if (!mounted) return;
    try {
      final response = await widget.api
          .get('/notifications')
          .timeout(const Duration(seconds: 12));
      final unreadCount = _int(response['unread_count']);
      if (mounted && unreadNotificationCount != unreadCount) {
        setState(() => unreadNotificationCount = unreadCount);
      }
      final rows = response['data'] as List? ?? const [];
      final newRows = <Map<String, dynamic>>[];
      for (final value in rows) {
        final row = _map(value);
        final id = _int(row['id']);
        if (id <= 0) continue;
        if (!_notificationsPrimed) {
          _seenNotificationIds.add(id);
        } else if (_seenNotificationIds.add(id)) {
          newRows.add(row);
        }
      }
      _notificationsPrimed = true;
      for (final row in newRows.reversed) {
        if (!mounted) continue;
        await _showPhoneNotification(row);
      }
    } catch (_) {}
  }

  Future<void> _checkWinnerCelebrations() async {
    if (!mounted || _checkingWinners) return;
    _checkingWinners = true;
    try {
      final response = await widget.api
          .get('/my/status')
          .timeout(const Duration(seconds: 15));
      final storage = const FlutterSecureStorage();
      final accountKey =
          (widget.user['id'] ?? widget.user['username'] ?? 'member').toString();
      final storageKey = 'mekenet_seen_winner_payouts_$accountKey';
      final saved = await storage.read(key: storageKey);
      final seen = <String>{
        if (saved != null && saved.isNotEmpty) ...saved.split(','),
      };
      final unseen = <Map<String, dynamic>>[];

      for (final value in (response['data'] as List? ?? const [])) {
        final row = _map(value);
        final ekub = _map(row['ekub']);
        final membership = _map(row['membership']);
        final memberId = _int(membership['id']);
        for (final periodValue in (row['periods'] as List? ?? const [])) {
          final period = _map(periodValue);
          if (period['winner'] is! Map) continue;
          final winner = _map(period['winner']);
          if (_int(winner['winner_member_id']) != memberId) continue;
          final payoutId = _int(winner['payout_id']);
          if (payoutId <= 0 || !seen.add(payoutId.toString())) continue;
          unseen.add({
            'ekub_name': (ekub['name'] ?? 'Ekub').toString(),
            'period_no': _int(period['period_no']),
            'net_amount': winner['net_amount'],
          });
        }
      }

      if (unseen.isEmpty) return;
      await storage.write(key: storageKey, value: seen.join(','));
      for (final winner in unseen) {
        if (!mounted) break;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: const Color(0xD900080A),
          builder: (_) => _WinnerCelebrationDialog(
            ekubName: winner['ekub_name'] as String,
            periodNo: winner['period_no'] as int,
            netAmount: winner['net_amount'],
          ),
        );
      }
    } catch (_) {
      // A failed status request should not interrupt normal app navigation.
    } finally {
      _checkingWinners = false;
    }
  }

  void _selectTab(int index) {
    if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => StatusView(api: widget.api)),
      );
      return;
    }
    setState(() => selected = index);
  }

  void _openCreateEkub() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileFeaturePage(
          api: widget.api,
          user: widget.user,
          feature: 'applications',
          onSignOut: widget.onSignOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardView(
        api: widget.api,
        user: widget.user,
        onNavigate: _selectTab,
        onCreateEkub: _openCreateEkub,
      ),
      ExploreView(api: widget.api),
      MyEkubsView(
        api: widget.api,
        onShowStatus: () => _selectTab(3),
        onBrowse: () => _selectTab(1),
      ),
      StatusView(api: widget.api),
      ProfileView(
        api: widget.api,
        user: widget.user,
        onSignOut: widget.onSignOut,
        isDark: widget.themeMode == ThemeMode.dark,
        onToggleTheme: widget.onToggleTheme,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/mekenet-ekub-logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              selected == 0
                  ? 'Mekenet Ekub'
                  : selected == 1
                  ? 'Ekubs'
                  : selected == 2
                  ? 'My Ekubs'
                  : 'Profile',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications and activity',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NotificationsView(
                  api: widget.api,
                  onRead: _checkNewNotifications,
                ),
              ),
            ),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (unreadNotificationCount > 0)
                  Positioned(
                    top: -7,
                    right: -8,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE34255),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadNotificationCount > 99
                            ? '99+'
                            : unreadNotificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: widget.themeMode == ThemeMode.dark
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(index: selected, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 62,
        height: 62,
        child: FloatingActionButton(
          heroTag: 'create-ekub-tab',
          tooltip: 'Create an Ekub',
          onPressed: _openCreateEkub,
          backgroundColor: green,
          foregroundColor: Colors.white,
          elevation: 5,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 34),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Container(
          height: 67,
          decoration: BoxDecoration(
            color: context.palette.panel,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: context.palette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(
                  widget.themeMode == ThemeMode.dark ? 32 : 12,
                ),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _MemberNavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                  selected: selected == 0,
                  onTap: () => _selectTab(0),
                ),
              ),
              Expanded(
                child: _MemberNavItem(
                  icon: Icons.storefront_outlined,
                  selectedIcon: Icons.storefront_rounded,
                  label: 'Ekubs',
                  selected: selected == 1,
                  onTap: () => _selectTab(1),
                ),
              ),
              const SizedBox(width: 66),
              Expanded(
                child: _MemberNavItem(
                  icon: Icons.savings_outlined,
                  selectedIcon: Icons.savings_rounded,
                  label: 'Dashboard',
                  selected: selected == 2,
                  onTap: () => _selectTab(2),
                ),
              ),
              Expanded(
                child: _MemberNavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profile',
                  selected: selected == 4,
                  onTap: () => _selectTab(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewEkubsDialog extends StatelessWidget {
  const _NewEkubsDialog({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: green.withAlpha(28),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fiber_new_rounded, color: green),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'New Ekubs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'These Ekubs were added since your last visit.',
            style: TextStyle(color: context.palette.muted, height: 1.4),
          ),
          const SizedBox(height: 13),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 390),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.palette.panel,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: sky.withAlpha(28),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.savings_outlined, color: sky),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item['name'] ?? 'Ekub').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_money(item['base_amount'])} ETB · ${item['frequency'] ?? 'Flexible'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.palette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, _int(item['id'])),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

class _WinnerCelebrationDialog extends StatefulWidget {
  const _WinnerCelebrationDialog({
    required this.ekubName,
    required this.periodNo,
    required this.netAmount,
  });

  final String ekubName;
  final int periodNo;
  final dynamic netAmount;

  @override
  State<_WinnerCelebrationDialog> createState() =>
      _WinnerCelebrationDialogState();
}

class _WinnerCelebrationDialogState extends State<_WinnerCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(count: 3);
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _confetti,
            builder: (context, _) => CustomPaint(
              painter: _CelebrationConfettiPainter(_confetti.value),
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 660),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF4),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 36,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 68)),
                    const SizedBox(height: 12),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFF8A00), Color(0xFFD448A6)],
                      ).createShader(bounds),
                      child: const Text(
                        'Congratulations!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'You are the winner of ${widget.ekubName} — Period ${widget.periodNo}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF27313A),
                        fontSize: 17,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _money(widget.netAmount),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF149B59),
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 17),
                    const Text(
                      'The Mekenet Ekub team will contact you about your payout.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF737B89),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF47B24),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 13,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Thank you 🎉'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CelebrationConfettiPainter extends CustomPainter {
  const _CelebrationConfettiPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(407);
    const colors = [
      Color(0xFFFFB000),
      Color(0xFFEF476F),
      Color(0xFF168AAD),
      Color(0xFF7B61FF),
      Color(0xFF06A77D),
      Color(0xFFFF7F11),
    ];
    for (var index = 0; index < 115; index++) {
      final x = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final drift = math.sin((progress * math.pi * 2) + index) * 18;
      final y = (startY + progress * size.height * 0.72) % size.height;
      final width = 4 + random.nextDouble() * 5;
      final height = 7 + random.nextDouble() * 8;
      final angle = random.nextDouble() * math.pi + progress * math.pi * 2;
      final paint = Paint()..color = colors[index % colors.length];
      canvas.save();
      canvas.translate(x + drift, y);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CelebrationConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MemberNavItem extends StatelessWidget {
  const _MemberNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? selectedIcon : icon,
            size: 22,
            color: selected ? green : context.palette.muted,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? green : context.palette.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key, required this.api, required this.onRead});
  final ApiClient api;
  final Future<void> Function() onRead;

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  bool loading = true;
  String? error;
  List<({String title, String detail, IconData icon, Color color})> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final next =
        <({String title, String detail, IconData icon, Color color})>[];
    try {
      final saved = await widget.api.get('/notifications');
      for (final value in saved['data'] as List? ?? const []) {
        final row = _map(value);
        final winner = row['type'] == 'winner';
        next.add((
          title: (row['title'] ?? 'Mekenet Ekub update').toString(),
          detail: (row['body'] ?? '').toString(),
          icon: winner
              ? Icons.emoji_events_rounded
              : Icons.notifications_active_outlined,
          color: winner ? green : sky,
        ));
      }
      await widget.api.post('/notifications/read');
      await widget.onRead();
    } on ApiException catch (exception) {
      error = exception.message;
    }
    try {
      final status = await widget.api.get('/my/status');
      for (final row in status['data'] as List? ?? []) {
        final group = _map(row);
        final ekub = _map(group['ekub']);
        final name = (ekub['name'] ?? 'Your Ekub').toString();
        for (final value in group['periods'] as List? ?? []) {
          final period = _map(value);
          if (period['can_pay'] == true) {
            next.add((
              title: '$name · Period ${period['period_no']}',
              detail: 'Contribution due: ${_money(period['available_to_pay'])}',
              icon: Icons.payments_outlined,
              color: green,
            ));
          }
          if (_num(period['pending']) > 0) {
            next.add((
              title: '$name · Payment review',
              detail: '${_money(period['pending'])} is awaiting confirmation.',
              icon: Icons.hourglass_top_rounded,
              color: sky,
            ));
          }
        }
      }
    } on ApiException catch (exception) {
      error = exception.message;
    }
    try {
      final applications = await widget.api.get('/profile/applications');
      for (final row in applications['data'] as List? ?? []) {
        final application = _map(row);
        final status = (application['status'] ?? '').toString();
        if (status.isEmpty || status == 'approved') continue;
        final rejected = status == 'rejected';
        next.add((
          title:
              '${application['name'] ?? 'Ekub application'} · ${status.replaceAll('_', ' ')}',
          detail: rejected
              ? (application['rejection_reason'] ??
                        'Review the application and contact support if needed.')
                    .toString()
              : 'Your request is waiting for administrator review.',
          icon: rejected
              ? Icons.info_outline_rounded
              : Icons.pending_actions_rounded,
          color: rejected ? const Color(0xFFD95368) : sky,
        ));
      }
    } on ApiException catch (exception) {
      error ??= exception.message;
    }
    if (mounted)
      setState(() {
        items = next;
        loading = false;
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [green, sky],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your Ekub updates',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          if (error != null) _Message(text: error!, isError: true),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            const _Empty(
              text:
                  'You’re all caught up. Payment reminders and application updates will appear here.',
            )
          else
            ...items.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 9),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: item.color.withAlpha(28),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(item.icon, color: item.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.detail,
                              style: TextStyle(
                                color: context.palette.muted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            'Updates are based on your latest account status. Pull down to refresh.',
            style: TextStyle(color: context.palette.muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel({required this.api});
  final ApiClient api;
  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final controller = PageController();
  late final Timer timer;
  List<String> images = [];
  bool loading = true;
  int current = 0;

  @override
  void initState() {
    super.initState();
    _loadAds();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!controller.hasClients || images.length < 2) return;
      controller.animateToPage(
        (current + 1) % images.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _loadAds() async {
    try {
      final response = await widget.api
          .get('/ads', authenticated: false)
          .timeout(const Duration(seconds: 8));
      final rows = response['data'] as List? ?? const [];
      final urls = rows
          .map((row) => _map(row)['image_url']?.toString() ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
      if (mounted)
        setState(() {
          images = urls;
          loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    timer.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 136,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [green, sky]),
          ),
          child: Center(
            child: Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/mekenet-ekub-logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (images.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 136,
          child: PageView.builder(
            controller: controller,
            itemCount: images.length,
            onPageChanged: (index) => setState(() => current = index),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Container(
                          color: context.palette.panel,
                          child: const Center(
                            child: CircularProgressIndicator(color: green),
                          ),
                        ),
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: context.palette.panel,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: green,
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: current == index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: current == index
                      ? green
                      : context.palette.muted.withAlpha(100),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({
    super.key,
    required this.api,
    required this.user,
    required this.onNavigate,
    required this.onCreateEkub,
  });
  final ApiClient api;
  final Map<String, dynamic> user;
  final ValueChanged<int> onNavigate;
  final VoidCallback onCreateEkub;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool loading = true;
  String? error;
  int joinedCount = 0;
  double dueTotal = 0;
  double pendingTotal = 0;
  List<dynamic> featured = [];
  final Set<int> joiningIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      final responses = await Future.wait([
        widget.api.get('/ekubs'),
        widget.api.get('/my/ekubs'),
        widget.api.get('/my/status'),
      ]);
      final available = responses[0]['data'] as List? ?? [];
      final joined = responses[1]['data'] as List? ?? [];
      final status = responses[2]['data'] as List? ?? [];
      var due = 0.0;
      var pending = 0.0;
      for (final row in status) {
        final group = _map(row);
        for (final value in group['periods'] as List? ?? []) {
          final period = _map(value);
          pending += _num(period['pending']);
          if (period['can_pay'] == true)
            due += _num(period['available_to_pay']);
        }
      }
      joinedCount = joined.length;
      dueTotal = due;
      pendingTotal = pending;
      featured = available;
    } on ApiException catch (exception) {
      error = exception.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _join(Map<String, dynamic> item) async {
    final id = _int(item['id']);
    if (!joiningIds.add(id)) return;
    if (mounted) setState(() {});
    final joined = await _joinEkub(context, widget.api, item);
    if (joined) await _load();
    joiningIds.remove(id);
    if (mounted) setState(() {});
  }

  Widget _ekubRow(List<Map<String, dynamic>> items) => SizedBox(
    height: 360,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length > 4 ? 4 : items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 11),
      itemBuilder: (context, index) {
        final item = items[index];
        final canJoin =
            item['joined'] != true &&
            item['status'] == 'open' &&
            item['is_full'] != true;
        return SizedBox(
          width: 270,
          child: _HomeEkubCard(
            item: item,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    EkubDetails(api: widget.api, id: _int(item['id'])),
              ),
            ),
            onJoin: canJoin ? () => _join(item) : null,
            actionLabel: item['joined'] == true
                ? 'Joined'
                : item['is_full'] == true
                ? 'Full'
                : canJoin
                ? 'Join'
                : 'Closed',
            busy: joiningIds.contains(_int(item['id'])),
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final firstName = (widget.user['first_name'] ?? 'there').toString();
    final hostedFeatured = featured
        .map(_map)
        .where((item) => item['is_item'] != true)
        .toList();
    final itemFeatured = featured
        .map(_map)
        .where((item) => item['is_item'] == true)
        .toList();
    final moreHosted = hostedFeatured.skip(4).take(8).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [green, sky],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/mekenet-ekub-logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'MEKENET EKUB',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE6F3DB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                const Text(
                  'BUILD YOUR FUTURE TOGETHER',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD7E5B7),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Welcome, $firstName',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Explore Ekubs and grow with your community.',
                  style: TextStyle(height: 1.3, color: Color(0xFFE8E7F3)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PromoCarousel(api: widget.api),
          if (error != null) ...[
            const SizedBox(height: 12),
            _Retry(text: error!, onRetry: _load),
          ],
          const SizedBox(height: 20),
          if (loading || hostedFeatured.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top hosted Ekubs',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate(1),
                  child: const Text('View all'),
                ),
              ],
            ),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              _ekubRow(hostedFeatured),
          ],
          if (!loading && itemFeatured.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item Ekubs',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate(1),
                  child: const Text('View all'),
                ),
              ],
            ),
            _ekubRow(itemFeatured),
          ],
          if (!loading && featured.isEmpty)
            const _Empty(
              text: 'There are no open Ekubs right now. Pull down to refresh.',
            ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your next step starts here',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Start an Ekub or find one that fits your goals.',
                        style: TextStyle(
                          color: Color(0xFFF4F7EC),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: widget.onCreateEkub,
                        style: TextButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Create an Ekub'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.savings_rounded,
                  size: 58,
                  color: Color(0xFFE4F0D3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your activity',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _OverviewTile(
                icon: Icons.groups_outlined,
                label: 'My Ekubs',
                value: joinedCount.toString(),
              ),
              _OverviewTile(
                icon: Icons.payments_outlined,
                label: 'Due now',
                value: _money(dueTotal),
              ),
              _OverviewTile(
                icon: Icons.hourglass_top,
                label: 'Pending review',
                value: _money(pendingTotal),
              ),
              _OverviewTile(
                icon: Icons.verified_user_outlined,
                label: 'Identity',
                value: (widget.user['kyc_status'] ?? 'Not submitted')
                    .toString()
                    .replaceAll('_', ' '),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.groups_outlined, size: 18),
                label: const Text('My Ekubs'),
                onPressed: () => widget.onNavigate(2),
              ),
              ActionChip(
                avatar: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Payment status'),
                onPressed: () => widget.onNavigate(3),
              ),
            ],
          ),
          if (!loading && moreHosted.isNotEmpty) ...[
            const SizedBox(height: 17),
            Text(
              'More to explore',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 9),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 4
                    : constraints.maxWidth >= 620
                    ? 3
                    : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: moreHosted.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 360,
                  ),
                  itemBuilder: (context, offset) {
                    final item = moreHosted[offset];
                    final canJoin =
                        item['joined'] != true &&
                        item['status'] == 'open' &&
                        item['is_full'] != true;
                    return _HomeEkubCard(
                      item: item,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EkubDetails(
                            api: widget.api,
                            id: _int(item['id']),
                          ),
                        ),
                      ),
                      onJoin: canJoin ? () => _join(item) : null,
                      actionLabel: item['joined'] == true
                          ? 'Joined'
                          : item['is_full'] == true
                          ? 'Full'
                          : canJoin
                          ? 'Join'
                          : 'Closed',
                      busy: joiningIds.contains(_int(item['id'])),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: context.palette.panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.palette.border),
    ),
    child: Row(
      children: [
        Icon(icon, color: green, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(color: context.palette.muted, fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CategoryArtwork extends StatefulWidget {
  const _CategoryArtwork({required this.category, required this.height});

  final String category;
  final double height;

  @override
  State<_CategoryArtwork> createState() => _CategoryArtworkState();
}

class _CategoryArtworkState extends State<_CategoryArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category.toLowerCase();
    final student = category.contains('student');
    final teacher = category.contains('teacher');
    final driver = category.contains('driver');
    final merchant =
        category.contains('merchant') || category.contains('merkato');
    final government = category.contains('government');
    final icon = student
        ? Icons.school_rounded
        : teacher
        ? Icons.menu_book_rounded
        : driver
        ? Icons.local_shipping_rounded
        : merchant
        ? Icons.storefront_rounded
        : government
        ? Icons.account_balance_rounded
        : Icons.groups_rounded;
    final label = widget.category.trim().isEmpty
        ? 'EKUB COMMUNITY'
        : '${widget.category.toUpperCase()} EKUB';
    final foreground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF142322)
        : const Color(0xFF173B42);

    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [green.withAlpha(72), sky.withAlpha(68)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -widget.height * .38,
            right: -widget.height * .12,
            child: Container(
              width: widget.height * .92,
              height: widget.height * .92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(35),
              ),
            ),
          ),
          Positioned(
            left: -widget.height * .28,
            bottom: -widget.height * .65,
            child: Container(
              width: widget.height,
              height: widget.height,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(60), width: 2),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _motion,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, math.sin(_motion.value * math.pi) * -5),
              child: child,
            ),
            child: Container(
              width: widget.height * .56,
              height: widget.height * .56,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(190),
                borderRadius: BorderRadius.circular(widget.height * .2),
                boxShadow: [
                  BoxShadow(
                    color: foreground.withAlpha(25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: widget.height * .38,
                color: student || teacher ? green : blue,
              ),
            ),
          ),
          Positioned(
            bottom: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(220),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 9,
                  letterSpacing: .7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeEkubCard extends StatelessWidget {
  const _HomeEkubCard({
    required this.item,
    required this.onTap,
    required this.onJoin,
    required this.actionLabel,
    this.busy = false,
  });
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback? onJoin;
  final String actionLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final images = item['images'] as List? ?? [];
    final isItem = item['is_item'] == true;
    final capacity = _num(item['capacity']);
    final progress = capacity <= 0
        ? 0.0
        : (_num(item['used_capacity']) / capacity).clamp(0.0, 1.0).toDouble();
    final frequency = (item['frequency'] ?? '').toString();
    final total = _num(item['base_amount']) * capacity;
    final slots = _num(item['slots_remaining']);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 112,
            child: !isItem
                ? _CategoryArtwork(
                    category: (item['category'] ?? '').toString(),
                    height: 112,
                  )
                : images.isEmpty
                ? const _ImageBox(height: 112)
                : Image.network(
                    images.first.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ImageBox(height: 112),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _money(item['base_amount']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: green,
                          ),
                        ),
                      ),
                      _Pill(text: frequency.isEmpty ? 'Ekub' : frequency),
                    ],
                  ),
                  Text(
                    item['name']?.toString() ?? 'Ekub',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Total ' + _money(total),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _HomeMetric(
                          label: frequency.isEmpty ? 'Schedule' : frequency,
                          value: _int(item['duration']).toString() + ' periods',
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _HomeMetric(
                          label: 'Members',
                          value:
                              _int(item['member_count']).toString() +
                              '/' +
                              _int(item['capacity']).toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: progress,
                      backgroundColor: context.palette.track,
                      valueColor: const AlwaysStoppedAnimation<Color>(green),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${(progress * 100).round()}% filled',
                          style: TextStyle(
                            color: context.palette.muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: slots > 0 && slots <= 3
                            ? const Color(0xFFD46770)
                            : context.palette.muted,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        item['is_full'] == true
                            ? 'Full'
                            : '${slots.toStringAsFixed(slots % 1 == 0 ? 0 : 1)} left',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: slots > 0 && slots <= 3
                              ? const Color(0xFFD46770)
                              : context.palette.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            minimumSize: const Size(0, 34),
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text(
                            'View details',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FilledButton(
                          onPressed: busy ? null : onJoin,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            minimumSize: const Size(0, 34),
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  actionLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMetric extends StatelessWidget {
  const _HomeMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.palette.muted, fontSize: 9.5),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
      ),
    ],
  );
}

class ExploreView extends StatefulWidget {
  const ExploreView({super.key, required this.api});
  final ApiClient api;

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  final search = TextEditingController();
  List<dynamic> rows = [];
  List<String> categories = [];
  List<String> frequencies = [];
  String category = 'All categories';
  String frequency = 'All frequencies';
  bool loading = true;
  final Set<int> joiningIds = {};
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      final response = await widget.api.get('/ekubs');
      rows = response['data'] as List? ?? [];
      categories = (response['categories'] as List? ?? const [])
          .map((value) => value.toString())
          .toList();
      frequencies = (response['frequencies'] as List? ?? const [])
          .map((value) => value.toString())
          .toList();
    } on ApiException catch (exception) {
      error = exception.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _join(Map<String, dynamic> item) async {
    final id = _int(item['id']);
    if (!joiningIds.add(id)) return;
    setState(() {});
    try {
      final joined = await _joinEkub(context, widget.api, item);
      if (joined) await _load();
    } finally {
      joiningIds.remove(id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final visible = rows.where((row) {
      final item = _map(row);
      final matchesQuery =
          query.isEmpty ||
          (item['name'] ?? '').toString().toLowerCase().contains(query) ||
          (item['category'] ?? '').toString().toLowerCase().contains(query) ||
          (item['frequency'] ?? '').toString().toLowerCase().contains(query);
      return (category == 'All categories' || item['category'] == category) &&
          (frequency == 'All frequencies' || item['frequency'] == frequency) &&
          matchesQuery;
    }).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PromoCarousel(api: widget.api),
          const SizedBox(height: 11),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search Ekubs',
              prefixIcon: Icon(Icons.search),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'CATEGORY',
            style: TextStyle(
              color: context.palette.muted,
              fontSize: 10,
              letterSpacing: .8,
              fontWeight: FontWeight.w800,
            ),
          ),
          _exploreFilterRow(
            context,
            values: ['All categories', ...categories],
            selected: category,
            onSelected: (value) => setState(() => category = value),
          ),
          const SizedBox(height: 3),
          Text(
            'PAYMENT FREQUENCY',
            style: TextStyle(
              color: context.palette.muted,
              fontSize: 10,
              letterSpacing: .8,
              fontWeight: FontWeight.w800,
            ),
          ),
          _exploreFilterRow(
            context,
            values: ['All frequencies', ...frequencies],
            selected: frequency,
            onSelected: (value) => setState(() => frequency = value),
          ),
          const SizedBox(height: 5),
          Text(
            visible.length.toString() + ' Ekubs',
            style: TextStyle(
              color: context.palette.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(25),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            _Retry(text: error!, onRetry: _load)
          else if (visible.isEmpty)
            const _Empty(
              text:
                  'No Ekubs match your filters. Change the search or pull down to refresh.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 980
                    ? 4
                    : constraints.maxWidth >= 640
                    ? 3
                    : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visible.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: constraints.maxWidth < 360 ? 345 : 360,
                  ),
                  itemBuilder: (context, index) {
                    final item = _map(visible[index]);
                    final id = _int(item['id']);
                    final canJoin =
                        item['joined'] != true &&
                        item['status'] == 'open' &&
                        item['is_full'] != true;
                    final actionLabel = item['joined'] == true
                        ? 'Joined'
                        : item['is_full'] == true
                        ? 'Full'
                        : item['status'] == 'open'
                        ? 'Join'
                        : 'Closed';
                    return _HomeEkubCard(
                      item: item,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EkubDetails(api: widget.api, id: id),
                        ),
                      ),
                      onJoin: canJoin ? () => _join(item) : null,
                      actionLabel: actionLabel,
                      busy: joiningIds.contains(id),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

Widget _exploreFilterRow(
  BuildContext context, {
  required List<String> values,
  required String selected,
  required ValueChanged<String> onSelected,
}) => SizedBox(
  height: 43,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: values.length,
    separatorBuilder: (_, __) => const SizedBox(width: 7),
    itemBuilder: (context, index) {
      final value = values[index];
      final active = value == selected;
      return ChoiceChip(
        label: Text(
          value == 'All categories' || value == 'All frequencies'
              ? 'All'
              : value,
        ),
        selected: active,
        onSelected: (_) => onSelected(value),
        showCheckmark: false,
        labelStyle: TextStyle(
          color: active ? Colors.white : context.palette.muted,
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12,
        ),
        backgroundColor: context.palette.panel,
        selectedColor: green,
        side: BorderSide(color: active ? green : context.palette.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      );
    },
  ),
);

class MyEkubsView extends StatefulWidget {
  const MyEkubsView({
    super.key,
    required this.api,
    required this.onShowStatus,
    required this.onBrowse,
  });
  final ApiClient api;
  final VoidCallback onShowStatus;
  final VoidCallback onBrowse;

  @override
  State<MyEkubsView> createState() => _MyEkubsViewState();
}

class _MyEkubsViewState extends State<MyEkubsView> {
  bool loading = true;
  String? error;
  List<dynamic> rows = [];
  double paidTotal = 0;
  double dueTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      final responses = await Future.wait([
        widget.api.get('/my/ekubs'),
        widget.api.get('/my/status'),
      ]);
      rows = responses[0]['data'] as List? ?? [];
      final statusRows = responses[1]['data'] as List? ?? [];
      paidTotal = 0;
      dueTotal = 0;
      for (final row in statusRows) {
        final group = _map(row);
        for (final value in group['periods'] as List? ?? []) {
          final period = _map(value);
          paidTotal += _num(period['paid']);
          if (period['can_pay'] == true)
            dueTotal += _num(period['available_to_pay']);
        }
      }
    } on ApiException catch (exception) {
      error = exception.message;
    }
    if (mounted) setState(() => loading = false);
  }

  final Set<int> leavingIds = {};

  Future<void> _leave(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this Ekub?'),
        content: Text(
          'You will leave ' + (item['name'] ?? 'this Ekub').toString() + '.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = _int(item['id']);
    setState(() => leavingIds.add(id));
    try {
      final response = await widget.api.delete(
        '/ekubs/' + id.toString() + '/leave',
      );
      if (mounted)
        _snack(
          context,
          response['message']?.toString() ?? 'You left the Ekub.',
        );
      await _load();
    } on ApiException catch (exception) {
      if (mounted) _snack(context, exception.message);
    } finally {
      leavingIds.remove(id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Your rotation',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.palette.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money(paidTotal).replaceAll('.00', ''),
              style: const TextStyle(
                fontSize: 26,
                color: green,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 6, bottom: 4),
              child: Text('in paid contributions'),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              children: [
                SizedBox(
                  width: 260,
                  height: 124,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(260, 124),
                        painter: _RotationGauge(context.palette.track),
                      ),
                      const Positioned(
                        bottom: 6,
                        child: Icon(
                          Icons.savings_outlined,
                          size: 40,
                          color: Color(0xFF9CA0AA),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  loading
                      ? 'Loading your Ekubs…'
                      : rows.isEmpty
                      ? 'No active Ekubs in rotation'
                      : '${rows.length} Ekub${rows.length == 1 ? '' : 's'} in your rotation',
                  style: TextStyle(
                    color: context.palette.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _OverviewTile(
                        icon: Icons.groups_outlined,
                        label: 'Joined',
                        value: rows.length.toString(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OverviewTile(
                        icon: Icons.payments_outlined,
                        label: 'Due now',
                        value: _money(dueTotal),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 17),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(25),
              child: CircularProgressIndicator(),
            ),
          )
        else if (error != null)
          _Retry(text: error!, onRetry: _load)
        else if (rows.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: context.palette.track,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.savings_outlined,
                      color: blue,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 13),
                  const Text(
                    'Welcome to Ekub!',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Join your first Ekub to start saving and tracking your progress here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.palette.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 15),
                  FilledButton.icon(
                    onPressed: widget.onBrowse,
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('Explore Ekubs'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Ekubs',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              TextButton.icon(
                onPressed: widget.onShowStatus,
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Payments'),
              ),
            ],
          ),
          ...rows.map((row) {
            final item = _map(row);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EkubCard(
                item: item,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EkubDetails(api: widget.api, id: _int(item['id'])),
                  ),
                ),
                onAction: widget.onShowStatus,
                actionLabel: 'Payments',
                actionIcon: Icons.receipt_long_outlined,
                onExtraAction:
                    item['status'] == 'open' &&
                        !leavingIds.contains(_int(item['id']))
                    ? () => _leave(item)
                    : null,
                extraActionLabel: leavingIds.contains(_int(item['id']))
                    ? 'Wait'
                    : 'Leave',
                extraActionIcon: Icons.logout,
                busy: leavingIds.contains(_int(item['id'])),
              ),
            );
          }),
        ],
      ],
    ),
  );
}

class _RotationGauge extends CustomPainter {
  const _RotationGauge(this.track);
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height),
      width: size.width - 36,
      height: (size.width - 36),
    );
    canvas.drawArc(rect, 3.141592653589793, -3.141592653589793, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RotationGauge oldDelegate) =>
      oldDelegate.track != track;
}

class EkubDetails extends StatefulWidget {
  const EkubDetails({super.key, required this.api, required this.id});
  final ApiClient api;
  final int id;
  @override
  State<EkubDetails> createState() => _EkubDetailsState();
}

class _EkubDetailsState extends State<EkubDetails> {
  Map<String, dynamic>? result;
  bool loading = true;
  bool busy = false;
  int? selectedPaymentPeriod;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      result = await widget.api.get('/ekubs/' + widget.id.toString());
    } on ApiException catch (exception) {
      error = exception.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _join() async {
    final item = _map(result?['ekub']);
    setState(() {
      busy = true;
      error = null;
    });
    final joined = await _joinEkub(context, widget.api, item);
    if (joined) await _load();
    if (mounted) setState(() => busy = false);
  }

  Widget _myPaymentDetails() {
    final periods = result?['my_payment_periods'] as List? ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'My payment details',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          'Choose a period to view its contribution and payment records.',
          style: TextStyle(color: context.palette.muted),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: selectedPaymentPeriod,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Payment period',
            prefixIcon: Icon(Icons.event_note_rounded),
          ),
          hint: const Text('Choose a period'),
          items: periods.map((value) {
            final period = _map(value);
            return DropdownMenuItem<int>(
              value: _int(period['period_no']),
              child: Text('Period ${period['period_no']}'),
            );
          }).toList(),
          onChanged: (value) => setState(() => selectedPaymentPeriod = value),
        ),
        if (selectedPaymentPeriod == null) ...[
          const SizedBox(height: 10),
          const _Empty(text: 'Select a period to see its payment details.'),
        ],
        ...periods.map((value) {
          final period = _map(value);
          if (_int(period['period_no']) != selectedPaymentPeriod) {
            return const SizedBox.shrink();
          }
          final payments = period['payments'] as List? ?? const [];
          final remaining = _num(period['remaining']);
          final pending = _num(period['pending']);
          final fullyPaid = period['fully_paid'] == true;
          final periodStatus = fullyPaid
              ? 'Paid'
              : pending > 0
              ? 'Under review'
              : 'Payment due';
          final statusColor = fullyPaid
              ? green
              : pending > 0
              ? const Color(0xFFCC8A24)
              : context.palette.muted;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Period ${period['period_no']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        periodStatus,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Info(
                        label: 'Due',
                        value: '${_money(period['due'])} ETB',
                      ),
                      _Info(
                        label: 'Paid',
                        value: '${_money(period['paid'])} ETB',
                      ),
                      _Info(
                        label: 'Pending',
                        value: '${_money(period['pending'])} ETB',
                      ),
                      _Info(
                        label: 'Remaining',
                        value: '${_money(remaining)} ETB',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (payments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'No payment submitted for this period yet.',
                        style: TextStyle(color: context.palette.muted),
                      ),
                    )
                  else
                    ...payments.map((paymentValue) {
                      final payment = _map(paymentValue);
                      final status = (payment['status'] ?? 'pending')
                          .toString();
                      final currency = (payment['payment_currency'] ?? 'ETB')
                          .toString();
                      final currencyAmount = payment['payment_currency_amount'];
                      final receiptUrl = (payment['screenshot_url'] ?? '')
                          .toString();
                      return Container(
                        margin: const EdgeInsets.only(top: 9),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: context.palette.panel,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.palette.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${payment['method']} · ${status.toUpperCase()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Submitted ${_money(payment['amount'])} ETB${currencyAmount == null || currency == 'ETB' ? '' : ' · ${_paymentUsdt(currencyAmount)} $currency'}',
                                    style: TextStyle(
                                      color: context.palette.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (_num(payment['approved_amount']) > 0)
                                    Text(
                                      'Approved ${_money(payment['approved_amount'])} ETB',
                                      style: TextStyle(
                                        color: context.palette.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (_num(payment['penalty']) > 0)
                                    Text(
                                      'Late payment fee ${_money(payment['penalty'])} ETB',
                                      style: TextStyle(
                                        color: context.palette.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  const SizedBox(height: 5),
                                  SelectableText(
                                    'Transaction ID: ${payment['transaction_no']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if ((payment['submitted_at'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Text(
                                      'Submitted ${payment['submitted_at']}',
                                      style: TextStyle(
                                        color: context.palette.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  if (currency != 'ETB' &&
                                      _num(payment['payment_exchange_rate']) >
                                          0)
                                    Text(
                                      'Rate: ${_num(payment['payment_exchange_rate']).toStringAsFixed(4)} ETB per $currency',
                                      style: TextStyle(
                                        color: context.palette.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  if ((payment['reviewed_at'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Text(
                                      'Reviewed ${payment['reviewed_at']}${(payment['approved_by'] ?? '').toString().isEmpty ? '' : ' by ${payment['approved_by']}'}',
                                      style: TextStyle(
                                        color: context.palette.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  if ((payment['rejection_reason'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(
                                        'Review note: ${payment['rejection_reason']}',
                                        style: const TextStyle(
                                          color: Color(0xFFD45353),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (receiptUrl.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.network(
                                  receiptUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 56,
                                    height: 56,
                                    color: context.palette.track,
                                    child: const Icon(Icons.receipt_long),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (result == null)
      return Scaffold(
        appBar: AppBar(),
        body: _Retry(text: error ?? 'Could not load Ekub.', onRetry: _load),
      );
    final item = _map(result!['ekub']);
    final membership = _map(result!['membership']);
    final joined = membership.isNotEmpty;
    final images = item['images'] as List? ?? [];
    final members = result!['members'] as List? ?? [];
    final winners = result!['winners'] as List? ?? [];
    final canJoin =
        !joined && item['is_full'] != true && item['status'] == 'open';

    return Scaffold(
      appBar: AppBar(title: const Text('Ekub details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (item['is_item'] != true)
            _CategoryArtwork(
              category: (item['category'] ?? '').toString(),
              height: 190,
            )
          else if (images.isEmpty)
            const _ImageBox(height: 180)
          else
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => SizedBox(
                  width: MediaQuery.sizeOf(context).width - 32,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.network(
                      images[index].toString(),
                      height: 190,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _ImageBox(height: 180),
                    ),
                  ),
                ),
              ),
            ),
          if (item['is_item'] == true && images.length > 1) ...[
            const SizedBox(height: 6),
            Text(
              'Swipe to view all ' + images.length.toString() + ' photos',
              style: TextStyle(color: context.palette.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 15),
          Text(
            item['name']?.toString() ?? 'Ekub',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            (item['category'] ?? '').toString() +
                ' · ' +
                (item['frequency'] ?? '').toString(),
            style: TextStyle(color: context.palette.muted),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _Info(label: 'Contribution', value: _money(item['base_amount'])),
              _Info(label: 'Periods', value: _int(item['duration']).toString()),
              _Info(
                label: 'Members',
                value: _int(item['member_count']).toString(),
              ),
              _Info(
                label: 'Shares filled',
                value:
                    _num(item['used_capacity']).toStringAsFixed(2) +
                    '/' +
                    _int(item['capacity']).toString(),
              ),
              _Info(label: 'Service fee', value: '2%'),
              _Info(
                label: 'Potential payout',
                value: _money(result!['potential_net_payout']),
              ),
            ],
          ),
          const SizedBox(height: 11),
          const _Message(
            text:
                'The potential payout is calculated after the 2% service fee. Actual payments must be confirmed by the site.',
            isError: false,
          ),
          if (joined) ...[
            const SizedBox(height: 10),
            _Message(
              text:
                  'Your share: ' +
                  (membership['share_type'] ?? '').toString().toUpperCase() +
                  ' · contribution per period: ' +
                  _money(membership['contribution_amount']),
              isError: false,
            ),
            _myPaymentDetails(),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            _Message(text: error!, isError: true),
          ],
          const SizedBox(height: 15),
          if (joined)
            const FilledButton(
              onPressed: null,
              child: Text('You joined this Ekub'),
            )
          else if (canJoin)
            FilledButton.icon(
              onPressed: busy ? null : _join,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: const Text('Join Ekub'),
            )
          else
            _Message(
              text: item['is_full'] == true
                  ? 'This Ekub is full.'
                  : 'This Ekub is no longer accepting members.',
              isError: false,
            ),
          const SizedBox(height: 20),
          Text(
            'Current members',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (members.isEmpty)
            const _Empty(text: 'No members have joined yet.')
          else
            Card(
              child: Column(
                children: members.map((row) {
                  final member = _map(row);
                  final name =
                      ((member['first_name'] ?? '').toString() +
                              ' ' +
                              (member['last_name'] ?? '').toString())
                          .trim();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.palette.panel,
                      child: Text(name.isEmpty ? 'M' : name[0].toUpperCase()),
                    ),
                    title: Text(
                      name.isEmpty ? 'Member' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '@' +
                          (member['username'] ?? '').toString() +
                          ' · ' +
                          (member['share_type'] ?? '').toString() +
                          ' share',
                    ),
                    trailing: Text(
                      _money(member['contribution_amount']),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (winners.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Winners',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...winners.map((row) {
              final winner = _map(row);
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.emoji_events_outlined,
                    color: green,
                  ),
                  title: Text('Period ' + winner['period_no'].toString()),
                  subtitle: Text('@' + (winner['username'] ?? '').toString()),
                  trailing: Text(
                    _money(winner['net_amount']),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class StatusView extends StatefulWidget {
  const StatusView({super.key, required this.api});
  final ApiClient api;
  @override
  State<StatusView> createState() => _StatusViewState();
}

class _StatusViewState extends State<StatusView> with WidgetsBindingObserver {
  bool loading = true;
  String? error;
  List<dynamic> rows = [];
  int? selectedEkubId;
  final Set<String> payingPeriods = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded =
          (await widget.api.get('/my/status'))['data'] as List? ?? [];
      rows = loaded.where((value) {
        final group = _map(value);
        return _map(group['ekub'])['status'] != 'finished';
      }).toList();
      if (selectedEkubId != null &&
          !rows.any(
            (value) => _int(_map(_map(value)['ekub'])['id']) == selectedEkubId,
          )) {
        selectedEkubId = null;
      }
    } on ApiException catch (exception) {
      error = exception.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _pay(
    int ekubId,
    int period,
    String ekubName,
    double amount,
  ) async {
    final paymentKey = '$ekubId:$period';
    if (!payingPeriods.add(paymentKey)) return;
    setState(() {
      error = null;
    });
    try {
      final submitted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ManualPaymentPage(
            api: widget.api,
            ekubId: ekubId,
            period: period,
            ekubName: ekubName,
            amount: amount,
          ),
        ),
      );
      if (submitted == true) {
        await _load();
        if (mounted)
          _snack(context, 'Payment submitted for admin verification.');
      }
    } finally {
      payingPeriods.remove(paymentKey);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selectedGroup;
    for (final value in rows) {
      final group = _map(value);
      final ekub = _map(group['ekub']);
      if (_int(ekub['id']) == selectedEkubId) {
        selectedGroup = group;
        break;
      }
    }
    final selectedEkub = selectedGroup == null
        ? null
        : _map(selectedGroup['ekub']);
    var paidTotal = 0.0;
    var dueTotal = 0.0;
    var reviewTotal = 0.0;
    var duePeriods = 0;
    if (selectedGroup != null) {
      final group = selectedGroup;
      for (final value in group['periods'] as List? ?? const []) {
        final period = _map(value);
        paidTotal += _num(period['paid']);
        reviewTotal += _num(period['pending']);
        if (period['can_pay'] == true) {
          dueTotal += _num(period['available_to_pay']);
          duePeriods++;
        }
      }
    }

    Widget metric(String label, String value, Color tone, IconData icon) =>
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
            decoration: BoxDecoration(
              color: context.palette.panel,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: context.palette.border),
            ),
            child: Column(
              children: [
                Icon(icon, color: tone, size: 19),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.palette.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );

    Widget periodCard(Map<String, dynamic> ekub, dynamic value) {
      final period = _map(value);
      final ekubId = _int(ekub['id']);
      final periodNo = _int(period['period_no']);
      final paymentKey = '$ekubId:$periodNo';
      final isPaying = payingPeriods.contains(paymentKey);
      final label = _periodLabel(period);
      final tone = label == 'Paid'
          ? green
          : label == 'Pending review'
          ? const Color(0xFFE5A83B)
          : label == 'Due now'
          ? sky
          : context.palette.muted;
      final payments = period['payments'] as List? ?? const [];
      final winner = period['winner'] is Map ? _map(period['winner']) : null;

      return Container(
        margin: const EdgeInsets.only(top: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.palette.panel,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: context.palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tone.withAlpha(24),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    label == 'Paid'
                        ? Icons.check_circle_outline_rounded
                        : label == 'Pending review'
                        ? Icons.hourglass_top_rounded
                        : label == 'Due now'
                        ? Icons.schedule_rounded
                        : Icons.event_outlined,
                    color: tone,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Period ' + periodNo.toString(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withAlpha(24),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: tone,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PaymentAmount(
                  label: 'DUE',
                  value: _money(period['required']) + ' ETB',
                  color: sky,
                ),
                _PaymentAmount(
                  label: 'PAID',
                  value: _money(period['paid']) + ' ETB',
                  color: green,
                ),
                if (_num(period['pending']) > 0)
                  _PaymentAmount(
                    label: 'IN REVIEW',
                    value: _money(period['pending']) + ' ETB',
                    color: const Color(0xFFE5A83B),
                  ),
              ],
            ),
            ...payments.map((paymentValue) {
              final payment = _map(paymentValue);
              final transaction = (payment['transaction_no'] ?? '').toString();
              final paymentStatus = (payment['status'] ?? 'pending')
                  .toString()
                  .replaceAll('_', ' ');
              final paymentTone = paymentStatus == 'approved'
                  ? green
                  : paymentStatus == 'rejected'
                  ? const Color(0xFFE36B73)
                  : const Color(0xFFE5A83B);
              return Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.palette.track.withAlpha(75),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (payment['method'] ?? 'Payment').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          _money(payment['amount']) + ' ETB',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            paymentStatus[0].toUpperCase() +
                                paymentStatus.substring(1),
                            style: TextStyle(
                              color: paymentTone,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (payment['payment_currency'] == 'USDT' &&
                            payment['payment_currency_amount'] != null)
                          Text(
                            _paymentUsdt(payment['payment_currency_amount']) +
                                ' USDT',
                            style: TextStyle(
                              color: context.palette.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    if (transaction.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        'Transaction reference',
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SelectableText(
                        transaction,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (period['can_pay'] == true) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: ValueKey('payment-$ekubId-$periodNo'),
                  onPressed: isPaying
                      ? null
                      : () => _pay(
                          ekubId,
                          periodNo,
                          (ekub['name'] ?? 'Ekub').toString(),
                          _num(period['available_to_pay']),
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isPaying)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(Icons.wallet_rounded, size: 19),
                      const SizedBox(width: 9),
                      const Flexible(
                        child: Text(
                          'Choose payment method',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _money(period['available_to_pay']) + ' ETB',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (winner != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: green.withAlpha(20),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 18,
                      color: green,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Winner @' + (winner['username'] ?? '').toString(),
                        style: const TextStyle(
                          color: green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _money(winner['net_amount']) + ' ETB',
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget ekubCard(dynamic value) {
      final group = _map(value);
      final ekub = _map(group['ekub']);
      final periods = group['periods'] as List? ?? const [];
      final current = _int(ekub['current_period']);
      final duration = _int(ekub['duration']);
      final progress = duration <= 0
          ? 0.0
          : (current / duration).clamp(0.0, 1.0).toDouble();

      return Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.panel,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: context.palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(
                Theme.of(context).brightness == Brightness.dark ? 22 : 9,
              ),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [green.withAlpha(35), sky.withAlpha(35)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.savings_rounded,
                    color: green,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (ekub['name'] ?? 'Ekub').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (ekub['category'] ?? 'Ekub').toString() +
                            ' · ' +
                            (ekub['frequency'] ?? 'Flexible').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: sky.withAlpha(23),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    current.toString() + ' / ' + duration.toString(),
                    style: const TextStyle(
                      color: sky,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: context.palette.track,
                color: green,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'PERIOD PROGRESS',
              style: TextStyle(
                color: context.palette.muted,
                fontSize: 9,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            ...periods.map((period) => periodCard(ekub, period)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment status'),
        actions: [
          IconButton(
            tooltip: 'Refresh payments',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: green))
          : RefreshIndicator(
              onRefresh: _load,
              color: green,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (rows.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: DropdownButtonFormField<int>(
                          value: selectedEkubId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Choose an Ekub',
                            prefixIcon: Icon(Icons.savings_outlined),
                          ),
                          hint: const Text('Select an Ekub to view payments'),
                          items: rows.map((value) {
                            final group = _map(value);
                            final ekub = _map(group['ekub']);
                            return DropdownMenuItem<int>(
                              value: _int(ekub['id']),
                              child: Text(
                                (ekub['name'] ?? 'Ekub').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => selectedEkubId = value),
                        ),
                      ),
                    ),
                  if (rows.isNotEmpty && selectedEkub == null) ...[
                    const SizedBox(height: 12),
                    const _Empty(
                      text: 'Choose an Ekub above to view its payment status.',
                    ),
                  ],
                  if (selectedEkub != null)
                    Container(
                      padding: const EdgeInsets.all(19),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [green, sky],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: green.withAlpha(50),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(42),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: Colors.white,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 11),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'YOUR EKUB CONTRIBUTIONS',
                                      style: TextStyle(
                                        color: Color(0xEEFFFFFF),
                                        fontSize: 10,
                                        letterSpacing: 1.1,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Stay on track',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xDDFFFFFF),
                                size: 23,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(34),
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: Colors.white.withAlpha(48),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Due now',
                                        style: TextStyle(
                                          color: Color(0xEEFFFFFF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'Pay only the period shown below',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _money(dueTotal) + ' ETB',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            duePeriods == 1
                                ? '1 period is ready for payment'
                                : duePeriods.toString() +
                                      ' periods are ready for payment',
                            style: const TextStyle(
                              color: Color(0xEEFFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (selectedEkub != null) const SizedBox(height: 12),
                  if (selectedEkub != null)
                    Row(
                      children: [
                        metric(
                          'Paid',
                          _money(paidTotal),
                          green,
                          Icons.check_circle_outline_rounded,
                        ),
                        metric(
                          'In review',
                          _money(reviewTotal),
                          const Color(0xFFE5A83B),
                          Icons.hourglass_top_rounded,
                        ),
                        metric(
                          'Periods ready',
                          duePeriods.toString(),
                          sky,
                          Icons.event_available_outlined,
                        ),
                      ],
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 13),
                    _Message(text: error!, isError: true),
                  ],
                  if (selectedEkub != null) const SizedBox(height: 20),
                  if (selectedEkub != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${selectedEkub['name']} payment schedule',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${_int(selectedEkub['duration'])} periods',
                          style: TextStyle(
                            color: context.palette.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  if (selectedEkub != null) const SizedBox(height: 11),
                  if (rows.isEmpty)
                    const _Empty(
                      text: 'No active Ekubs to show payment status for.',
                    )
                  else if (selectedEkub != null)
                    ekubCard(selectedEkub),
                ],
              ),
            ),
    );
  }
}

class ManualPaymentPage extends StatefulWidget {
  const ManualPaymentPage({
    super.key,
    required this.api,
    required this.ekubId,
    required this.period,
    required this.ekubName,
    required this.amount,
  });
  final ApiClient api;
  final int ekubId, period;
  final String ekubName;
  final double amount;
  @override
  State<ManualPaymentPage> createState() => _ManualPaymentPageState();
}

class _ManualPaymentPageState extends State<ManualPaymentPage> {
  final transaction = TextEditingController();
  final picker = ImagePicker();
  List<Map<String, dynamic>> methods = [];
  Map<String, dynamic>? selected;
  XFile? receipt;
  bool loading = true, busy = false, accepted = false;
  bool checkingTransaction = false;
  bool? transactionAvailable;
  String? transactionCheckMessage;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    transaction.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await widget.api.get('/payments/methods');
      methods = (response['methods'] as List? ?? []).map(_map).toList();
      selected = null;
      for (final option in methods) {
        if (option['configured'] == true) {
          selected = option;
          break;
        }
      }
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not load the payment methods.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _pickReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final image = await picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2200,
      );
      if (image != null && mounted) setState(() => receipt = image);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not open the image picker.');
    }
  }

  Future<bool> _checkTransaction() async {
    if (transaction.text.trim().isEmpty) {
      setState(() {
        error = 'Enter the transaction ID.';
        transactionAvailable = null;
        transactionCheckMessage = null;
      });
      return false;
    }
    setState(() {
      checkingTransaction = true;
      transactionAvailable = null;
      transactionCheckMessage = null;
      error = null;
    });
    try {
      final response = await widget.api.post(
        '/payments/check-transaction',
        body: {'transaction_no': transaction.text.trim()},
      );
      final available = response['available'] == true;
      final message = (response['message'] ?? '').toString();
      if (mounted) {
        setState(() {
          transactionAvailable = available;
          transactionCheckMessage = message;
          if (!available) error = message;
        });
      }
      return available;
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Could not check this transaction ID. Try again.',
        );
    } finally {
      if (mounted) setState(() => checkingTransaction = false);
    }
    return false;
  }

  Future<void> _submit() async {
    if (selected?['configured'] != true) {
      setState(() => error = 'Choose a configured payment method.');
      return;
    }
    if (transaction.text.trim().isEmpty || receipt == null || !accepted) {
      setState(
        () => error = transaction.text.trim().isEmpty
            ? 'Enter the transaction ID.'
            : receipt == null
            ? 'Attach your transfer receipt.'
            : 'Confirm the transfer details.',
      );
      return;
    }
    if (!await _checkTransaction()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.postFiles(
        '/payments/${widget.ekubId}/${widget.period}',
        fields: {
          'amount': widget.amount.toStringAsFixed(2),
          'method': selected!['name'].toString(),
          'transaction_no': transaction.text.trim(),
          'terms_accepted': '1',
        },
        files: {'screenshot': receipt!.path},
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Could not submit payment. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final method = selected;
    final rate = _num(method?['etb_per_usdt']);
    final isUsdt = method?['currency'] == 'USDT';
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm payment')),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: const [
                            _PaymentStep(
                              number: '1',
                              label: 'Choose method',
                              active: true,
                            ),
                            Expanded(child: Divider(color: green)),
                            _PaymentStep(
                              number: '2',
                              label: 'Pay & confirm',
                              active: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(19),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [green, sky],
                            ),
                            borderRadius: BorderRadius.circular(21),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Amount to pay',
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                _money(widget.amount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 29,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${widget.ekubName} · Period ${widget.period}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Tap how you’ll pay',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: methods.map((option) {
                            final active = option['name'] == method?['name'];
                            final enabled = option['configured'] == true;
                            final name = option['name'].toString();
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: InkWell(
                                  onTap: enabled
                                      ? () => setState(() {
                                          selected = option;
                                          error = null;
                                        })
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    height: 100,
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: palette.panel,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: active ? green : palette.border,
                                        width: active ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          name == 'Telebirr'
                                              ? Icons
                                                    .account_balance_wallet_outlined
                                              : name == 'CBE'
                                              ? Icons.account_balance_outlined
                                              : Icons.currency_exchange_rounded,
                                          color: active ? green : palette.muted,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          name,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          enabled
                                              ? (option['currency'] == 'USDT'
                                                    ? 'USDT wallet'
                                                    : 'ETB transfer')
                                              : 'Not configured',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: palette.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (method != null)
                          Card(
                            margin: const EdgeInsets.only(top: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              method['name'].toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            if ((method['account_holder'] ?? '')
                                                .toString()
                                                .isNotEmpty)
                                              Text(
                                                'Account holder: ${method['account_holder']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: palette.muted,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: method['account'] == ''
                                            ? null
                                            : () async {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text: method['account']
                                                        .toString(),
                                                  ),
                                                );
                                                if (mounted)
                                                  _snack(
                                                    context,
                                                    'Account copied.',
                                                  );
                                              },
                                        icon: const Icon(Icons.copy_rounded),
                                      ),
                                    ],
                                  ),
                                  SelectableText(
                                    (method['account'] ??
                                            'Account not configured')
                                        .toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    isUsdt
                                        ? (rate > 0
                                              ? 'Send exactly ${(widget.amount / rate).toStringAsFixed(8)} USDT · 1 USDT = ${rate.toStringAsFixed(2)} ETB'
                                              : 'Binance rate is not configured.')
                                        : 'Transfer ${_money(widget.amount)} to this account. Admin will verify the receipt.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: palette.muted,
                                    ),
                                  ),
                                  if (isUsdt && rate > 0)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () async {
                                          await Clipboard.setData(
                                            ClipboardData(
                                              text: (widget.amount / rate)
                                                  .toStringAsFixed(8),
                                            ),
                                          );
                                          if (mounted)
                                            _snack(
                                              context,
                                              'USDT amount copied.',
                                            );
                                        },
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Copy exact USDT amount',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        Text(
                          'Confirm you paid',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: transaction,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) => setState(() {
                            transactionAvailable = null;
                            transactionCheckMessage = null;
                            error = null;
                          }),
                          decoration: const InputDecoration(
                            labelText: 'Transaction ID / reference',
                            prefixIcon: Icon(Icons.tag_rounded),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: busy || checkingTransaction
                                ? null
                                : _checkTransaction,
                            icon: checkingTransaction
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    transactionAvailable == true
                                        ? Icons.check_circle_outline
                                        : Icons.manage_search_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              checkingTransaction
                                  ? 'Checking…'
                                  : transactionAvailable == true
                                  ? 'ID is available'
                                  : 'Check transaction ID',
                            ),
                          ),
                        ),
                        if (transactionCheckMessage != null &&
                            transactionAvailable == true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              transactionCheckMessage!,
                              style: const TextStyle(
                                color: green,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(height: 9),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _pickReceipt,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: Text(
                            receipt?.name ?? 'Attach a receipt image',
                          ),
                        ),
                        CheckboxListTile(
                          value: accepted,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => accepted = v == true),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'I confirm I transferred this amount to the account shown. The payment stays pending until an administrator verifies the transaction ID and receipt.',
                            style: TextStyle(fontSize: 12, height: 1.3),
                          ),
                        ),
                        if (error != null)
                          _Message(text: error!, isError: true),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            busy ||
                                checkingTransaction ||
                                selected?['configured'] != true
                            ? null
                            : _submit,
                        icon: busy
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_user_outlined),
                        label: Text(
                          busy ? 'Submitting…' : 'Confirm my payment',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PaymentStep extends StatelessWidget {
  const _PaymentStep({
    required this.number,
    required this.label,
    required this.active,
  });
  final String number, label;
  final bool active;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 13,
        backgroundColor: active ? green : context.palette.track,
        foregroundColor: Colors.white,
        child: Text(
          number,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
      const SizedBox(width: 5),
    ],
  );
}

class ProfileView extends StatefulWidget {
  const ProfileView({
    super.key,
    required this.api,
    required this.user,
    required this.onSignOut,
    required this.isDark,
    required this.onToggleTheme,
  });
  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;
  final bool isDark;
  final Future<void> Function() onToggleTheme;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late Map<String, dynamic> profile;

  @override
  void initState() {
    super.initState();
    profile = widget.user;
  }

  Future<void> _refresh() async {
    try {
      profile = _map((await widget.api.get('/me'))['user']);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _open(BuildContext context, String feature) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileFeaturePage(
          api: widget.api,
          user: profile,
          feature: feature,
          onSignOut: widget.onSignOut,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String feature, {
    Color iconColor = green,
  }) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () {
        if (feature == 'appearance') {
          widget.onToggleTheme();
        } else {
          _open(context, feature);
        }
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(30),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.palette.muted, fontSize: 12),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: context.palette.muted,
        ),
      ),
    ),
  );

  Widget _tileGrid(BuildContext context, List<Widget> tiles) => Column(
    children: [
      for (var index = 0; index < tiles.length; index++)
        Padding(
          padding: EdgeInsets.only(bottom: index == tiles.length - 1 ? 0 : 8),
          child: tiles[index],
        ),
    ],
  );

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fullName =
        ((profile['first_name'] ?? '').toString() +
                ' ' +
                (profile['last_name'] ?? '').toString())
            .trim();
    final kyc = (profile['kyc_status'] ?? 'not_submitted').toString();
    final picture = profile['profile_picture_url']?.toString();
    final approved = kyc == 'approved';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Profile',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 13),
        Card(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.palette.profileStart, context.palette.panel],
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: green.withAlpha(130),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 39,
                        backgroundColor: context.palette.track,
                        backgroundImage: picture == null || picture.isEmpty
                            ? null
                            : NetworkImage(picture),
                        child: picture == null || picture.isEmpty
                            ? const Icon(
                                Icons.savings_rounded,
                                color: blue,
                                size: 36,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: 1,
                      child: Material(
                        color: green,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _open(context, 'profile_details'),
                          child: const SizedBox(
                            width: 27,
                            height: 27,
                            child: Icon(
                              Icons.camera_alt_outlined,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '@' + (profile['username'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.palette.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  (profile['phone'] ?? '').toString(),
                  style: TextStyle(color: context.palette.muted),
                ),
                if (profile['email'] != null)
                  Text(
                    profile['email'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.palette.muted),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: approved ? green.withAlpha(22) : const Color(0xFFFFEDF0),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _open(context, 'kyc'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    approved
                        ? Icons.verified_user_rounded
                        : Icons.gpp_maybe_outlined,
                    size: 30,
                    color: approved ? green : const Color(0xFFC84F63),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          approved
                              ? 'Identity verified'
                              : 'Identity unverified',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: approved ? green : const Color(0xFFC84F63),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          approved
                              ? 'Your identity has been approved.'
                              : 'Verify your identity to unlock full features.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  FilledButton(
                    onPressed: () => _open(context, 'kyc'),
                    style: FilledButton.styleFrom(
                      backgroundColor: approved
                          ? green
                          : const Color(0xFFD95368),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(76, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(approved ? 'View' : 'Verify'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _sectionTitle(context, 'Personal'),
        _tileGrid(context, [
          _tile(
            context,
            Icons.edit_outlined,
            'Edit profile',
            'Update your details and profile photo',
            'profile_details',
          ),
        ]),
        const SizedBox(height: 18),
        _sectionTitle(context, 'Account & payments'),
        _tileGrid(context, [
          _tile(
            context,
            Icons.account_balance_wallet_outlined,
            'Payment methods',
            'Manage payout accounts',
            'payment_methods',
          ),
          _tile(
            context,
            Icons.manage_accounts_outlined,
            'Account settings',
            'Password and account controls',
            'settings',
          ),
          _tile(
            context,
            Icons.phonelink_lock_outlined,
            'Two-step verification',
            'Email codes and authenticator app',
            'security',
            iconColor: blue,
          ),
          _tile(
            context,
            widget.isDark
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            'Appearance',
            (widget.isDark ? 'Dark' : 'Light') + ' theme · Tap to switch',
            'appearance',
            iconColor: blue,
          ),
          _tile(
            context,
            Icons.add_business_outlined,
            'Create an Ekub',
            'Apply and track your application',
            'applications',
          ),
          _tile(
            context,
            Icons.task_alt_outlined,
            'Finished Ekubs',
            'Completed groups and winners',
            'finished',
          ),
          _tile(
            context,
            Icons.groups_2_outlined,
            'Full Ekubs',
            'Groups filled to member capacity',
            'full_ekubs',
            iconColor: blue,
          ),
        ]),
        const SizedBox(height: 18),
        _sectionTitle(context, 'About & support'),
        _tileGrid(context, [
          _tile(
            context,
            Icons.info_outline,
            'About',
            'How Mekenet Ekub works',
            'about',
          ),
          _tile(
            context,
            Icons.privacy_tip_outlined,
            'Privacy policy',
            'Your information and choices',
            'privacy',
            iconColor: blue,
          ),
          _tile(
            context,
            Icons.gavel_outlined,
            'Terms of service',
            'Platform rules and fees',
            'terms',
          ),
          _tile(
            context,
            Icons.support_agent_outlined,
            'Contact support',
            'Get help with your account',
            'contact',
            iconColor: blue,
          ),
        ]),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => widget.onSignOut(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF8585),
            backgroundColor: const Color(0x1AE84B4B),
            side: const BorderSide(color: Color(0x668E3D3D)),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class ProfileFeaturePage extends StatefulWidget {
  const ProfileFeaturePage({
    super.key,
    required this.api,
    required this.user,
    required this.feature,
    required this.onSignOut,
  });
  final ApiClient api;
  final Map<String, dynamic> user;
  final String feature;
  final Future<void> Function() onSignOut;
  @override
  State<ProfileFeaturePage> createState() => _ProfileFeaturePageState();
}

class _ProfileFeaturePageState extends State<ProfileFeaturePage> {
  final form = GlobalKey<FormState>();
  final picker = ImagePicker();
  final fields = <String, TextEditingController>{};
  Map<String, dynamic> result = {};
  List<dynamic> rows = [];
  List<String> banks = [], categories = [], frequencies = [];
  String? bank,
      category,
      frequency,
      idType = 'National ID',
      gender = 'Male',
      reason = 'I no longer need the service';
  XFile? photo, front, back, video, profilePicture;
  bool livenessPassed = false;
  bool loading = true, busy = false, emailCodeSent = false;
  bool emailChangeCodeSent = false;
  String? emailChangeRequestedFor;
  String? secret;

  TextEditingController field(String key) =>
      fields.putIfAbsent(key, () => TextEditingController());
  @override
  void initState() {
    super.initState();
    field('full_name').text =
        ((widget.user['first_name'] ?? '').toString() +
                ' ' +
                (widget.user['last_name'] ?? '').toString())
            .trim();
    field('first_name').text = (widget.user['first_name'] ?? '').toString();
    field('last_name').text = (widget.user['last_name'] ?? '').toString();
    field('username').text = (widget.user['username'] ?? '').toString();
    field('phone').text = (widget.user['phone'] ?? '').toString();
    field('email').text = (widget.user['email'] ?? '').toString();
    field('duration').text = '12';
    _load();
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
    });
    try {
      switch (widget.feature) {
        case 'payment_methods':
          result = await widget.api.get('/profile/payment-methods');
          rows = result['data'] as List? ?? [];
          banks = (result['banks'] as List? ?? [])
              .map((e) => e.toString())
              .toList();
          if (bank == null && banks.isNotEmpty) bank = banks.first;
        case 'applications':
          result = await widget.api.get('/profile/applications');
          rows = result['data'] as List? ?? [];
          categories = (result['categories'] as List? ?? [])
              .map((e) => e.toString())
              .toList();
          frequencies = (result['frequencies'] as List? ?? [])
              .map((e) => e.toString())
              .toList();
          category ??= categories.isEmpty ? null : categories.first;
          frequency ??= frequencies.isEmpty ? null : frequencies.first;
        case 'finished':
          rows =
              (await widget.api.get('/profile/finished-ekubs'))['data']
                  as List? ??
              [];
        case 'full_ekubs':
          rows =
              (await widget.api.get('/profile/full-ekubs'))['data'] as List? ??
              [];
        case 'kyc':
          result = await widget.api.get('/profile/kyc');
          final verification = _map(result['verification']);
          if (verification.isNotEmpty) {
            field(
              'full_name',
            ).text = (verification['full_name'] ?? field('full_name').text)
                .toString();
            field('dob').text = (verification['dob'] ?? '').toString();
            field('id_number').text = (verification['id_number'] ?? '')
                .toString();
            gender = (verification['gender'] ?? gender).toString();
            idType = (verification['id_type'] ?? idType).toString();
          }
        case 'security':
          result = await widget.api.get('/profile/security');
      }
    } on ApiException catch (e) {
      result['error'] = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<bool> _post(
    String path,
    Map<String, dynamic> body, {
    bool reload = true,
  }) async {
    setState(() => busy = true);
    try {
      final response = await widget.api.post(path, body: body);
      if (mounted) _snack(context, response['message']?.toString() ?? 'Saved.');
      if (reload) await _load();
      return true;
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _paymentAdd() async {
    if (!form.currentState!.validate()) return;
    final saved = await _post('/profile/payment-methods', {
      'bank_name': bank,
      'account_name': field('account_name').text.trim(),
      'account_number': field('account_number').text.trim(),
    });
    if (saved) {
      field('account_name').clear();
      field('account_number').clear();
    }
  }

  Future<void> _deletePayment(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove payout account?'),
        content: const Text('This account will be removed from your profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => busy = true);
      try {
        await widget.api.delete('/profile/payment-methods/$id');
        await _load();
      } on ApiException catch (e) {
        if (mounted) _snack(context, e.message);
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
  }

  Future<void> _application() async {
    if (!form.currentState!.validate()) return;
    final sent = await _post('/profile/applications', {
      'name': field('name').text.trim(),
      'category': category,
      'frequency': frequency,
      'base_amount': double.tryParse(field('amount').text) ?? 0,
      'duration': int.tryParse(field('duration').text) ?? 0,
      'note': field('note').text.trim(),
    });
    if (sent) {
      field('name').clear();
      field('amount').clear();
      field('note').clear();
    }
  }

  Future<void> _pick(String key) async {
    if (key == 'liveness_video') {
      final passed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LivenessCapturePage()),
      );
      if (passed == true && mounted) setState(() => livenessPassed = true);
      return;
    }
    final isVideo = key == 'video';
    if (isVideo) {
      final recordedVideo = await Navigator.of(context).push<XFile?>(
        MaterialPageRoute(builder: (_) => const AgreementVideoCapturePage()),
      );
      if (recordedVideo != null && mounted) {
        setState(() => video = recordedVideo);
      }
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.palette.panel,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.image_outlined, color: green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Add identity image',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.photo_camera_outlined),
                ),
                title: const Text('Take a photo'),
                subtitle: const Text('Capture with your phone camera'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.photo_library_outlined),
                ),
                title: const Text('Choose an image'),
                subtitle: const Text('Pick an existing file from your phone'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    XFile? file;
    try {
      file = await picker.pickImage(source: source, imageQuality: 88);
    } on PlatformException catch (exception) {
      if (mounted)
        _snack(
          context,
          exception.message ?? 'Could not open the camera or photo library.',
        );
      return;
    }
    if (file == null || !mounted) return;
    setState(() {
      if (key == 'photo') photo = file;
      if (key == 'front') front = file;
      if (key == 'back') back = file;
      if (key == 'video') video = file;
      if (key == 'profile_picture') profilePicture = file;
    });
  }

  Future<void> _saveProfile() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final newEmail = field('email').text.trim();
      final oldEmail = (widget.user['email'] ?? '').toString().trim();
      Map<String, dynamic>? response;
      if (newEmail.toLowerCase() != oldEmail.toLowerCase()) {
        if (emailChangeRequestedFor?.toLowerCase() != newEmail.toLowerCase()) {
          response = await widget.api.post(
            '/profile/email/send-code',
            body: {'email': newEmail},
          );
          if (mounted) {
            setState(() {
              emailChangeCodeSent = true;
              emailChangeRequestedFor = newEmail;
            });
            _snack(
              context,
              response['message']?.toString() ??
                  'A verification code was sent to the new email.',
            );
          }
          return;
        }
        response = await widget.api.post(
          '/profile/email/verify',
          body: {
            'email': newEmail,
            'code': field('email_change_code').text.trim(),
          },
        );
        if (mounted) {
          widget.user['email'] = newEmail;
          widget.user['email_verified_at'] = DateTime.now().toIso8601String();
          _snack(context, response['message']?.toString() ?? 'Email verified.');
        }
      }
      final locked = widget.user['kyc_status'] == 'approved';
      if (!locked) {
        response = await widget.api.post(
          '/profile',
          body: {
            'first_name': field('first_name').text.trim(),
            'last_name': field('last_name').text.trim(),
            'username': field('username').text.trim(),
            'phone': field('phone').text.trim(),
          },
        );
      }
      if (mounted) {
        _snack(context, response?['message']?.toString() ?? 'Profile updated.');
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _saveProfilePicture() async {
    if (profilePicture == null) {
      _snack(context, 'Choose a profile picture first.');
      return;
    }
    setState(() => busy = true);
    try {
      final response = await widget.api.postFiles(
        '/profile/picture',
        fields: const {},
        files: {'profile_picture': profilePicture!.path},
      );
      if (mounted) {
        _snack(
          context,
          response['message']?.toString() ?? 'Profile picture updated.',
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submitKyc() async {
    if (!form.currentState!.validate()) return;
    if (photo == null ||
        front == null ||
        (idType == 'National ID' && back == null) ||
        !livenessPassed ||
        video == null) {
      _snack(
        context,
        'Pass the live face check and add the agreement video and required ID documents.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      final r = await widget.api.postFiles(
        '/profile/kyc',
        fields: {
          'full_name': field('full_name').text.trim(),
          'dob': field('dob').text.trim(),
          'gender': gender!,
          'id_type': idType!,
          'id_number': field('id_number').text.trim(),
          'liveness_verified': '1',
        },
        files: {
          'personal_photo': photo!.path,
          'id_front': front!.path,
          if (idType == 'National ID') 'id_back': back!.path,
          'video_agreement': video!.path,
        },
      );
      if (mounted)
        _snack(context, r['message']?.toString() ?? 'Submitted for review.');
      result['status'] = 'pending';
      setState(() {
        photo = null;
        front = null;
        back = null;
        livenessPassed = false;
        video = null;
      });
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _security(String action, [Map<String, dynamic>? body]) async {
    setState(() => busy = true);
    try {
      final r = await widget.api.post('/profile/security/$action', body: body);
      if (mounted) _snack(context, r['message']?.toString() ?? 'Updated.');
      if (action == 'start-authenticator') {
        secret = r['secret']?.toString();
        await Clipboard.setData(ClipboardData(text: secret ?? ''));
      }
      if (action == 'send-email-code') emailCodeSent = true;
      if (action == 'verify-email' ||
          action == 'verify-authenticator' ||
          action == 'disable') {
        secret = null;
        emailCodeSent = false;
        field('code').clear();
        result = await widget.api.get('/profile/security');
      }
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (field('delete_password').text.isEmpty) {
      _snack(context, 'Enter your password to confirm account deletion.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This cannot be undone. You cannot delete while you are in a running Ekub.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await widget.api.post(
        '/profile/account/delete',
        body: {
          'password': field('delete_password').text,
          'reason': reason,
          'details': field('delete_details').text,
        },
      );
      await widget.onSignOut();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _fileTile(
    BuildContext context,
    String title,
    XFile? file,
    String key,
  ) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: busy ? null : () => _pick(key),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (file == null ? green : blue).withAlpha(28),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                file != null
                    ? Icons.check_circle_outline
                    : key == 'video' || key == 'liveness_video'
                    ? Icons.videocam_outlined
                    : Icons.image_outlined,
                color: file != null ? green : blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    file?.name ??
                        (key == 'liveness_video'
                            ? 'Open the live in-app camera check'
                            : key == 'video'
                            ? 'Upload or record the consent phrase'
                            : 'Take a photo or choose an image'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              file == null ? Icons.add_circle_outline : Icons.edit_outlined,
              color: green,
            ),
          ],
        ),
      ),
    ),
  );
  Widget _errorOrEmpty(String message) =>
      Center(child: _Message(text: message, isError: true));

  Widget _body(BuildContext context) {
    if (result['error'] != null)
      return _errorOrEmpty(result['error'].toString());
    switch (widget.feature) {
      case 'profile_details':
        final locked = widget.user['kyc_status'] == 'approved';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (locked)
              Card(
                color: sky.withAlpha(18),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user_outlined, color: sky),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your personal information is locked after identity verification. You can still update your profile picture.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_outline_rounded, color: green),
                          SizedBox(width: 9),
                          Text(
                            'Personal details',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: field('first_name'),
                        readOnly: locked,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your first name.'
                            : null,
                      ),
                      const SizedBox(height: 11),
                      TextFormField(
                        controller: field('last_name'),
                        readOnly: locked,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your last name.'
                            : null,
                      ),
                      const SizedBox(height: 11),
                      TextFormField(
                        controller: field('username'),
                        readOnly: locked,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                        ),
                        validator: (v) =>
                            (v == null ||
                                !RegExp(
                                  r'^[A-Za-z0-9_.]{3,30}$',
                                ).hasMatch(v.trim()))
                            ? 'Use 3–30 letters, numbers, dots, or underscores.'
                            : null,
                      ),
                      const SizedBox(height: 11),
                      TextFormField(
                        controller: field('phone'),
                        readOnly: locked,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                        ),
                        validator: (v) =>
                            (v == null ||
                                v.replaceAll(RegExp(r'\D'), '').length < 9)
                            ? 'Enter a valid Ethiopian phone number.'
                            : null,
                      ),
                      const SizedBox(height: 11),
                      TextFormField(
                        controller: field('email'),
                        readOnly: false,
                        onChanged: (value) {
                          if (emailChangeRequestedFor?.toLowerCase() !=
                              value.trim().toLowerCase()) {
                            field('email_change_code').clear();
                          }
                          setState(() {});
                        },
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                        ),
                        validator: (v) =>
                            v == null ||
                                !RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(v.trim())
                            ? 'Enter a valid email address.'
                            : null,
                      ),
                      if (field('email').text.trim().toLowerCase() !=
                          (widget.user['email'] ?? '')
                              .toString()
                              .trim()
                              .toLowerCase()) ...[
                        const SizedBox(height: 8),
                        Text(
                          emailChangeCodeSent &&
                                  emailChangeRequestedFor?.toLowerCase() ==
                                      field('email').text.trim().toLowerCase()
                              ? 'Enter the verification code sent to the new address.'
                              : 'Changing your email requires a code sent to the new address.',
                          style: TextStyle(color: context.palette.muted),
                        ),
                        if (emailChangeCodeSent &&
                            emailChangeRequestedFor?.toLowerCase() ==
                                field('email').text.trim().toLowerCase()) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: field('email_change_code'),
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'Email verification code',
                              prefixIcon: Icon(Icons.mark_email_read_outlined),
                            ),
                          ),
                        ],
                      ],
                      if (!locked ||
                          field('email').text.trim().toLowerCase() !=
                              (widget.user['email'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase()) ...[
                        const SizedBox(height: 13),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: busy ? null : _saveProfile,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              emailChangeCodeSent &&
                                      emailChangeRequestedFor?.toLowerCase() ==
                                          field(
                                            'email',
                                          ).text.trim().toLowerCase()
                                  ? 'Verify and save profile'
                                  : 'Save profile',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Text(
                'Profile picture',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 5),
            _fileTile(
              context,
              'Profile picture',
              profilePicture,
              'profile_picture',
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : _saveProfilePicture,
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Update profile picture'),
              ),
            ),
          ],
        );
      case 'payment_methods':
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: sky.withAlpha(18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: sky.withAlpha(50)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: sky),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Manage the bank or wallet accounts used for receiving payouts. Account numbers are masked after saving.',
                      style: TextStyle(
                        color: context.palette.muted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Saved payout accounts',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              ...rows.map((e) {
                final r = _map(e);
                final id = _int(r['id']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 3,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: green.withAlpha(25),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.account_balance_outlined,
                        color: green,
                      ),
                    ),
                    title: Text(
                      (r['bank_name'] ?? 'Bank or wallet').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${(r['account_name'] ?? '').toString()} · ${(r['account_number'] ?? '').toString()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'remove') {
                          _deletePayment(id);
                        } else {
                          _post('/profile/payment-methods/$id/default', {});
                        }
                      },
                      itemBuilder: (_) => [
                        if (r['is_default'] != true)
                          const PopupMenuItem(
                            value: 'default',
                            child: Text('Make default'),
                          ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.add_card_outlined, color: green),
                          SizedBox(width: 9),
                          Text(
                            'Add payout account',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Your account information is kept private.',
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: bank,
                        decoration: const InputDecoration(
                          labelText: 'Bank or wallet',
                        ),
                        items: banks
                            .map(
                              (b) => DropdownMenuItem(
                                value: b,
                                child: Text(
                                  b,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => bank = v),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: field('account_number'),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Account number',
                          prefixIcon: Icon(Icons.numbers_rounded),
                        ),
                        validator: (v) =>
                            (v == null ||
                                v.replaceAll(RegExp(r'\D'), '').length < 6)
                            ? 'Enter at least six digits.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: field('account_name'),
                        decoration: const InputDecoration(
                          labelText: 'Account holder name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().length < 3)
                            ? 'Enter the account holder name.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: busy ? null : _paymentAdd,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      case 'applications':
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [green, blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start a new Ekub',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Send your plan to an administrator for review.',
                          style: TextStyle(
                            color: Colors.white.withAlpha(225),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, color: green),
                        const SizedBox(width: 8),
                        const Text(
                          'Ekub details',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Form(
                      key: form,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: field('name'),
                            decoration: const InputDecoration(
                              labelText: 'Ekub name',
                              prefixIcon: Icon(Icons.savings_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter a name.'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: categories
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                      v,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => category = v),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: frequency,
                            decoration: const InputDecoration(
                              labelText: 'Payment frequency',
                              prefixIcon: Icon(Icons.event_repeat_outlined),
                            ),
                            items: frequencies
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                      v,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => frequency = v),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: field('amount'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Contribution per period (ETB)',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                            validator: (v) =>
                                (double.tryParse(v ?? '') ?? 0) <= 0
                                ? 'Enter an amount.'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: field('duration'),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Number of periods',
                              prefixIcon: Icon(
                                Icons.format_list_numbered_rounded,
                              ),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 2 || n > 500
                                  ? 'Enter 2 to 500 periods.'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: field('note'),
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Note (optional)',
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                          ),
                          const SizedBox(height: 13),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: busy ? null : _application,
                              icon: const Icon(Icons.send_rounded),
                              label: Text(
                                busy ? 'Sending…' : 'Send application',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.assignment_outlined, color: green),
                const SizedBox(width: 8),
                const Text(
                  'Your applications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (rows.isEmpty)
              const _Empty(
                text:
                    'No applications submitted yet. Your requests will appear here.',
              ),
            ...rows.map((e) {
              final r = _map(e);
              final status = (r['status'] ?? 'pending').toString();
              final statusColor = status == 'approved'
                  ? green
                  : status == 'rejected'
                  ? const Color(0xFFD95368)
                  : const Color(0xFFE5A83B);
              return Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (r['name'] ?? 'Ekub application').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${(r['category'] ?? 'Category').toString()} · ${(r['frequency'] ?? 'Frequency').toString()}',
                        style: TextStyle(color: context.palette.muted),
                      ),
                      if (r['base_amount'] != null ||
                          r['duration'] != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          '${_money(r['base_amount'])} per period · ${(r['duration'] ?? '—').toString()} periods',
                          style: TextStyle(
                            color: context.palette.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if ((r['rejection_reason'] ?? '')
                          .toString()
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _Message(
                          text: r['rejection_reason'].toString(),
                          isError: true,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      case 'full_ekubs':
        final darkTheme = Theme.of(context).brightness == Brightness.dark;
        return rows.isEmpty
            ? const Center(child: _Empty(text: 'No full Ekubs yet.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: rows.map((e) {
                  final r = _map(e);
                  final status = (r['status'] ?? 'active').toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            green.withAlpha(darkTheme ? 30 : 17),
                            sky.withAlpha(darkTheme ? 24 : 14),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: green.withAlpha(28),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.savings_outlined,
                                    color: green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (r['name'] ?? 'Ekub').toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${(r['category'] ?? 'Category').toString()} · ${(r['frequency'] ?? 'Frequency').toString()}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: context.palette.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: green.withAlpha(27),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: const Text(
                                    'FULL',
                                    style: TextStyle(
                                      color: green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Wrap(
                              spacing: 18,
                              runSpacing: 10,
                              children: [
                                _FeatureValue(
                                  icon: Icons.payments_outlined,
                                  label: 'Contribution',
                                  value: '${_money(r['base_amount'])} ETB',
                                ),
                                _FeatureValue(
                                  icon: Icons.people_outline_rounded,
                                  label: 'Members',
                                  value: (r['member_count'] ?? '—').toString(),
                                ),
                                _FeatureValue(
                                  icon: Icons.repeat_rounded,
                                  label: 'Periods',
                                  value: (r['duration'] ?? '—').toString(),
                                ),
                                _FeatureValue(
                                  icon: Icons.play_circle_outline_rounded,
                                  label: 'Group status',
                                  value: status.isEmpty
                                      ? 'Active'
                                      : status[0].toUpperCase() +
                                            status.substring(1),
                                ),
                                if (_int(r['current_period']) > 0)
                                  _FeatureValue(
                                    icon: Icons.calendar_month_outlined,
                                    label: 'Current period',
                                    value: (r['current_period']).toString(),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: 1,
                                minHeight: 7,
                                color: green,
                                backgroundColor: context.palette.border,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Member capacity reached',
                              style: TextStyle(
                                color: context.palette.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
      case 'finished':
        return rows.isEmpty
            ? const Center(child: _Empty(text: 'No finished Ekubs yet.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: rows.map((e) {
                  final r = _map(e);
                  final winners = r['winners'] as List? ?? [];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (r['name'] ?? '').toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            (r['category'] ?? '').toString() +
                                ' · ' +
                                (r['frequency'] ?? '').toString(),
                            style: TextStyle(color: context.palette.muted),
                          ),
                          Text(
                            _money(r['base_amount']) +
                                ' ETB · ' +
                                (r['duration'] ?? '').toString() +
                                ' periods · ' +
                                (r['member_count'] ?? '').toString() +
                                ' members',
                            style: TextStyle(color: context.palette.muted),
                          ),
                          ...winners.map((w) {
                            final win = _map(w);
                            return Text(
                              'Period ' +
                                  (win['period_no'] ?? '').toString() +
                                  ': @' +
                                  (win['username'] ?? '').toString() +
                                  ' · ' +
                                  _money(win['net_amount']) +
                                  ' ETB',
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
      case 'kyc':
        final status = (result['status'] ?? 'not_submitted').toString();
        final verification = _map(result['verification']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: status == 'approved'
                  ? green.withAlpha(18)
                  : sky.withAlpha(18),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (status == 'approved' ? green : sky).withAlpha(
                          27,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        status == 'approved'
                            ? Icons.verified_user_outlined
                            : Icons.fact_check_outlined,
                        color: status == 'approved' ? green : sky,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Identity ${status.replaceAll('_', ' ')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (verification['rejection_reason'] ??
                                    (status == 'approved'
                                        ? 'Your identity has been verified.'
                                        : 'Submit your details and documents for review.'))
                                .toString(),
                            style: TextStyle(
                              color: context.palette.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (status != 'approved') ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.badge_outlined, color: green),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Identity information',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Use the details shown on your valid identity document.',
                          style: TextStyle(
                            color: context.palette.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: field('full_name'),
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full legal name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter your name.'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: field('dob'),
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'Date of birth (YYYY-MM-DD)',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter your date of birth.'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: gender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                          ),
                          items: const ['Male', 'Female', 'Other']
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => gender = v ?? gender),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: idType,
                          decoration: const InputDecoration(
                            labelText: 'ID type',
                          ),
                          items: const ['National ID', 'Passport']
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => idType = v ?? idType),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: field('id_number'),
                          decoration: const InputDecoration(
                            labelText: 'ID number',
                            prefixIcon: Icon(Icons.numbers_rounded),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter your ID number.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Required documents',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _fileTile(context, 'Personal photo', photo, 'photo'),
                        _fileTile(
                          context,
                          idType == 'Passport'
                              ? 'Passport image'
                              : 'ID front image',
                          front,
                          'front',
                        ),
                        if (idType == 'National ID')
                          _fileTile(context, 'ID back image', back, 'back'),
                        Card(
                          child: ListTile(
                            leading: Icon(
                              livenessPassed
                                  ? Icons.verified_user_rounded
                                  : Icons.face_retouching_natural_rounded,
                              color: livenessPassed ? green : sky,
                            ),
                            title: const Text('Live face check'),
                            subtitle: Text(
                              livenessPassed
                                  ? 'Passed on this device. No video saved.'
                                  : 'Blink, turn your head, then follow the circle.',
                            ),
                            trailing: FilledButton.tonal(
                              onPressed: busy
                                  ? null
                                  : () => _pick('liveness_video'),
                              child: Text(livenessPassed ? 'Repeat' : 'Start'),
                            ),
                          ),
                        ),
                        _fileTile(
                          context,
                          'Agreement video — English or Amharic',
                          video,
                          'video',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Text(
                            'The live camera check runs in this app and verifies each step before continuing. Then add a separate agreement video saying “I Agree by Mekenet Ekub Rules.” or “በመቀነት እቁበ ህግ እና ደንብ ተስማምቻልው፡፡” Only the agreement video and ID documents are uploaded.',
                            style: TextStyle(
                              color: context.palette.muted,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: busy ? null : _submitKyc,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: Text(
                              busy ? 'Submitting…' : 'Submit for review',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      case 'settings':
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: green.withAlpha(30),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${(widget.user['username'] ?? '').toString()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(widget.user['phone'] ?? '').toString()} · ${(widget.user['email'] ?? 'No email').toString()}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.palette.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 13),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_reset_rounded, color: green),
                        const SizedBox(width: 8),
                        const Text(
                          'Change password',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Use at least 8 characters, with an uppercase letter, a number, and a symbol.',
                      style: TextStyle(
                        color: context.palette.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Form(
                      key: form,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: field('current_password'),
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Current password',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter your current password.'
                                : null,
                          ),
                          const SizedBox(height: 9),
                          TextFormField(
                            controller: field('new_password'),
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'New password',
                              prefixIcon: Icon(Icons.password_rounded),
                            ),
                            validator: (v) =>
                                (v == null ||
                                    v.length < 8 ||
                                    !RegExp(r'[A-Z]').hasMatch(v) ||
                                    !RegExp(r'\d').hasMatch(v) ||
                                    !RegExp(r'[^A-Za-z0-9]').hasMatch(v))
                                ? 'Use 8+ characters with an uppercase letter, a number, and a symbol.'
                                : null,
                          ),
                          const SizedBox(height: 9),
                          TextFormField(
                            controller: field('new_password_confirmation'),
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm new password',
                              prefixIcon: Icon(
                                Icons.check_circle_outline_rounded,
                              ),
                            ),
                            validator: (v) => v != field('new_password').text
                                ? 'Passwords do not match.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (form.currentState!.validate()) {
                                        final changed = await _post(
                                          '/profile/password',
                                          {
                                            'current_password': field(
                                              'current_password',
                                            ).text,
                                            'new_password': field(
                                              'new_password',
                                            ).text,
                                            'new_password_confirmation': field(
                                              'new_password_confirmation',
                                            ).text,
                                          },
                                          reload: false,
                                        );
                                        if (changed) {
                                          field('current_password').clear();
                                          field('new_password').clear();
                                          field(
                                            'new_password_confirmation',
                                          ).clear();
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Update password'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 13),
            Card(
              color: const Color(0x1AD95368),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFD95368),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Delete account',
                          style: TextStyle(
                            fontSize: 17,
                            color: Color(0xFFD95368),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'You cannot delete your account while part of a running Ekub. This action cannot be undone.',
                      style: TextStyle(
                        color: context.palette.muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 11),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: reason,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        prefixIcon: Icon(Icons.info_outline_rounded),
                      ),
                      items:
                          const [
                                'I no longer need the service',
                                'I have privacy concerns',
                                'I created a second account',
                                'I am not satisfied with the service',
                                'I had a problem with a payment',
                                'Other',
                              ]
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(
                                    v,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => reason = v),
                    ),
                    if (reason == 'Other') ...[
                      const SizedBox(height: 9),
                      TextField(
                        controller: field('delete_details'),
                        decoration: const InputDecoration(
                          labelText: 'Tell us more',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    TextField(
                      controller: field('delete_password'),
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm with your password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 11),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _deleteAccount,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete my account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD95368),
                        side: const BorderSide(color: Color(0x80D95368)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case 'security':
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: result['enabled'] == true
                  ? green.withAlpha(18)
                  : sky.withAlpha(18),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (result['enabled'] == true ? green : sky)
                            .withAlpha(28),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        result['enabled'] == true
                            ? Icons.verified_user_outlined
                            : Icons.shield_outlined,
                        color: result['enabled'] == true ? green : sky,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result['enabled'] == true
                                ? 'Protection enabled'
                                : 'Protection is off',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Email: ${(result['email_hint'] ?? 'not available').toString()}',
                            style: TextStyle(color: context.palette.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.mark_email_read_outlined, color: green),
                        SizedBox(width: 9),
                        Text(
                          'Email one-time code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Add an extra check when you sign in.',
                      style: TextStyle(
                        color: context.palette.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (emailCodeSent) ...[
                      const SizedBox(height: 11),
                      TextField(
                        controller: field('code'),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Six-digit email code',
                          prefixIcon: Icon(Icons.password_rounded),
                        ),
                      ),
                    ],
                    const SizedBox(height: 11),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : emailCodeSent
                            ? () => _security('verify-email', {
                                'code': field('code').text.trim(),
                              })
                            : () => _security('send-email-code'),
                        icon: Icon(
                          emailCodeSent
                              ? Icons.verified_outlined
                              : Icons.send_outlined,
                        ),
                        label: Text(
                          emailCodeSent
                              ? 'Verify and enable email OTP'
                              : 'Send email code',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.phonelink_lock_outlined, color: sky),
                        SizedBox(width: 9),
                        Text(
                          'Authenticator app',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Use Google Authenticator, Microsoft Authenticator, or another TOTP app.',
                      style: TextStyle(
                        color: context.palette.muted,
                        height: 1.35,
                        fontSize: 12,
                      ),
                    ),
                    if (secret != null) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Secret copied. Add this key manually in your authenticator app.',
                      ),
                      const SizedBox(height: 5),
                      SelectableText(
                        secret!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: field('code'),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Authenticator code',
                          prefixIcon: Icon(Icons.password_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: busy
                              ? null
                              : () => _security('verify-authenticator', {
                                  'code': field('code').text.trim(),
                                }),
                          child: const Text('Verify authenticator'),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 11),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: busy
                              ? null
                              : () => _security('start-authenticator'),
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('Set up authenticator'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (result['enabled'] == true) ...[
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final p = TextEditingController();
                            final value = await showDialog<String>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text(
                                  'Turn off two-step verification?',
                                ),
                                content: TextField(
                                  controller: p,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(c, p.text),
                                    child: const Text('Turn off'),
                                  ),
                                ],
                              ),
                            );
                            p.dispose();
                            if (value != null && value.isNotEmpty)
                              await _security('disable', {'password': value});
                          },
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('Turn off two-step verification'),
                  ),
                ),
              ),
            ],
          ],
        );
      default:
        return _infoBody(context);
    }
  }

  Widget _infoBody(BuildContext context) {
    final data = switch (widget.feature) {
      'about' => const [
        (
          'Saving together. Growing together.',
          'Mekenet Ekub brings the familiar tradition of እቁብ into an organized digital experience, helping members explore groups and follow their participation.',
        ),
        (
          'How it works',
          'Review each group’s category, schedule, contribution, duration and capacity. KYC approval is required before joining.',
        ),
        (
          'Payout fee',
          'The stated service fee is 2% of the collected pool. The winner receives 98%, subject to the group rules.',
        ),
      ],
      'privacy' => const [
        (
          'Information collected',
          'Your account details, identity documents, payment records and saved payout accounts.',
        ),
        (
          'How it is used',
          'To verify identity, manage Ekub groups, confirm contributions, send reminders and security codes, pay winners and prevent abuse.',
        ),
        (
          'Who can see it',
          'Authorised administrators and partners with matching permissions can review identity and payment information. Members cannot see other members’ documents or bank details.',
        ),
        (
          'Retention and deletion',
          'You may request account deletion when you are not part of a running Ekub. Some accounting records may be retained as described in the site policy.',
        ),
      ],
      'terms' => const [
        (
          'Service fee',
          'A 2% fee is deducted from the approved gross pool when a member wins a period. The winner receives 98%.',
        ),
        (
          'Late payment',
          'Late payments may receive a penalty according to the Ekub configuration.',
        ),
        (
          'Verification',
          'KYC approval is required before joining active Ekubs. Check the contribution schedule before joining.',
        ),
      ],
      _ => const [
        ('Call support', '+251 951 180 317'),
        ('Email', 'mekenetsupport@gmail.com'),
        (
          'Working hours',
          'Monday to Saturday, 12:00 AM–4:00 PM. Sunday closed.',
        ),
        (
          'Account safety',
          'Support will never ask for your password or authenticator code.',
        ),
      ],
    };
    final title = switch (widget.feature) {
      'about' => 'About Mekenet Ekub',
      'privacy' => 'Privacy policy',
      'terms' => 'Terms of service',
      _ => 'Contact support',
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.feature == 'about')
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [green, blue]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Build your future together.',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        ...data.map(
          (entry) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.$1,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    entry.$2,
                    style: TextStyle(color: context.palette.muted, height: 1.4),
                  ),
                  if (widget.feature == 'contact' &&
                      (entry.$1 == 'Call support' || entry.$1 == 'Email'))
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: entry.$2),
                          );
                          if (context.mounted)
                            _snack(context, 'Copied to clipboard.');
                        },
                        icon: const Icon(Icons.copy, color: green),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (widget.feature == 'contact')
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Follow Mekenet Ekub',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Find our official channels and community updates.',
                    style: TextStyle(color: context.palette.muted),
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 15,
                    runSpacing: 13,
                    children: const [
                      _SocialButton(
                        name: 'TikTok',
                        url: 'https://www.tiktok.com/@mekenetekub',
                        color: Color(0xFF111111),
                      ),
                      _SocialButton(
                        name: 'YouTube',
                        url:
                            'https://www.youtube.com/channel/UCTNqC2Atij-_omNMBoUMVbQ',
                        color: Color(0xFFE62117),
                      ),
                      _SocialButton(
                        name: 'Facebook',
                        url:
                            'https://web.facebook.com/profile.php?id=61595090707504',
                        color: Color(0xFF1877F2),
                      ),
                      _SocialButton(
                        name: 'Telegram',
                        url: 'https://t.me/mekenet_ekub',
                        color: Color(0xFF229ED9),
                      ),
                      _SocialButton(
                        name: 'X',
                        url: 'https://x.com/MekenetEkud',
                        color: Color(0xFF111111),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = {
      'profile_details': 'Edit profile',
      'kyc': 'Identity verification',
      'payment_methods': 'Payment methods',
      'settings': 'Account settings',
      'security': 'Two-step verification',
      'applications': 'Ekub applications',
      'finished': 'Finished Ekubs',
      'full_ekubs': 'Full Ekubs',
      'about': 'About',
      'privacy': 'Privacy policy',
      'terms': 'Terms of service',
      'contact': 'Contact support',
    };
    return Scaffold(
      appBar: AppBar(title: Text(titles[widget.feature] ?? 'Profile')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _body(context),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.name,
    required this.url,
    required this.color,
  });
  final String name, url;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 66,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!opened && context.mounted)
          _snack(context, 'Could not open $name.');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withAlpha(22),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(28, 28),
                  painter: _SocialLogoPainter(name: name, color: color),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SocialLogoPainter extends CustomPainter {
  const _SocialLogoPainter({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 28;
    canvas.save();
    canvas.scale(scale, scale);
    final mark = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (name.toLowerCase()) {
      case 'telegram':
        canvas.drawCircle(const Offset(14, 14), 13, mark);
        canvas.drawPath(
          Path()
            ..moveTo(5, 13.3)
            ..lineTo(21.7, 6.9)
            ..quadraticBezierTo(23, 6.4, 22.5, 8)
            ..lineTo(19.7, 21)
            ..quadraticBezierTo(19.4, 22.3, 18.2, 21.6)
            ..lineTo(13.8, 18.3)
            ..lineTo(11.4, 20.6)
            ..lineTo(11.7, 16.7)
            ..lineTo(19.1, 10.1)
            ..lineTo(9.6, 15.8)
            ..lineTo(5.3, 14.3)
            ..quadraticBezierTo(4.2, 13.9, 5, 13.3)
            ..close(),
          white,
        );
        break;
      case 'youtube':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(1.5, 5.5, 25, 17),
            const Radius.circular(5),
          ),
          mark,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 9.4)
            ..lineTo(19, 14)
            ..lineTo(12, 18.6)
            ..close(),
          white,
        );
        break;
      case 'facebook':
        final painter = TextPainter(
          text: const TextSpan(
            text: 'f',
            style: TextStyle(
              color: Color(0xFF1877F2),
              fontSize: 29,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, const Offset(9.5, 0));
        break;
      case 'x':
        final stroke = Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.square;
        canvas.drawLine(const Offset(5, 4), const Offset(23, 24), stroke);
        canvas.drawLine(const Offset(22, 4), const Offset(6, 24), stroke);
        break;
      default: // TikTok's layered music note mark.
        void note(Paint paint, Offset offset) {
          canvas.drawLine(
            Offset(16 + offset.dx, 4 + offset.dy),
            Offset(16 + offset.dx, 18 + offset.dy),
            Paint()
              ..color = paint.color
              ..strokeWidth = 4.2
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            Offset(16 + offset.dx, 5 + offset.dy),
            Offset(22 + offset.dx, 7 + offset.dy),
            Paint()
              ..color = paint.color
              ..strokeWidth = 4.2
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawCircle(Offset(10 + offset.dx, 20 + offset.dy), 4, paint);
        }
        note(Paint()..color = const Color(0xFF25F4EE), const Offset(-1.4, 0.8));
        note(Paint()..color = const Color(0xFFFE2C55), const Offset(1.4, -0.6));
        note(white, Offset.zero);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SocialLogoPainter oldDelegate) =>
      oldDelegate.name != name || oldDelegate.color != color;
}

Future<bool> _joinEkub(
  BuildContext context,
  ApiClient api,
  Map<String, dynamic> item,
) async {
  final options = item['is_item'] == true
      ? ['full']
      : ['full', 'half', 'quarter'];
  final share = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.palette.panel,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Choose your share for ' +
                  (item['name'] ?? 'this Ekub').toString(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          ...options.map(
            (value) => ListTile(
              leading: const Icon(Icons.check_circle_outline, color: green),
              title: Text(value.toUpperCase() + ' share'),
              subtitle: Text(
                value == 'full'
                    ? 'Full contribution'
                    : value == 'half'
                    ? 'Half contribution'
                    : 'Quarter contribution',
              ),
              onTap: () => Navigator.pop(context, value),
            ),
          ),
        ],
      ),
    ),
  );
  if (share == null || !context.mounted) return false;
  try {
    await api.post(
      '/ekubs/' + _int(item['id']).toString() + '/join',
      body: {'share_type': share},
    );
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: green.withAlpha(28),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: green,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'You’re in!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text(
                  'You joined ${(item['name'] ?? 'this Ekub').toString()} with a ${share.toUpperCase()} share.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.muted, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return true;
  } on ApiException catch (exception) {
    if (context.mounted) _snack(context, exception.message);
    return false;
  }
}

class _EkubCard extends StatelessWidget {
  const _EkubCard({
    required this.item,
    required this.onTap,
    required this.onAction,
    required this.actionLabel,
    required this.actionIcon,
    this.onExtraAction,
    this.extraActionLabel,
    this.extraActionIcon,
    this.busy = false,
  });
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback? onAction;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onExtraAction;
  final String? extraActionLabel;
  final IconData? extraActionIcon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final images = item['images'] as List? ?? [];
    final isItem = item['is_item'] == true;
    final capacity = _num(item['capacity']);
    final progress = capacity <= 0
        ? 0.0
        : (_num(item['used_capacity']) / capacity).clamp(0.0, 1.0).toDouble();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isItem)
                  _CategoryArtwork(
                    category: (item['category'] ?? '').toString(),
                    height: 142,
                  )
                else if (images.isEmpty)
                  const _ImageBox(height: 116)
                else
                  Image.network(
                    images.first.toString(),
                    height: 142,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ImageBox(height: 116),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['name']?.toString() ?? 'Ekub',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (item['joined'] == true) const _Pill(text: 'Joined'),
                      if (item['status'] == 'started')
                        const _Pill(text: 'Started'),
                      if (item['status'] == 'open' && item['joined'] != true)
                        const _Pill(text: 'Open'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    (item['category'] ?? '').toString() +
                        ' · ' +
                        (item['frequency'] ?? '').toString(),
                    style: TextStyle(color: context.palette.muted),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Contribution',
                          value: _money(item['base_amount']),
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: 'Members',
                          value:
                              _int(item['member_count']).toString() +
                              ' / ' +
                              _int(item['capacity']).toString(),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: progress,
                      backgroundColor: context.palette.track,
                      valueColor: const AlwaysStoppedAnimation<Color>(green),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                  child: Text(
                    item['is_full'] == true
                        ? 'Full'
                        : _num(item['slots_remaining']).toStringAsFixed(2) +
                              ' shares available',
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text(
                      'Details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onAction,
                    icon: busy && onExtraAction == null
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(actionIcon, size: 16),
                    label: Text(
                      actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (extraActionLabel != null) ...[
                  const SizedBox(width: 7),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onExtraAction,
                      icon: extraActionIcon == null
                          ? const SizedBox.shrink()
                          : Icon(extraActionIcon, size: 15),
                      label: Text(
                        extraActionLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: context.palette.muted, fontSize: 12)),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 52) / 2,
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.palette.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: context.palette.muted, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: green.withAlpha(36),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: green,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _PaymentAmount extends StatelessWidget {
  const _PaymentAmount({
    required this.label,
    required this.value,
    this.color = green,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: color.withAlpha(24),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.palette.muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ImageBox extends StatelessWidget {
  const _ImageBox({this.height = 170});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFEAF7EF), Color(0xFFE5F5FB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    alignment: Alignment.center,
    child: Container(
      width: height - 18,
      height: height - 18,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: green.withAlpha(35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.asset(
          'assets/images/mekenet-ekub-logo.png',
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}

class _FeatureValue extends StatelessWidget {
  const _FeatureValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: sky),
      const SizedBox(width: 6),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: context.palette.muted, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(19),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: green, size: 34),
          const SizedBox(height: 9),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.muted),
          ),
        ],
      ),
    ),
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.text, required this.onRetry});
  final String text;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.isError});
  final String text;
  final bool isError;
  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFE55252) : green;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        border: Border.all(color: color.withAlpha(90)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text.trim(),
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.35,
          color: isError
              ? (dark ? const Color(0xFFFFB7B7) : const Color(0xFF9E2424))
              : (dark ? const Color(0xFFBFF1D2) : const Color(0xFF17643A)),
        ),
      ),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map)
    return value.map((key, item) => MapEntry(key.toString(), item));
  return <String, dynamic>{};
}

double _num(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
int _int(dynamic value) => _num(value).toInt();
String _money(dynamic value) => _num(value).toStringAsFixed(2) + ' ETB';
String _paymentUsdt(dynamic value) => _num(value).toStringAsFixed(8);

String _periodLabel(Map<String, dynamic> value) {
  if (value['is_paid'] == true) return 'Paid';
  if (_num(value['pending']) > 0) return 'Pending review';
  if (value['can_pay'] == true) return 'Due now';
  if (value['is_current'] == true) return 'Current';
  return 'Upcoming';
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
