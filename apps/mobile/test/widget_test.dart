import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/widgets.dart';
import 'package:dio/dio.dart';

import 'api_test.dart' show MemoryStore, RecordingAdapter;

void main() {
  testWidgets(
    'payment transport failure stays unconfirmed and retry uses the same key',
    (tester) async {
      final adapter = RecordingAdapter()..failFirst = true;
      final api = Api(
        dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter,
        store: MemoryStore(),
        intents: MemoryStore(),
      );
      int reloads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommandForm(
              api: api,
              title: '납부 신고',
              path: '/reports',
              fields: const [
                FormFieldSpec('amount', '신고 금액', kind: FieldKind.amount),
              ],
              base: const {'version': 1},
              onDone: () => reloads++,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), '10000');
      await tester.tap(find.text('확인하고 요청'));
      await tester.pumpAndSettle();
      expect(reloads, 0);
      expect(find.textContaining('요청을 완료하지 못했습니다'), findsOneWidget);
      await tester.tap(find.text('같은 요청 다시 시도'));
      await tester.pumpAndSettle();
      expect(reloads, 1);
      expect(
        adapter.requests[0].headers['Idempotency-Key'],
        adapter.requests[1].headers['Idempotency-Key'],
      );
    },
  );
  testWidgets('version conflict requires reload and disables resubmission', (
    tester,
  ) async {
    final adapter = RecordingAdapter()..status = 409;
    final api = Api(
      dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter,
      store: MemoryStore(),
      intents: MemoryStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandForm(
            api: api,
            title: '환불 확인',
            path: '/refunds/r/confirm',
            fields: const [],
            base: const {'version': 1},
            onDone: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('확인하고 요청'));
    await tester.pumpAndSettle();
    expect(find.text('최신 자료 다시 불러오기'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(adapter.requests.length, 1);
  });
  testWidgets(
    'signed out user sees real provider login without fake continue',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiProvider.overrideWithValue(
              Api(store: MemoryStore(), intents: MemoryStore()),
            ),
          ],
          child: const MoishowApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('카카오로 계속하기'), findsOneWidget);
      expect(find.text('Google로 계속하기'), findsOneWidget);
      expect(find.text('Apple로 계속하기'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );
  testWidgets('onboarding session cannot enter active app', (tester) async {
    final api = Api(store: MemoryStore(), intents: MemoryStore());
    await api.saveSession({
      'token': 'pending',
      'scope': 'ONBOARDING',
      'userId': 'u',
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: const MoishowApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('전화번호 인증'), findsOneWidget);
    expect(find.text('SMS 보내기'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
