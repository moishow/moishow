import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/bank_verification.dart';
import 'package:moishow/bank_account.dart';
import 'package:moishow/settlement_screens.dart';
import 'package:moishow/handover_review.dart';
import 'package:moishow/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_test.dart' show MemoryStore, RecordingAdapter;

class VerificationApi extends Api {
  final calls = <Map<String, dynamic>>[];
  bool available = true,
      unknown = false,
      failBegin = false,
      invalidCode = false,
      finalConflict = false,
      failConfirm = false,
      failAttemptRefresh = false;
  List<Json> saved = [];
  String state = 'AWAITING_CODE';
  Completer<dynamic>? beginWait;
  VerificationApi() : super(store: MemoryStore(), intents: MemoryStore());
  Json proof() => {
    'id': 'proof',
    'status': state,
    'expiresAt': DateTime.now()
        .add(const Duration(minutes: 10))
        .toIso8601String(),
    'bankName': '테스트 은행',
    'accountMasked': '***1234',
    'attemptsRemaining': invalidCode ? 0 : 5,
  };
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Json? body,
    String? key,
  }) async {
    calls.add({'method': method, 'path': path, 'body': body, 'key': key});
    if (path == '/me/bank-account') {
      if (method == 'POST' && finalConflict) {
        throw const ApiFailure(409, 'STALE_VERSION');
      }
      return {
        'registered': true,
        'version': 4,
        'bankName': '기존 은행',
        'accountMasked': '***9999',
        'holderMasked': '김*',
        'verifiedAt': DateTime.now().toIso8601String(),
      };
    }
    if (path.endsWith('/banks')) {
      return {
        'available': available,
        'banks': [
          {'id': 'bank', 'name': '테스트 은행'},
        ],
      };
    }
    if (path == '/clubs/club') {
      return {'version': 2, 'role': 'OWNER', 'status': 'ACTIVE'};
    }
    if (path == '/clubs/club/reserve') {
      return {
        'version': 3,
        'balance': 0,
        'available': 0,
        'unbackedAmount': 0,
        'names': {},
        'entries': [],
        'custodianId': 'other',
        'bankName': '은행',
        'maskedAccount': '***',
      };
    }
    if (method == 'GET' && path.contains('?')) return saved;
    if (method == 'GET') {
      if (failAttemptRefresh && state == 'LOCKED') {
        throw const ApiFailure(null, 'NETWORK_UNAVAILABLE');
      }
      return proof();
    }
    if (path.endsWith('/confirm')) {
      if (failConfirm) {
        failConfirm = false;
        state = 'VERIFIED';
        throw const ApiFailure(null, 'NETWORK_UNAVAILABLE');
      }
      if (invalidCode) {
        state = 'LOCKED';
        throw const ApiFailure(400, 'BANK_VERIFICATION_LOCKED');
      }
      state = 'VERIFIED';
      return proof();
    }
    if (beginWait != null) return beginWait!.future;
    if (failBegin) {
      failBegin = false;
      throw const ApiFailure(null, 'NETWORK_UNAVAILABLE');
    }
    if (unknown) state = 'UNKNOWN';
    return proof();
  }
}

class BlockingBankIntent extends MemoryStore {
  final entered = Completer<void>(), release = Completer<void>();
  bool hold = true;
  @override
  Future<void> write(String? text) async {
    if (hold && text != null) {
      hold = false;
      entered.complete();
      await release.future;
    }
    value = text;
  }
}

Future<void> open(
  WidgetTester t,
  VerificationApi a,
  void Function(Json?) done, {
  String purpose = 'PERSONAL',
  String? contextId,
}) async {
  await a.saveSession({
    'token': 'a',
    'scope': 'ACTIVE',
    'userId': 'u',
    'expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
  });
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () async => done(
              await verifyBankAccount(
                c,
                a,
                purpose: purpose,
                contextId: contextId,
              ),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('열기'));
  await t.pumpAndSettle();
}

