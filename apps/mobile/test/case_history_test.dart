import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/case_screens.dart';
import 'api_test.dart' show MemoryStore;

class CaseApi extends Api {
  CaseApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String p) async => {
    'status': 'OPEN',
    'reason': '도움 요청',
    'history': [
      {
        'action': 'CREATED',
        'reason': '접수 기록',
        'createdAt': '2026-10-22T10:00:00Z',
      },
      {
        'action': 'CLAIM',
        'reason': '배정 기록',
        'createdAt': '2026-10-22T10:05:00Z',
      },
    ],
  };
}

void main() {
  testWidgets(
    'operator history uses Korean action and local date labels while preserving server codes',
    (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(CaseApi())],
          child: const MaterialApp(
            home: Scaffold(body: CaseDetail(id: 'case')),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('접수'), findsOneWidget);
      expect(find.text('담당 배정'), findsOneWidget);
      expect(find.textContaining('T10:'), findsNothing);
    },
  );
}
