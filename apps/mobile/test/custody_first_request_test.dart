import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/advance_screen.dart';
import 'api_test.dart' show MemoryStore;

class EmptyCashApi extends Api {
  EmptyCashApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String p) async => {
    'eventId': 'e',
    'version': 9,
    'responsibleId': 'new',
    'transfers': [],
    'names': {
      'new': {'nickname': '현 담당자', 'departed': false},
    },
  };
}

void main() {
  testWidgets(
    'first cash transfer remains possible with an empty history and exact current recipient name',
    (t) async {
      final api = EmptyCashApi();
      await api.saveSession({
        'token': 'test',
        'scope': 'ACTIVE',
        'userId': 'old',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: const MaterialApp(
            home: Scaffold(body: CustodyTransfers(id: 'e')),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('현 담당자 현 담당자'), findsOneWidget);
      expect(find.text('남은 보관금 인계 요청'), findsOneWidget);
      expect(find.textContaining('응답 형식'), findsNothing);
    },
  );
}