Future<void> details(WidgetTester t) async {
  await t.tap(find.text('은행 선택'));
  await t.pumpAndSettle();
  await t.tap(find.text('테스트 은행').last);
  await t.pumpAndSettle();
  await t.enterText(find.widgetWithText(TextFormField, '계좌번호'), '1234');
  await t.enterText(find.widgetWithText(TextFormField, '예금주명'), '홍길동');
  await t.enterText(
    find.widgetWithText(TextFormField, '생년월일 6자리 (YYMMDD)'),
    '900101',
  );
}

void main() {
  testWidgets('two stages bind context and never persist DOB or code', (
    t,
  ) async {
    final a = VerificationApi();
    Json? result;
    await open(t, a, (v) => result = v, purpose: 'RESERVE', contextId: 'club');
    await details(t);
    await t.tap(find.text('1원 인증 요청'));
    await t.pumpAndSettle();
    expect(find.text('인증번호 4자리'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextFormField, '인증번호 4자리'), '1234');
    await t.tap(find.text('인증번호 확인'));
    await t.pumpAndSettle();
    expect(result, isNull);
    await t.tap(find.text('이 계좌로 등록 계속'));
    await t.pumpAndSettle();
    expect(result, {
      'bankName': '테스트 은행',
      'accountNumber': '1234',
      'holderName': '홍길동',
      'verificationId': 'proof',
    });
    final begin = a.calls.firstWhere((c) => c['method'] == 'POST');
    expect(begin['body']['purpose'], 'RESERVE');
    expect(begin['body']['contextId'], 'club');
    expect((a.intents as MemoryStore).value, isNull);
    expect(result!.containsKey('identity'), isFalse);
  });
  testWidgets('disabled provider offers no demo approval', (t) async {
    final a = VerificationApi()..available = false;
    await open(t, a, (_) {});
    expect(find.textContaining('계좌 인증을 이용할 수 없습니다'), findsOneWidget);
    expect(find.text('1원 인증 요청'), findsNothing);
  });
  testWidgets(
    'ambiguous begin retries exact key and never automatically begins twice',
    (t) async {
      final a = VerificationApi()..failBegin = true;
      await open(t, a, (_) {});
      await details(t);
      await t.tap(find.text('1원 인증 요청'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('같은 요청 다시 확인'));
      await t.pumpAndSettle();
      await t.tap(find.text('같은 요청 다시 확인'));
      await t.pumpAndSettle();
      final posts = a.calls.where((c) => c['method'] == 'POST').toList();
      expect(posts.length, 2);
      expect(posts[0]['key'], posts[1]['key']);
      expect(posts[0]['body'], posts[1]['body']);
      expect((a.intents as MemoryStore).value, isNull);
    },
  );
  testWidgets('UNKNOWN only allows status lookup no new transfer', (t) async {
    final a = VerificationApi()..unknown = true;
    await open(t, a, (_) {});
    await details(t);
    await t.tap(find.text('1원 인증 요청'));
    await t.pumpAndSettle();
    expect(find.textContaining('결과 미확인'), findsOneWidget);
    expect(find.text('1원 인증 요청'), findsNothing);
    await t.tap(find.text('인증 상태 다시 조회'));
    await t.pumpAndSettle();
    expect(a.calls.where((c) => c['method'] == 'POST').length, 1);
  });
  testWidgets('invalid final code reloads lock and cannot approve', (t) async {
    final a = VerificationApi()..invalidCode = true;
    await open(t, a, (_) {});
    await details(t);
    await t.tap(find.text('1원 인증 요청'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, '인증번호 4자리'), '0000');
    await t.tap(find.text('인증번호 확인'));
    await t.pumpAndSettle();
    expect(find.textContaining('시도 횟수'), findsWidgets);
    expect(find.text('이 계좌로 등록 계속'), findsNothing);
  });
  testWidgets('route reentry loads proof without another begin', (t) async {
    final a = VerificationApi()..state = 'VERIFIED';
    a.saved = [a.proof()];
    await open(t, a, (_) {});
    await t.tap(find.textContaining('이전 인증 선택'));
    await t.pumpAndSettle();
    expect(find.textContaining('계좌번호와 예금주를 다시 입력'), findsOneWidget);
    expect(a.calls.where((c) => c['method'] == 'POST'), isEmpty);
  });
  testWidgets('late response after session switch cannot return proof', (
    t,
  ) async {
    final a = VerificationApi()..beginWait = Completer();
    Json? result;
    await open(t, a, (v) => result = v);
    await details(t);
    await t.tap(find.text('1원 인증 요청'));
    await t.pump();
    await a.clearSession();
    a.beginWait!.complete(a.proof());
    await t.pumpAndSettle();
    expect(result, isNull);
    expect(find.textContaining('로그인 계정이 변경'), findsOneWidget);
    expect(find.text('이 계좌로 등록 계속'), findsNothing);
  });
  testWidgets(
    'personal final stale write keeps old account and proof available',
    (t) async {
      final a = VerificationApi()
        ..state = 'VERIFIED'
        ..finalConflict = true;
      a.saved = [a.proof()];
      await a.saveSession({
        'token': 'a',
        'scope': 'ACTIVE',
        'userId': 'u',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(a)],
          child: const MaterialApp(home: Scaffold(body: BankAccountPanel())),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('계좌 변경·다시 확인'));
      await t.pumpAndSettle();
      expect(find.textContaining('이전 인증 선택'), findsOneWidget);
      await t.tap(find.textContaining('이전 인증 선택'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, '계좌번호'), '1234');
      await t.enterText(find.widgetWithText(TextFormField, '예금주명'), '홍길동');
      await t.tap(find.text('이 계좌로 등록 계속'));
      await t.pumpAndSettle();
      await t.tap(find.text('확인하고 요청'));
      await t.pumpAndSettle();
      expect(find.text('최신 자료 다시 불러오기'), findsOneWidget);
      expect(find.textContaining('기존 은행'), findsOneWidget);
      final write = a.calls.lastWhere((c) => c['method'] == 'POST');
      expect(write['body']['version'], 4);
      expect(write['body']['verificationId'], 'proof');
      expect(write['body'].containsKey('identity'), isFalse);
      await t.tap(find.text('최신 자료 다시 불러오기'));
      await t.pumpAndSettle();
      await t.tap(find.text('계좌 변경·다시 확인'));
      await t.pumpAndSettle();
      expect(find.textContaining('이전 인증 선택'), findsOneWidget);
    },
  );
  testWidgets(
    'confirm timeout can resolve by status lookup without another POST',
    (t) async {
      final a = VerificationApi()..failConfirm = true;
      await open(t, a, (_) {});
      await details(t);
      await t.tap(find.text('1원 인증 요청'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, '인증번호 4자리'), '1234');
      await t.tap(find.text('인증번호 확인'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('인증 상태 다시 조회'));
      await t.tap(find.text('인증 상태 다시 조회'));
      await t.pumpAndSettle();
      expect(find.text('이 계좌로 등록 계속'), findsOneWidget);
      expect(a.calls.where((c) => c['method'] == 'POST').length, 2);
    },
  );
  testWidgets(
    'reserve settings and custodian confirm use exact scoped verification',
    (t) async {
      final a = VerificationApi();
      await a.saveSession({
        'token': 'a',
        'scope': 'ACTIVE',
        'userId': 'u',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(a)],
          child: const MaterialApp(
            home: Scaffold(body: ReserveScreen(id: 'club')),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('보관 계좌 설정'));
      await t.tap(find.text('보관 계좌 설정'));
      await t.pumpAndSettle();
      expect(
        a.calls.any(
          (c) =>
              c['path'] == '/bank-verifications?purpose=RESERVE&contextId=club',
        ),
        isTrue,
      );
      await t.tap(find.text('닫기'));
      await t.pumpAndSettle();
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(a)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HandoverReview(
                  handover: const {
                    'id': 'handover',
                    'candidateId': 'u',
                    'proposerId': 'p',
                    'version': 4,
                    'status': 'ACCEPTED',
                    'inventoryAmount': 0,
                    'inventory': {},
                    'returns': [],
                  },
                  reload: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('실제 수령·0원 인계 확인'));
      await t.pumpAndSettle();
      expect(
        a.calls.any(
          (c) =>
              c['path'] ==
              '/bank-verifications?purpose=RESERVE_HANDOVER&contextId=handover',
        ),
        isTrue,
      );
    },
  );
  testWidgets('expired previous proof cannot continue registration', (t) async {
    final a = VerificationApi()..state = 'EXPIRED';
    a.saved = [a.proof()];
    await open(t, a, (_) {});
    await t.tap(find.textContaining('이전 인증 선택'));
    await t.pumpAndSettle();
    expect(find.textContaining('유효 시간이 지났습니다'), findsOneWidget);
    expect(find.text('이 계좌로 등록 계속'), findsNothing);
    expect(a.calls.where((c) => c['method'] == 'POST'), isEmpty);
  });
  testWidgets('verification remains scrollable at narrow 200 percent text', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final a = VerificationApi();
    await open(t, a, (_) {});
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.text('1원 인증 요청'));
    expect(find.text('1원 인증 요청'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'unknown attempt count after invalid code blocks another submission until GET succeeds',
    (t) async {
      final a = VerificationApi()
        ..invalidCode = true
        ..failAttemptRefresh = true;
      await open(t, a, (_) {});
      await details(t);
      await t.tap(find.text('1원 인증 요청'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, '인증번호 4자리'), '0000');
      await t.tap(find.text('인증번호 확인'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, '인증번호 확인'))
            .onPressed,
        isNull,
      );
      a.failAttemptRefresh = false;
      await t.ensureVisible(find.text('인증 상태 다시 조회'));
      await t.tap(find.text('인증 상태 다시 조회'));
      await t.pumpAndSettle();
      expect(find.textContaining('시도 횟수'), findsWidgets);
      expect(find.text('인증번호 확인'), findsNothing);
    },
  );
  testWidgets(
    'final bank submit stays bound to the actor who completed verification',
    (t) async {
      final a = VerificationApi()..state = 'VERIFIED';
      a.saved = [a.proof()];
      await a.saveSession({
        'token': 'a',
        'scope': 'ACTIVE',
        'userId': 'u',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(a)],
          child: const MaterialApp(home: Scaffold(body: BankAccountPanel())),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('계좌 변경·다시 확인'));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('이전 인증 선택'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, '계좌번호'), '1234');
      await t.enterText(find.widgetWithText(TextFormField, '예금주명'), '홍길동');
      await t.tap(find.text('이 계좌로 등록 계속'));
      await t.pumpAndSettle();
      await a.clearSession();
      await a.saveSession({
        'token': 'b',
        'scope': 'ACTIVE',
        'userId': 'other',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      await t.tap(find.text('확인하고 요청'));
      await t.pumpAndSettle();
      expect(a.calls.where((c) => c['method'] == 'POST'), isEmpty);
      expect((a.intents as MemoryStore).value, isNull);
    },
  );
  test(
    'owner-bound final command cannot cross a session change while journal persistence waits',
    () async {
      final journal = BlockingBankIntent(), adapter = RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
        ..httpClientAdapter = adapter;
      final a = Api(dio: dio, store: MemoryStore(), intents: journal);
      await a.saveSession({
        'token': 'a',
        'scope': 'ACTIVE',
        'userId': 'u',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      final sending = verifiedBankCommandApi(a, 'a').send(
        Command('/me/bank-account', {
          'version': 4,
          'bankName': '은행',
          'accountNumber': '1234',
          'holderName': '홍길동',
          'verificationId': 'proof',
        }),
      );
      final observed = expectLater(
        sending,
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
        ),
      );
      await journal.entered.future;
      await a.clearSession();
      await a.saveSession({
        'token': 'b',
        'scope': 'ACTIVE',
        'userId': 'other',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      journal.release.complete();
      await observed;
      expect(adapter.requests, isEmpty);
      expect(journal.value, '[]');
    },
  );
}
