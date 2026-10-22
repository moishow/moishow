import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/main.dart';
import 'package:moishow/event_screen.dart';
import 'mobile_flow_test.dart' show ConsentApi;

class DelegateApi extends ConsentApi {
  @override
  Future<dynamic> get(String p) async {
    if (p.endsWith('/access')) {
      return {
        'manageEvent': false,
        'manageSettlement': true,
        'viewSettlement': true,
      };
    }
    if (p.endsWith('/participations')) {
      return [
        {
          'id': 'p',
          'roundId': 'r',
          'userId': 'u',
          'nickname': '참가자',
          'status': 'CONFIRMED',
          'agreedFee': 1000,
          'version': 1,
        },
      ];
    }
    if (p.endsWith('/request-history')) return [];
    return super.get(p);
  }
}

void main() {
  testWidgets(
    'financial handover does not grant host cancellation or fee changes',
    (t) async {
      final api = DelegateApi();
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
            home: Scaffold(body: EventScreen(id: 'e')),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('비용 변경 제안'), findsNothing);
      expect(find.text('차수 취소'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.text('이벤트 최종 정산'), findsOneWidget);
    },
  );
}
