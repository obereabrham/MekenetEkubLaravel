import 'package:flutter/material.dart' hide Text;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'app_translation.dart';

typedef Text = LocalizedText;

class AppLockConfig {
  const AppLockConfig({
    this.enabled = false,
    this.method = 'pin',
    this.timeoutMinutes = 5,
    this.secret = '',
  });

  final bool enabled;
  final String method;
  final int timeoutMinutes;
  final String secret;

  static const _storage = FlutterSecureStorage();

  static Future<AppLockConfig> read() async => AppLockConfig(
    enabled: await _storage.read(key: 'mekenet_app_lock_enabled') == 'true',
    method: await _storage.read(key: 'mekenet_app_lock_method') ?? 'pin',
    timeoutMinutes:
        int.tryParse(
          await _storage.read(key: 'mekenet_app_lock_timeout') ?? '5',
        ) ??
        5,
    secret: await _storage.read(key: 'mekenet_app_lock_secret') ?? '',
  );

  Future<void> write() async {
    await _storage.write(
      key: 'mekenet_app_lock_enabled',
      value: enabled ? 'true' : 'false',
    );
    await _storage.write(key: 'mekenet_app_lock_method', value: method);
    await _storage.write(
      key: 'mekenet_app_lock_timeout',
      value: timeoutMinutes.toString(),
    );
    if (secret.isEmpty) {
      await _storage.delete(key: 'mekenet_app_lock_secret');
    } else {
      await _storage.write(key: 'mekenet_app_lock_secret', value: secret);
    }
  }
}

class AppLockSettingsPage extends StatefulWidget {
  const AppLockSettingsPage({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final AppLockConfig initial;
  final Future<void> Function(AppLockConfig) onSave;

  @override
  State<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends State<AppLockSettingsPage> {
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  bool _enabled = false;
  String _method = 'pin';
  int _timeout = 5;
  List<int> _pattern = const [];
  List<int> _confirmPattern = const [];
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initial.enabled;
    _method = widget.initial.method;
    _timeout = widget.initial.timeoutMinutes;
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      var secret = widget.initial.secret;
      if (!_enabled) {
        secret = '';
      } else if (_method == 'pin') {
        final pin = _pin.text.trim();
        if (pin.isNotEmpty) {
          if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
            throw const FormatException('Use a 4–8 digit PIN.');
          }
          if (pin != _confirmPin.text.trim()) {
            throw const FormatException('The PIN entries do not match.');
          }
          secret = pin;
        } else if (!widget.initial.enabled || widget.initial.method != 'pin') {
          throw const FormatException('Create and confirm a PIN to continue.');
        }
      } else if (_method == 'pattern') {
        if (_pattern.isNotEmpty || _confirmPattern.isNotEmpty) {
          if (_pattern.length < 4) {
            throw const FormatException('Connect at least four pattern dots.');
          }
          if (_pattern.join(',') != _confirmPattern.join(',')) {
            throw const FormatException('The pattern entries do not match.');
          }
          secret = _pattern.join(',');
        } else if (!widget.initial.enabled ||
            widget.initial.method != 'pattern') {
          throw const FormatException(
            'Draw and confirm a pattern to continue.',
          );
        }
      } else {
        final auth = LocalAuthentication();
        final available = await auth.getAvailableBiometrics();
        if (available.isEmpty) {
          throw const FormatException(
            'Set up a fingerprint or face in your phone settings first.',
          );
        }
        final ok = await auth.authenticate(
          localizedReason:
              'Confirm the biometric you will use to unlock Mekenet Ekub',
          biometricOnly: true,
        );
        if (!ok)
          throw const FormatException('Biometric setup was not confirmed.');
        secret = '';
      }

      await widget.onSave(
        AppLockConfig(
          enabled: _enabled,
          method: _method,
          timeoutMinutes: _timeout,
          secret: secret,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save app lock settings.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('App lock')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile.adaptive(
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            title: const Text('Protect this app'),
            subtitle: const Text(
              'Ask for your PIN, pattern, or biometric when you return.',
            ),
            secondary: const Icon(Icons.lock_outline_rounded),
          ),
        ),
        if (_enabled) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _method,
            decoration: const InputDecoration(labelText: 'Unlock method'),
            items: const [
              DropdownMenuItem(value: 'pin', child: Text('PIN')),
              DropdownMenuItem(value: 'pattern', child: Text('Pattern')),
              DropdownMenuItem(
                value: 'biometric',
                child: Text('Fingerprint / biometric'),
              ),
            ],
            onChanged: (value) => setState(() {
              _method = value ?? 'pin';
              _pattern = const [];
              _confirmPattern = const [];
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _timeout,
            decoration: const InputDecoration(
              labelText: 'Lock after leaving the app',
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Immediately')),
              DropdownMenuItem(value: 1, child: Text('1 minute')),
              DropdownMenuItem(value: 5, child: Text('5 minutes')),
              DropdownMenuItem(value: 10, child: Text('10 minutes')),
              DropdownMenuItem(value: 60, child: Text('1 hour')),
              DropdownMenuItem(value: -1, child: Text('Never')),
            ],
            onChanged: (value) => setState(() => _timeout = value ?? 5),
          ),
          if (_method == 'pin') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              decoration: InputDecoration(
                labelText:
                    widget.initial.enabled && widget.initial.method == 'pin'
                    ? 'New PIN (leave blank to keep current)'
                    : 'Create a 4–8 digit PIN',
              ),
            ),
            TextField(
              controller: _confirmPin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              decoration: const InputDecoration(labelText: 'Confirm PIN'),
            ),
          ],
          if (_method == 'pattern') ...[
            const SizedBox(height: 12),
            const Text('Draw a pattern using at least four dots.'),
            _PatternPad(
              onComplete: (value) => setState(() => _pattern = value),
            ),
            const Text('Draw it again to confirm.'),
            _PatternPad(
              onComplete: (value) => setState(() => _confirmPattern = value),
            ),
          ],
          if (_method == 'biometric')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Your phone must have an enrolled fingerprint or other biometric.',
              ),
            ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save app lock'),
        ),
      ],
    ),
  );
}

