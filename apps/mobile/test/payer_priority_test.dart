import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/main.dart';
import 'package:moishow/finance_screen.dart';
import 'mobile_flow_test.dart' show FinanceUiApi;

class PayerApi extends FinanceUiApi {
  @override
  Future<dynamic> get(String p) async {
    if (p.endsWith('/access')) {
      return {'manageSettlement': false, 'viewSettlement': true};
    }
    final result = await super.get(p);
    if (p == '/events/e/finance') {
      final d = Map<String, dynamic>.from(result);
      d['mode'] = 'PREPAY';
      d['requests'] = [
        {
          'id': 'q',
          'userId': 'u',
          'roundId': 'r',
          'amount': 20000,
          'remaining': 20000,
          'status': 'UNPAID',
          'deadline': '2026-12-01T12:00:00Z',
        },
      ];
      return d;
    }
    return result;
  }
}

void main() {
  testWidgets(
    'payer sees own advance payment request before provisional zero expense positions',
    (t) async {
      final api = PayerApi();
      await api.saveSession({
        'token': 'test',
        'scope': 'ACTIVE',
        'userId': 'u',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: const MaterialApp(
            home: Scaffold(body: FinanceScreen(id: 'e')),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('내 납부 요청'), findsOneWidget);
      expect(find.textContaining('최초 정산 등록 전'), findsOneWidget);
    },
  );
}
