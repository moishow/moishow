import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/main.dart';
import 'package:moishow/account_screens.dart';
import 'package:moishow/api.dart';
import 'api_test.dart' show MemoryStore;

class BankUiApi extends Api {
  BankUiApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String path) async {
    if (path == '/notification-preferences') return {'pushEnabled': false};
    if (path == '/me/bank-account') return {'registered': false, 'version': 0};
    return [];
  }
}

void main() {
  testWidgets(
    'settings has a real personal bank verification flow without fabricated status',
    (tester) async {
      final api = BankUiApi();
      await api.saveSession({
        'token': 'test-only',
        'scope': 'ACTIVE',
        'userId': 'u',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('개인 계좌 등록·확인'), findsOneWidget);
      expect(find.text('확인된 개인 계좌가 없습니다.'), findsOneWidget);
    },
  );
}
