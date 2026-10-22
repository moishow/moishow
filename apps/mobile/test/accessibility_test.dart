import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/screens.dart';
import 'package:moishow/auth.dart';
import 'package:moishow/api.dart';
import 'package:moishow/widgets.dart';
import 'api_test.dart' show MemoryStore;

void main() {
  test('won follows grouped tabular currency without changing integers', () {
    expect(won(10000), '10,000원');
    expect(won(-5000), '-5,000원');
  });
  testWidgets(
    'login remains usable at 200 percent text on a narrow short screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: LoginScreen(
            auth: NativeAuth(Api(store: MemoryStore(), intents: MemoryStore())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
