import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekenet_mobile/app_lock.dart';

void main() {
  testWidgets('App lock accepts the saved PIN', (tester) async {
    const salt = 'test-salt';
    const pin = '2468';
    final digest = sha256.convert(utf8.encode('$salt:$pin')).toString();
    var unlocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          method: 'pin',
          secret: '$salt:$digest',
          onUnlock: () => unlocked = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), pin);
    await tester.tap(find.text('Unlock'));
    await tester.pump();

    expect(unlocked, isTrue);
  });

  testWidgets('App lock rejects an incorrect PIN', (tester) async {
    const salt = 'test-salt';
    const pin = '2468';
    final digest = sha256.convert(utf8.encode('$salt:$pin')).toString();

    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          method: 'pin',
          secret: '$salt:$digest',
          onUnlock: () {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '1357');
    await tester.tap(find.text('Unlock'));
    await tester.pump();

    expect(find.text('That code did not match. Try again.'), findsOneWidget);
  });
}
