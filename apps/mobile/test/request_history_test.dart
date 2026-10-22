import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/request_history.dart';
import 'api_test.dart' show MemoryStore;

class RequestsApi extends Api {
  RequestsApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String p) async => [
    {
      'id': 'x',
      'userId': 'u',
      'nickname': '산책자',
      'status': 'REJECTED',
      'memo': '늦게 합류하고 싶어요',
      'reason': '주최자의 일정 확인 결과',
      'createdAt': '2026-10-22T10:00:00Z',
      'createdBy': 'host',
    },
  ];
}

void main() {
  testWidgets(
    'private request history retains application memo and explicit rejection reason',
    (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(RequestsApi())],
          child: const MaterialApp(
            home: Scaffold(
              body: RequestHistoryPanel(
                path: '/rounds/r/request-history',
                title: '내 합류 요청 이력',
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('내 합류 요청 이력'));
      await t.pumpAndSettle();
      expect(find.textContaining('늦게 합류하고 싶어요'), findsOneWidget);
      expect(find.textContaining('주최자의 일정 확인 결과'), findsOneWidget);
      expect(find.textContaining('산책자'), findsOneWidget);
    },
  );
}
