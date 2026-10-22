import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/widgets.dart';
import 'package:moishow/screens.dart';
import 'package:moishow/account_screens.dart';
import 'api_test.dart' show MemoryStore;

class FlowApi extends Api {
  FlowApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String path) async {
    if (path.startsWith('/home')) return {'tasks': [], 'upcoming': []};
    if (path == '/clubs') {
      return [
        {
          'id': 'club',
          'name': '산책 모임',
          'role': 'OWNER',
          'membershipStatus': 'ACTIVE',
          'version': 0,
        },
      ];
    }
    if (path == '/clubs/club') {
      return {
        'id': 'club',
        'name': '산책 모임',
        'role': 'OWNER',
        'membershipStatus': 'ACTIVE',
        'version': 0,
      };
    }
    return [];
  }
}

class ConsentApi extends FlowApi {
  @override
  Future<dynamic> get(String path) async {
    if (path == '/events/e') {
      return {
        'id': 'e',
        'clubId': 'club',
        'title': '산책',
        'settlementMode': 'PREPAY',
        'version': 2,
        'startsAt': '2026-12-01T10:00:00Z',
        'endsAt': '2026-12-01T20:00:00Z',
        'rounds': [
          {
            'id': 'r',
            'capacity': 10,
            'closesAt': '2026-12-01T00:00:00Z',
            'cancellationFee': 1000,
            'feeVersion': 2,
            'status': 'OPEN',
            'version': 4,
          },
        ],
      };
    }
    if (path == '/events/e/access') {
      return {
        'manageSettlement': false,
        'manageEvent': false,
        'viewSettlement': true,
      };
    }
    if (path == '/rounds/r/participation') {
      return {
        'id': 'p',
        'roundId': 'r',
        'version': 4,
        'status': 'CONFIRMED',
        'agreedFee': 500,
        'agreedFeeVersion': 1,
        'feeConsent': 'PENDING',
        'scheduleConsent': 'PENDING',
        'consentHistory': [],
      };
    }
    return super.get(path);
  }
}

class InboxApi extends FlowApi {
  @override
  Future<dynamic> get(String path) async {
    if (path.startsWith('/chat/rooms')) return [];
    if (path.startsWith('/chat/requests')) {
      return [
        {
          'id': 'pending',
          'title': '산책 이웃',
          'lastMessage': '같이 걸어요.',
          'status': 'PENDING',
          'kind': 'DIRECT',
        },
      ];
    }
    if (path.startsWith('/chat/invitations')) {
      return [
        {'id': 'g', 'title': '주말 산책', 'kind': 'GROUP_DM'},
      ];
    }
    if (path == '/support/cases') {
      return [
        {
          'id': 'case',
          'version': 0,
          'caseType': 'REPORT',
          'status': 'OPEN',
          'canClaim': true,
          'canReadDetails': false,
          'canDecide': false,
          'isRequester': false,
        },
      ];
    }
    return super.get(path);
  }
}

class FinanceUiApi extends ConsentApi {
  @override
  Future<dynamic> get(String path) async {
    if (path == '/events/e/access') {
      return {
        'manageSettlement': true,
        'manageEvent': true,
        'viewSettlement': true,
      };
    }
    if (path == '/events/e/finance') {
      return {
        'version': 1,
        'eventVersion': 2,
        'status': 'OPEN',
        'mode': 'POSTPAY',
        'names': {
          'u': {'nickname': '산책왕', 'departed': false},
        },
        'requests': [],
        'reports': [],
        'expenses': [],
        'refunds': [],
        'disputes': [],
        'revisions': [],
        'calculation': {
          'positions': [],
          'rounds': [],
          'totalExpense': 0,
          'pendingCancellation': 0,
          'reserveRemainder': 0,
          'hostContribution': 0,
        },
        'funding': {'ready': true, 'positions': [], 'custody': []},
      };
    }
    if (path == '/events/e/handovers' || path == '/events/e/support/results') {
      return [];
    }
    return super.get(path);
  }
}

void main() {
  testWidgets(
    'expense requires actual funding portions with an explicit source',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FinanceUiApi();
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
            home: Scaffold(body: FinanceScreen(id: 'e')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('지출 추가'));
      await tester.tap(find.text('지출 추가'));
      await tester.pumpAndSettle();
      expect(find.text('자금 출처'), findsOneWidget);
      expect(find.text('지급자'), findsOneWidget);
    },
  );
  testWidgets(
    'chat shows separate request and group invitation acceptance flows',
    (tester) async {
      final api = InboxApi();
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
          child: const MaterialApp(home: Scaffold(body: ChatScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('그룹 대화 만들기'), findsOneWidget);
      expect(find.text('받은 대화 요청'), findsOneWidget);
      expect(find.text('그룹 초대'), findsOneWidget);
    },
  );
  testWidgets('eligible handler claims a case before private detail access', (
    tester,
  ) async {
    final api = InboxApi();
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
        child: const MaterialApp(home: Scaffold(body: CasesScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('담당자로 맡기'), findsOneWidget);
  });
  testWidgets(
    'pending fee/date consent keeps participation and offers explicit accept or free cancellation',
    (tester) async {
      final api = ConsentApi();
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
            home: Scaffold(body: EventScreen(id: 'e')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('변경 비용에 동의'), findsOneWidget);
      expect(find.text('비용 변경 거부 · 무료 취소'), findsOneWidget);
      expect(find.textContaining('미응답이어도 참여는 유지'), findsNWidgets(2));
    },
  );
  testWidgets(
    'home plus opens the shared composer with explicit settlement selection',
    (tester) async {
      final api = FlowApi();
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
          child: const MoishowApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('정모·번개 만들기'));
      await tester.pumpAndSettle();
      expect(find.text('정산 방식'), findsOneWidget);
      expect(find.text('차수 추가'), findsOneWidget);
    },
  );
  testWidgets(
    'evidence field offers actual photo selection instead of reference text',
    (tester) async {
      final api = FlowApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommandForm(
              api: api,
              title: '지출',
              path: '/events/e/finance/expenses',
              fields: const [FormFieldSpec('evidence', '증빙', optional: true)],
              base: const {'version': 1},
              onDone: () {},
            ),
          ),
        ),
      );
      expect(find.text('사진 선택'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    },
  );
}
