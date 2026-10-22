import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/settlement_screens.dart';
import 'api_test.dart' show MemoryStore;

class ReserveApi extends Api {
  ReserveApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String p) async => p.endsWith('/reserve')
      ? {
          'version': 3,
          'balance': 5000,
          'available': 0,
          'unbackedAmount': 5000,
          'custodianId': 'other',
          'bankName': '은행',
          'maskedAccount': '***',
          'names': {},
          'entries': [
            {
              'id': 'x',
              'purpose': '원 목적',
              'amount': 1000,
              'kind': 'SPEND',
              'status': 'REQUESTED',
              'canExecute': false,
              'canRecordActual': true,
            },
          ],
        }
      : {'version': 2, 'role': 'MEMBER', 'status': 'ACTIVE'};
}

void main() {
  testWidgets(
    'reserve respects role and distinguishes already happened transactions from permission to execute',
    (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(ReserveApi())],
          child: const MaterialApp(
            home: Scaffold(body: ReserveScreen(id: 'c')),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('처음 보관 계좌 등록'), findsNothing);
      expect(find.text('적립금 사용'), findsNothing);
      expect(find.text('이미 발생한 거래 기록'), findsOneWidget);
      expect(find.textContaining('부족액'), findsWidgets);
    },
  );
}