class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.config,
    required this.onUnlock,
    required this.onSignInAgain,
  });

  final AppLockConfig config;
  final VoidCallback onUnlock;
  final VoidCallback onSignInAgain;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  final _pin = TextEditingController();
  List<int> _pattern = const [];
  String? _message;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    if (widget.config.method == 'biometric') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'Unlock Mekenet Ekub',
        biometricOnly: true,
      );
      if (ok && mounted) widget.onUnlock();
      if (!ok && mounted)
        setState(
          () => _message = 'Biometric check was not completed. Try again.',
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _message =
              'Biometric unlock is unavailable. Sign in again or check your phone settings.',
        );
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  void _unlockWithPin() {
    if (_pin.text == widget.config.secret) {
      widget.onUnlock();
    } else {
      setState(() {
        _pin.clear();
        _message = 'That PIN is incorrect.';
      });
    }
  }

  void _unlockWithPattern(List<int> pattern) {
    if (pattern.join(',') == widget.config.secret) {
      widget.onUnlock();
    } else {
      setState(() {
        _pattern = const [];
        _message = 'That pattern is incorrect.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 52,
                  color: Color(0xFF88B44A),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mekenet Ekub is locked',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 22),
                if (widget.config.method == 'pin') ...[
                  TextField(
                    controller: _pin,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Enter your PIN',
                    ),
                    onSubmitted: (_) => _unlockWithPin(),
                  ),
                  FilledButton(
                    onPressed: _unlockWithPin,
                    child: const Text('Unlock'),
                  ),
                ] else if (widget.config.method == 'pattern') ...[
                  const Text('Draw your unlock pattern.'),
                  _PatternPad(
                    onComplete: (value) {
                      setState(() => _pattern = value);
                      _unlockWithPattern(value);
                    },
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: _authenticating ? null : _authenticate,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text(
                      _authenticating ? 'Checking…' : 'Unlock with biometrics',
                    ),
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 18),
                TextButton(
                  onPressed: widget.onSignInAgain,
                  child: const Text('Sign in again'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PatternPad extends StatefulWidget {
  const _PatternPad({required this.onComplete});

  final ValueChanged<List<int>> onComplete;

  @override
  State<_PatternPad> createState() => _PatternPadState();
}

class _PatternPadState extends State<_PatternPad> {
  final List<int> _sequence = [];

  void _addPoint(Offset point, Size size) {
    final column = (point.dx / (size.width / 3)).floor().clamp(0, 2);
    final row = (point.dy / (size.height / 3)).floor().clamp(0, 2);
    final index = row * 3 + column;
    if (!_sequence.contains(index)) setState(() => _sequence.add(index));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              _sequence.clear();
              _addPoint(details.localPosition, size);
            },
            onPanUpdate: (details) => _addPoint(details.localPosition, size),
            onPanEnd: (_) =>
                widget.onComplete(List<int>.unmodifiable(_sequence)),
            child: CustomPaint(
              painter: _PatternPainter(List<int>.unmodifiable(_sequence)),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    ),
  );
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter(this.sequence);

  final List<int> sequence;

  Offset _center(int index, Size size) => Offset(
    (index % 3 + 0.5) * size.width / 3,
    (index ~/ 3 + 0.5) * size.height / 3,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF88B44A)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var index = 1; index < sequence.length; index++) {
      canvas.drawLine(
        _center(sequence[index - 1], size),
        _center(sequence[index], size),
        line,
      );
    }
    for (var index = 0; index < 9; index++) {
      final selected = sequence.contains(index);
      canvas.drawCircle(
        _center(index, size),
        selected ? 13 : 10,
        Paint()
          ..color = selected
              ? const Color(0xFF88B44A)
              : const Color(0xFF8A9691),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) =>
      oldDelegate.sequence != sequence;
}
