import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/case_screens.dart';
import 'api_test.dart' show MemoryStore;

class DisputeApi extends Api {
  DisputeApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String p) async => {
    'version': 5,
    'status': 'OPEN',
    'reason': '비용 확인',
    'canResolve': true,
    'relatedRevisions': [
      {'id': 'revision', 'createdAt': '2026-10-22', 'correctionAmount': -3000},
    ],
  };
}

void main() {
  testWidgets(
    'private dispute resolution chooses the exact related immutable revision',
    (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(DisputeApi())],
          child: const MaterialApp(
            home: Scaffold(
              body: DisputeDetail(eventId: 'e', id: 'd'),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('인정·반려 결과 기록'));
      await t.pumpAndSettle();
      expect(find.text('연결할 정정 기록'), findsOneWidget);
      expect(find.textContaining('직접 금액을 바꾸지 않습니다'), findsOneWidget);
    },
  );
}
