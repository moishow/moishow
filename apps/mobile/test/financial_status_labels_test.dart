import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/main.dart';
import 'package:moishow/finance_screen.dart';
import 'mobile_flow_test.dart' show FinanceUiApi;

class ReceivedRefundApi extends FinanceUiApi {
  @override
  Future<dynamic> get(String p) async {
    final result = await super.get(p);
    if (p == '/events/e/finance') {
      final d = Map<String, dynamic>.from(result);
      d['status'] = 'REGISTERED';
      d['refunds'] = [
        {
          'id': 'refund',
          'userId': 'u',
          'amount': 5000,
          'sentAmount': 5000,
          'status': 'CONFIRMED',
        },
      ];
      return d;
    }
    return result;
  }
}

void main() {
  testWidgets(
    'a confirmed refund means actual receipt rather than participation confirmation',
    (t) async {
      final api = ReceivedRefundApi();
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
      expect(find.textContaining('수령 확인 완료'), findsOneWidget);
      expect(find.textContaining('참여 확정'), findsNothing);
    },
  );
}
