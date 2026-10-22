import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moishow/api.dart';
import 'package:moishow/history_panel.dart';
import 'package:moishow/main.dart';
import 'package:moishow/theme.dart';
import 'api_test.dart' show MemoryStore;

class HistoryHttp implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final List<Json> events;
  Json finance;
  bool failNextPage = false;
  Completer<ResponseBody>? holdFinance;
  HistoryHttp({required this.events, required this.finance});

  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    if (request.path.startsWith('/me/history')) {
      final offset = int.parse(request.uri.queryParameters['offset']!);
      final limit = int.parse(request.uri.queryParameters['limit']!);
      if (offset > 0 && failNextPage) {
        failNextPage = false;
        return response({'code': 'TEST_PAGE_FAILURE'}, 503);
      }
      return response(events.skip(offset).take(limit).toList());
    }
    if (request.path == '/events/event-0/finance') {
      final pending = holdFinance;
      holdFinance = null;
      return pending == null ? response(finance) : pending.future;
    }
    return response({'code': 'UNEXPECTED_TEST_REQUEST'}, 404);
  }

  ResponseBody response(Object value, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: {
          'content-type': ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

Json personalPosition(String user, {int amount = 30000}) => {
  'userId': user,
  'obligation': amount,
  'deposits': 40000,
  'ordinaryRefunded': 0,
  'personalExpense': 0,
  'advanceRecovered': 0,
  'additional': 0,
  'ordinaryRefundDue': 10000,
  'advanceDue': 0,
};

Json finance({bool ready = true, List<Json>? positions}) => {
  'status': 'CLOSED',
  'firstRegisteredAt': '2026-10-20T10:00:00Z',
  'names': {
    'me': {'nickname': '산책', 'departed': true},
    'other': {'nickname': '다른 부원', 'departed': false},
  },
  'funding': {
    'ready': ready,
    'positions':
        positions ??
        [personalPosition('other', amount: 987654), personalPosition('me')],
  },
};

List<Json> events(int count) => List.generate(
  count,
  (i) => {'eventId': 'event-$i', 'title': '지난 모임 $i', 'status': 'CLOSED'},
);

Future<Api> apiFor(HistoryHttp adapter) async {
  final api = Api(
    dio: Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter,
    store: MemoryStore(),
    intents: MemoryStore(),
  );
  await api.saveSession({
    'token': 'history-test-session',
    'scope': 'ACTIVE',
    'userId': 'me',
    'expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
  });
  return api;
}

Future<void> mount(WidgetTester tester, Api api) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: SingleChildScrollView(child: HistoryPanel())),
      ),
      GoRoute(
        path: '/events/:id/finance',
        builder: (_, state) =>
            Scaffold(body: Text('원본 정산 ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiProvider.overrideWithValue(api)],
      child: MaterialApp.router(theme: Tokens.theme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'loads twenty history rows at a time without eagerly loading event finance',
    (tester) async {
      final adapter = HistoryHttp(events: events(21), finance: finance());
      await mount(tester, await apiFor(adapter));
      expect(adapter.requests.length, 1);
      expect(adapter.requests.single.uri.queryParameters, {
        'offset': '0',
        'limit': '20',
      });
      expect(find.text('지난 모임 19'), findsOneWidget);
      expect(find.text('지난 모임 20'), findsNothing);
      await tester.ensureVisible(find.text('정산 내역 더 보기'));
      await tester.tap(find.text('정산 내역 더 보기'));
      await tester.pumpAndSettle();
      expect(adapter.requests.length, 2);
      expect(adapter.requests.last.uri.queryParameters, {
        'offset': '20',
        'limit': '20',
      });
      expect(find.text('지난 모임 20'), findsOneWidget);
      expect(find.text('정산 내역 더 보기'), findsNothing);
      expect(adapter.requests.every((r) => r.method == 'GET'), true);
    },
  );

  testWidgets(
    'expansion shows only canonical own money and keeps departed records and original route',
    (tester) async {
      final adapter = HistoryHttp(events: events(1), finance: finance());
      await mount(tester, await apiFor(adapter));
      await tester.tap(find.text('지난 모임 0'));
      await tester.pumpAndSettle();
      expect(adapter.requests.last.path, '/events/event-0/finance');
      expect(find.text('산책 · 탈퇴한 멤버'), findsOneWidget);
      expect(find.text('최종 개인 부담 30,000원'), findsOneWidget);
      expect(find.text('확인 입금 40,000원'), findsOneWidget);
      expect(find.text('일반 환불 10,000원'), findsOneWidget);
      expect(find.textContaining('987,654'), findsNothing);
      expect(find.textContaining('미납·환불·이의'), findsWidgets);
      await tester.ensureVisible(find.text('계산 근거·정정·이의 기록'));
      await tester.tap(find.text('계산 근거·정정·이의 기록'));
      await tester.pumpAndSettle();
      expect(find.text('원본 정산 event-0'), findsOneWidget);
    },
  );

  testWidgets(
    'missing money is a visible contract failure instead of a zero amount',
    (tester) async {
      final own = personalPosition('me')..remove('deposits');
      final adapter = HistoryHttp(
        events: events(1),
        finance: finance(positions: [own]),
      );
      await mount(tester, await apiFor(adapter));
      await tester.tap(find.text('지난 모임 0'));
      await tester.pumpAndSettle();
      expect(find.textContaining('서버 자료 형식'), findsOneWidget);
      expect(find.text('확인 입금 0원'), findsNothing);
      expect(find.text('계산 근거·정정·이의 기록'), findsOneWidget);
    },
  );

  testWidgets(
    'unready funding and manager without own position never borrow another person money',
    (tester) async {
      final adapter = HistoryHttp(
        events: events(1),
        finance: finance(ready: false),
      );
      await mount(tester, await apiFor(adapter));
      await tester.tap(find.text('지난 모임 0'));
      await tester.pumpAndSettle();
      expect(find.textContaining('자금 출처 분류'), findsOneWidget);
      expect(find.textContaining('최종 개인 부담'), findsNothing);
      adapter.finance = finance(positions: [personalPosition('other')]);
      await tester.tap(find.text('금액 다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('개인 부담 대상이 아닌 담당 기록입니다.'), findsOneWidget);
      expect(find.textContaining('최종 개인 부담'), findsNothing);
      expect(find.text('계산 근거·정정·이의 기록'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed later page preserves loaded records and retries the same offset',
    (tester) async {
      final adapter = HistoryHttp(events: events(21), finance: finance())
        ..failNextPage = true;
      await mount(tester, await apiFor(adapter));
      await tester.ensureVisible(find.text('정산 내역 더 보기'));
      await tester.tap(find.text('정산 내역 더 보기'));
      await tester.pumpAndSettle();
      expect(find.text('지난 모임 0'), findsOneWidget);
      await tester.ensureVisible(find.text('목록 다시 불러오기'));
      await tester.tap(find.text('목록 다시 불러오기'));
      await tester.pumpAndSettle();
      expect(
        adapter.requests.map((r) => r.uri.queryParameters['offset']).toList(),
        ['0', '20', '20'],
      );
      expect(find.text('지난 모임 20'), findsOneWidget);
    },
  );

  testWidgets(
    'late personal money from a previous session cannot populate the next account',
    (tester) async {
      final pending = Completer<ResponseBody>();
      final adapter = HistoryHttp(events: events(1), finance: finance())
        ..holdFinance = pending;
      final api = await apiFor(adapter);
      await mount(tester, api);
      await tester.tap(find.text('지난 모임 0'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(adapter.requests.last.path, '/events/event-0/finance');
      await api.saveSession({
        'token': 'different-history-session',
        'scope': 'ACTIVE',
        'userId': 'next-person',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      adapter.events.clear();
      await mount(tester, api);
      pending.complete(adapter.response(finance()));
      await tester.pumpAndSettle();
      expect(find.text('지난 정산 내역이 없어요.'), findsOneWidget);
      expect(find.text('산책 · 탈퇴한 멤버'), findsNothing);
      expect(find.textContaining('최종 개인 부담'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history summary and original action remain reachable on a small screen at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final adapter = HistoryHttp(events: events(1), finance: finance());
      await mount(tester, await apiFor(adapter));
      await tester.ensureVisible(find.text('지난 모임 0'));
      await tester.tap(find.text('지난 모임 0'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('계산 근거·정정·이의 기록'));
      expect(find.text('최종 개인 부담 30,000원'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
