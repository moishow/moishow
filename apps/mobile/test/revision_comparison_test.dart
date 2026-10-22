import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/revision_comparison.dart';
import 'package:moishow/theme.dart';
import 'package:moishow/widgets.dart' show formatTimestamp;

Json position(
  String id, {
  int obligation = 30000,
  int received = 30000,
  int refunded = 0,
  int net = 0,
  int additional = 0,
  int refund = 0,
}) => {
  'userId': id,
  'obligation': obligation,
  'received': received,
  'refunded': refunded,
  'net': net,
  'additional': additional,
  'refund': refund,
};

Json revision(List<Json> before, List<Json>? after) => {
  'reason': '중복 영수증 정정',
  'createdAt': '2026-10-22T10:30:00Z',
  'snapshot': jsonEncode({'positions': before}),
  'afterSnapshot': after == null ? null : jsonEncode({'positions': after}),
};

Future<void> mount(
  WidgetTester tester,
  Json value, {
  String Function(dynamic)? nameOf,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: Tokens.theme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: RevisionComparison(
            revision: value,
            nameOf:
                nameOf ??
                (id) => {'me': '산책', 'new': '새 참여자', 'old': '이전 참여자'}[id]!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows preserved thirty thousand before and twenty five thousand after with reason and local time',
    (tester) async {
      final data = revision(
        [position('me')],
        [position('me', obligation: 25000, net: -5000, refund: 5000)],
      );
      final preserved = jsonEncode(data);
      await mount(tester, data);
      expect(find.text('중복 영수증 정정'), findsOneWidget);
      expect(
        find.text('기록 시각 ${formatTimestamp(data['createdAt'])}'),
        findsOneWidget,
      );
      expect(find.text('산책'), findsOneWidget);
      expect(find.text('원본 · 개인 부담 30,000원'), findsOneWidget);
      expect(find.text('정정 후 · 개인 부담 25,000원'), findsOneWidget);
      expect(find.text('원본 · 확인 입금 30,000원'), findsOneWidget);
      expect(find.text('정정 후 · 일반 환불 5,000원'), findsOneWidget);
      expect(jsonEncode(data), preserved);
    },
  );

  testWidgets(
    'signed net is kept separate from canonical ordinary refund and no delta is calculated',
    (tester) async {
      await mount(
        tester,
        revision(
          [
            position(
              'me',
              obligation: 10000,
              received: 0,
              net: 5000,
              additional: 5000,
            ),
          ],
          [position('me', obligation: 10000, received: 0, net: -7000)],
        ),
      );
      expect(find.text('원본 · 순차액 5,000원'), findsOneWidget);
      expect(find.text('정정 후 · 순차액 -7,000원'), findsOneWidget);
      expect(find.text('정정 후 · 일반 환불 0원'), findsOneWidget);
      expect(find.textContaining('12,000'), findsNothing);
      expect(find.textContaining('선지출'), findsWidgets);
      expect(find.text('정정 후 · 일반 환불 7,000원'), findsNothing);
    },
  );

  testWidgets(
    'a user absent on either side is a missing record rather than zero money',
    (tester) async {
      await mount(
        tester,
        revision([position('old')], [position('new', obligation: 25000)]),
      );
      expect(find.text('이전 참여자'), findsOneWidget);
      expect(find.text('새 참여자'), findsOneWidget);
      expect(find.text('원본 · 개인 부담 기록 없음'), findsOneWidget);
      expect(find.text('정정 후 · 개인 부담 기록 없음'), findsOneWidget);
      expect(find.text('원본 · 개인 부담 0원'), findsNothing);
      expect(find.text('정정 후 · 개인 부담 0원'), findsNothing);
    },
  );

  testWidgets(
    'null after snapshot is explicit and does not use any current finance values',
    (tester) async {
      final data = revision([position('me')], null);
      data['currentFinance'] = {
        'positions': [position('me', obligation: 123456)],
      };
      await mount(tester, data);
      expect(find.text('정정 후 보존 자료가 없습니다.'), findsOneWidget);
      expect(find.text('원본 · 개인 부담 30,000원'), findsOneWidget);
      expect(find.text('정정 후 · 개인 부담 보존 자료 없음'), findsOneWidget);
      expect(find.textContaining('123,456'), findsNothing);
    },
  );

  testWidgets(
    'missing or fractional money stays unknown and a malformed snapshot does not become zero',
    (tester) async {
      final before = position('me')..remove('received');
      final after = position('me')..['refund'] = 1.5;
      await mount(tester, revision([before], [after]));
      expect(find.text('원본 · 확인 입금 금액 확인 필요'), findsOneWidget);
      expect(find.text('정정 후 · 일반 환불 금액 확인 필요'), findsOneWidget);
      expect(find.text('원본 · 확인 입금 0원'), findsNothing);
      expect(find.text('정정 후 · 일반 환불 0원'), findsNothing);
      final malformed = revision([position('me')], [position('me')])
        ..['snapshot'] = '{broken';
      await mount(tester, malformed);
      expect(find.text('원본 보존 자료 형식을 확인해주세요.'), findsOneWidget);
      expect(find.text('원본 · 개인 부담 자료 확인 필요'), findsOneWidget);
      expect(find.text('정정 후 · 개인 부담 30,000원'), findsOneWidget);
    },
  );

  testWidgets(
    'only users actually present in supplied server snapshots are named or displayed',
    (tester) async {
      final called = <dynamic>[];
      await mount(
        tester,
        revision([position('me')], [position('me', obligation: 25000)]),
        nameOf: (id) {
          called.add(id);
          return {'me': '탈퇴한 산책', 'unrelated': '다른 모임 부원'}[id]!;
        },
      );
      expect(called, ['me']);
      expect(find.text('탈퇴한 산책'), findsOneWidget);
      expect(find.text('다른 모임 부원'), findsNothing);
    },
  );

  testWidgets(
    'before and after amounts wrap without overflow at 320 width and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(
        tester,
        revision(
          [position('me', obligation: maxKrw)],
          [position('me', net: -maxKrw)],
        ),
      );
      await tester.ensureVisible(
        find.text('정정 후 · 순차액 -9,007,199,254,740,991원'),
      );
      expect(find.text('원본 · 개인 부담 9,007,199,254,740,991원'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
