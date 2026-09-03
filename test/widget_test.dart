import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: ChatConnectApp()));

    // Da der GoRouter als Erstes den SplashScreen lädt,
    // sollte ein CircularProgressIndicator sichtbar sein.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
