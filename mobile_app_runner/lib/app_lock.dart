import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

const _lockGreen = Color(0xFF88B44A);

class AppLockSettingsPage extends StatefulWidget {
  const AppLockSettingsPage({super.key, required this.onChanged});
  final Future<void> Function() onChanged;

  @override
  State<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends State<AppLockSettingsPage> {
  static const _storage = FlutterSecureStorage();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  String _method = 'pin';
  final List<int> _pattern = [];
  List<int> _firstPattern = [];
  bool _confirmPattern = false;
  bool _enabled = false;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      _storage.read(key: 'mekenet_app_lock_enabled'),
      _storage.read(key: 'mekenet_app_lock_method'),
    ]);
    if (!mounted) return;
    setState(() {
      _enabled = values[0] == 'true';
      _method = values[1] == 'pattern' ? 'pattern' : 'pin';
      _busy = false;
    });
  }

  Future<void> _savePin() async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(_pin.text)) {
      setState(() => _error = 'Choose a PIN with 4 to 8 digits.');
      return;
    }
    if (_pin.text != _confirmation.text) {
      setState(() => _error = 'The PIN entries do not match.');
      return;
    }
    await _saveSecret('pin', _pin.text);
  }

  Future<void> _savePattern() async {
    if (!_confirmPattern) {
      if (_pattern.length < 4) {
        setState(() => _error = 'Choose at least four pattern points.');
        return;
      }
      setState(() {
        _firstPattern = List.of(_pattern);
        _pattern.clear();
        _confirmPattern = true;
        _error = null;
      });
      return;
    }
    if (_pattern.join(',') != _firstPattern.join(',')) {
      setState(() {
        _pattern.clear();
        _firstPattern.clear();
        _confirmPattern = false;
        _error = 'The patterns did not match. Draw it again.';
      });
      return;
    }
    await _saveSecret('pattern', _pattern.join(','));
  }

  Future<void> _saveSecret(String method, String secret) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final salt = List.generate(16, (_) => math.Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final digest = sha256.convert(utf8.encode('$salt:$secret')).toString();
    await _storage.write(key: 'mekenet_app_lock_method', value: method);
    final patternLength = method == 'pattern' ? ':${secret.split(',').length}' : '';
    await _storage.write(key: 'mekenet_app_lock_secret', value: '$salt:$digest$patternLength');
    await _storage.write(key: 'mekenet_app_lock_enabled', value: 'true');
    await widget.onChanged();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _enabled = true;
      _pin.clear();
      _confirmation.clear();
      _pattern.clear();
      _firstPattern.clear();
      _confirmPattern = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App lock enabled.')),
    );
  }

  Future<void> _disable() async {
    await _storage.write(key: 'mekenet_app_lock_enabled', value: 'false');
    await _storage.delete(key: 'mekenet_app_lock_secret');
    await widget.onChanged();
    if (mounted) setState(() => _enabled = false);
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('App lock')),
    body: _busy && !_enabled
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline, color: _lockGreen),
                  title: Text(_enabled ? 'App lock is on' : 'Lock the app'),
                  subtitle: const Text(
                    'The app locks when you leave it and asks for your code when you return.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Lock method'),
                items: const [
                  DropdownMenuItem(value: 'pin', child: Text('PIN')),
                  DropdownMenuItem(value: 'pattern', child: Text('Pattern')),
                ],
                onChanged: (value) => setState(() {
                  _method = value ?? 'pin';
                  _error = null;
                  _confirmPattern = false;
                  _firstPattern.clear();
                  _pattern.clear();
                }),
              ),
              const SizedBox(height: 16),
              if (_method == 'pin') ...[
                TextField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 8,
                  decoration: const InputDecoration(labelText: 'New PIN (4–8 digits)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmation,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 8,
                  decoration: const InputDecoration(labelText: 'Confirm PIN'),
                ),
              ] else ...[
                Text(_confirmPattern ? 'Draw the same pattern again.' : 'Choose at least four points.'),
                const SizedBox(height: 12),
                _PatternGrid(
                  selected: _pattern,
                  onPoint: (point) => setState(() {
                    _error = null;
                    if (!_pattern.contains(point)) _pattern.add(point);
                  }),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _pattern.clear()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Clear pattern'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : (_method == 'pin' ? _savePin : _savePattern),
                icon: const Icon(Icons.lock_outline),
                label: Text(_method == 'pin' ? 'Save PIN and enable lock' : (_confirmPattern ? 'Confirm pattern' : 'Continue')),
              ),
              if (_enabled) ...[
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _busy ? null : _disable, child: const Text('Turn off app lock')),
              ],
            ],
          ),
  );
}

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.method, required this.secret, required this.onUnlock});
  final String method;
  final String secret;
  final VoidCallback onUnlock;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  final _pin = TextEditingController();
  final _pattern = <int>[];
  String? _error;

  void _check(String candidate) {
    final parts = widget.secret.split(':');
    final digest = parts.length >= 2 ? sha256.convert(utf8.encode('${parts[0]}:$candidate')).toString() : '';
    if (parts.length >= 2 && digest == parts[1]) {
      widget.onUnlock();
      return;
    }
    setState(() {
      _pattern.clear();
      _pin.clear();
      _error = 'That code did not match. Try again.';
    });
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 54, color: _lockGreen),
                const SizedBox(height: 16),
                const Text('Mekenet Ekub is locked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                if (widget.method == 'pin')
                  TextField(
                    controller: _pin,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 8,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Enter your PIN'),
                    onSubmitted: _check,
                  )
                else ...[
                  _PatternGrid(
                    selected: _pattern,
                    onPoint: (point) {
                      if (_pattern.contains(point)) return;
                      _pattern.add(point);
                      setState(() => _error = null);
                    },
                    onComplete: () {
                      final secretParts = widget.secret.split(':');
                      final requiredPoints = secretParts.length > 2 ? int.tryParse(secretParts[2]) ?? 4 : 4;
                      if (_pattern.length == requiredPoints) {
                        _check(_pattern.join(','));
                      } else {
                        setState(() {
                          _pattern.clear();
                          _error = 'That pattern did not match. Try again.';
                        });
                      }
                    },
                  ),
                  TextButton(onPressed: () => setState(_pattern.clear), child: const Text('Clear')),
                ],
                if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                if (widget.method == 'pin') ...[
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => _check(_pin.text), child: const Text('Unlock')),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PatternGrid extends StatelessWidget {
  const _PatternGrid({required this.selected, required this.onPoint, this.onComplete});
  final List<int> selected;
  final ValueChanged<int> onPoint;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        final cell = side / 3;
        int? pointAt(Offset position) {
          if (position.dx < 0 || position.dy < 0 || position.dx > side || position.dy > side) return null;
          final column = (position.dx / cell).floor().clamp(0, 2).toInt();
          final row = (position.dy / cell).floor().clamp(0, 2).toInt();
          final center = Offset((column + .5) * cell, (row + .5) * cell);
          if ((position - center).distance > cell * .46) return null;
          return row * 3 + column;
        }

        void addPoint(Offset position) {
          final point = pointAt(position);
          if (point != null && !selected.contains(point)) onPoint(point);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => addPoint(details.localPosition),
          onPanStart: (details) => addPoint(details.localPosition),
          onPanUpdate: (details) => addPoint(details.localPosition),
          onPanEnd: (_) => onComplete?.call(),
          child: CustomPaint(
            painter: _PatternPainter(points: List<int>.of(selected)),
            child: SizedBox.expand(
              child: Stack(
                children: List.generate(9, (index) {
                  final active = selected.contains(index);
                  return Positioned(
                    left: (index % 3) * cell,
                    top: (index ~/ 3) * cell,
                    width: cell,
                    height: cell,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: active ? 42 : 28,
                        height: active ? 42 : 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? _lockGreen : _lockGreen.withAlpha(35),
                          border: Border.all(color: _lockGreen, width: 2),
                        ),
                        child: active
                            ? Center(child: Text('${selected.indexOf(index) + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({required this.points});
  final List<int> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final cell = size.width / 3;
    final paint = Paint()
      ..color = _lockGreen.withAlpha(150)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < points.length; i++) {
      final from = points[i - 1];
      final to = points[i];
      canvas.drawLine(
        Offset((from % 3 + .5) * cell, (from ~/ 3 + .5) * cell),
        Offset((to % 3 + .5) * cell, (to ~/ 3 + .5) * cell),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) =>
      oldDelegate.points.join(',') != points.join(',');
}
