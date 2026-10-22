import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/event_reserve_transfer.dart';
import 'api_test.dart' show MemoryStore;

class ContextApi extends Api {
  final paths = <String>[];
  ContextApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String p) async {
    paths.add(p);
    return {
      'clubId': 'c',
      'reserveVersion': 9,
      'bankName': '은행',
      'maskedAccount': '***',
      'sourceAvailable': 100,
      'maxTransferable': 80,
      'canDeposit': true,
      'custodianNickname': '보관 담당',
      'deposits': [
        {
          'id': 'deposit',
          'amount': 80,
          'purpose': '해당 출처',
          'status': 'PROPOSED',
          'canMarkSent': true,
          'canConfirm': false,
        },
      ],
    };
  }
}

void main() {
  testWidgets(
    'former event handler uses narrow reserve context without loading full club ledger',
    (t) async {
      final api = ContextApi();
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: const MaterialApp(
            home: Scaffold(body: EventReserveTransfer(eventId: 'e')),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('실제 보관금에서 적립 전환 제안'), findsOneWidget);
      expect(api.paths, ['/events/e/reserve-transfer-context']);
      expect(find.text('적립 실제 송금 기록'), findsOneWidget);
    },
  );
}
