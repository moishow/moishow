import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/advance_screen.dart';
import 'package:moishow/handover_inbox.dart';
import 'api_test.dart' show MemoryStore;

class AdvanceApi extends Api {
  AdvanceApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String path) async => {
    'eventId': 'e',
    'version': 4,
    'responsibleId': 'u',
    'names': {
      'u': {'nickname': '새 담당자', 'departed': false},
      'old': {'nickname': '기존 주최자', 'departed': true},
    },
    'liabilities': [
      {'creditorId': 'old', 'amount': 6000},
    ],
    'custody': [
      {
        'actorId': 'u',
        'cashHeld': 6000,
        'advanceDue': 0,
        'proposedSelfRecovery': 0,
        'transferableCash': 6000,
        'remainingAdvanceLiability': 0,
        'deficit': 0,
      },
    ],
    'repayments': [],
    'recoveries': [],
  };
}

class StaleApi extends AdvanceApi {
  @override
  Future<dynamic> get(String path) async {
    if (path == '/me/owner-transfers') return [];
    return [
      {
        'id': 'h',
        'eventId': 'e',
        'version': 5,
        'bookVersion': 9,
        'proposerId': 'old',
        'candidateId': 'u',
        'proposerNickname': '기존 주최자',
        'candidateNickname': '새 담당자',
        'inventoryAmount': 5000,
        'inventoryNote': '기존 선지출 반환 의무 유지',
        'status': 'RECEIVED_STALE',
        'requiresReproposal': true,
        'inventory': {
          'names': {
            'old': {'nickname': '기존 주최자', 'departed': true},
            'u': {'nickname': '새 담당자', 'departed': false},
          },
          'cashHeld': 5000,
          'advanceLiabilities': [
            {'creditorId': 'old', 'amount': 6000},
          ],
          'ordinaryRefundLiabilities': [],
          'pendingTransactions': [],
        },
        'currentInventory': {
          'ready': true,
          'proposerCashHeld': 0,
          'candidateCashHeld': 5000,
          'unbackedAmount': 0,
        },
        'returns': [],
      },
    ];
  }
}

class CashTransferApi extends AdvanceApi {
  @override
  Future<dynamic> get(String path) async {
    if (path.endsWith('/custody-transfers')) {
      return {
        'version': 9,
        'responsibleId': 'new',
        'names': {
          'u': {'nickname': '원래 담당자', 'departed': true},
          'new': {'nickname': '현 담당자', 'departed': false},
        },
        'transfers': [
          {
            'id': 'cash',
            'senderId': 'u',
            'recipientId': 'new',
            'amount': 150,
            'status': 'REQUESTED',
            'createdAt': '2026-10-22',
          },
        ],
      };
    }
    return super.get(path);
  }
}

void main() {
  testWidgets(
    'cash left after factual correction transfers to fixed responsible without another authority handover',
    (t) async {
      final api = CashTransferApi();
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
            home: Scaffold(body: AdvanceScreen(id: 'e')),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('추가 보관금 인계'), findsOneWidget);
      expect(find.textContaining('담당 권한은 바뀌지 않습니다'), findsOneWidget);
      expect(find.textContaining('현 담당자'), findsWidgets);
    },
  );

  testWidgets(
    'actual stale handover receipt never transfers authority or recharges held cash',
    (tester) async {
      final api = StaleApi();
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
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: HandoverInbox())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('권한은 아직 이전되지 않았습니다'), findsOneWidget);
      expect(find.textContaining('이미 받은 현금'), findsOneWidget);
    },
  );
  testWidgets(
    'handover keeps named original host repayment separate from cash in new custody',
    (tester) async {
      final api = AdvanceApi();
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
          child: const MaterialApp(
            home: Scaffold(body: AdvanceScreen(id: 'e')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('기존 주최자 · 탈퇴한 멤버'), findsOneWidget);
      expect(find.text('선지출 반환 요청'), findsOneWidget);
      expect(find.textContaining('외부 송금 완료가 아닙니다'), findsOneWidget);
    },
  );
}
