import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/club_invitation.dart';
import 'api_test.dart' show MemoryStore;

class InviteApi extends Api {
  InviteApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> send(Command c) async => {
    'inviteToken': 'TEST-INVITE',
    'expiresAt': '2026-10-29T00:00:00Z',
    'version': 4,
  };
}

void main() {
  testWidgets(
    'club invitation retains actual result for review and explicit copying',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClubInvitation(
              api: InviteApi(),
              clubId: 'c',
              version: 3,
              reload: () {},
            ),
          ),
        ),
      );
      await t.tap(find.text('초대 토큰 생성'));
      await t.pumpAndSettle();
      expect(find.text('TEST-INVITE'), findsOneWidget);
      expect(find.text('초대 토큰 복사'), findsOneWidget);
    },
  );
}
