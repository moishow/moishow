import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/main.dart';
import 'package:moishow/screens.dart';
import 'mobile_flow_test.dart' show ConsentApi;

class LevelApi extends ConsentApi {
  final String nickname;
  final paths = <String>[];
  LevelApi(this.nickname);
  @override
  Future<dynamic> get(String p) async {
    paths.add(p);
    if (p == '/clubs/c') {
      return {
        'id': 'c',
        'name': '모임',
        'version': 1,
        'status': 'ACTIVE',
        'role': 'MEMBER',
        'membershipStatus': 'ACTIVE',
        'joinMode': 'IMMEDIATE',
      };
    }
    if (p == '/clubs/c/members') {
      return [
        {'userId': 'other', 'nickname': '같은 모임 부원', 'role': 'MEMBER'},
      ];
    }
    if (p.contains('/levels/')) {
      return {
        'score': 52,
        'historyLabel': '참여 이력',
        'history': [
          {
            'role': 'PARTICIPANT',
            'outcome': 'ON_TIME',
            'delta': 1,
            'reason': '실제 입금 확인',
          },
        ],
      };
    }
    if (p.endsWith('/join-history') || p.endsWith('/request-history')) {
      return [];
    }
    return super.get(p);
  }
}

void main() {
  for (final role in ['공개 번개 비부원', '탈퇴한 참가자']) {
    testWidgets(
      '$role can open own activity level only from an authorized existing event',
      (t) async {
        final api = LevelApi(role);
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
        expect(find.text('이 모임의 내 활동 레벨'), findsOneWidget);
        await t.tap(find.text('이 모임의 내 활동 레벨'));
        await t.pumpAndSettle();
        expect(find.textContaining('52점'), findsOneWidget);
        expect(api.paths, contains('/clubs/club/levels/u'));
      },
    );
  }
  testWidgets(
    'same club member row opens that exact known member level without a user directory',
    (t) async {
      final api = LevelApi('모임 부원');
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
            home: Scaffold(body: ClubScreen(id: 'c')),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('같은 모임 부원'));
      await t.pumpAndSettle();
      await t.tap(find.text('같은 모임 부원'));
      await t.pumpAndSettle();
      expect(find.textContaining('52점'), findsOneWidget);
      expect(api.paths, contains('/clubs/c/levels/other'));
    },
  );
}
