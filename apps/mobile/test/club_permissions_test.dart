import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/main.dart';
import 'package:moishow/screens.dart';
import 'mobile_flow_test.dart' show FlowApi;

class ClubApi extends FlowApi {
  final bool dissolved;
  ClubApi({this.dissolved = false});
  @override
  Future<dynamic> get(String p) async {
    if (p == '/clubs/c') {
      return {
        'id': 'c',
        'version': 1,
        'name': '산책',
        'joinMode': 'IMMEDIATE',
        'membershipStatus': 'ACTIVE',
        'role': 'ADMIN',
        'status': dissolved ? 'DISSOLVED' : 'ACTIVE',
      };
    }
    if (p.endsWith('/members')) {
      return [
        {
          'userId': 'other-admin',
          'nickname': '다른 관리자',
          'role': 'ADMIN',
          'status': 'ACTIVE',
        },
        {
          'userId': 'member',
          'nickname': '부원',
          'role': 'MEMBER',
          'status': 'ACTIVE',
        },
      ];
    }
    return [];
  }
}

void main() {
  testWidgets(
    'dissolved membership keeps financial history but cannot create events',
    (t) async {
      final api = ClubApi(dissolved: true);
      await api.saveSession({
        'token': 'test',
        'scope': 'ACTIVE',
        'userId': 'admin',
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
      expect(find.text('정모·번개 만들기'), findsNothing);
      expect(find.text('모임 적립금'), findsOneWidget);
    },
  );
}
