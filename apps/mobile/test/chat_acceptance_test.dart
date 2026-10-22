import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/chat_lists.dart';
import 'mobile_flow_test.dart' show FlowApi;

class InviteApi extends FlowApi {
  bool accepted = false;
  @override
  Future<dynamic> get(String path) async {
    if (path.startsWith('/chat/rooms')) {
      return accepted
          ? [
              {
                'id': 'g',
                'title': '수락한 그룹',
                'kind': 'GROUP_DM',
                'lastMessage': '',
              },
            ]
          : [];
    }
    if (path.startsWith('/chat/invitations')) {
      return accepted
          ? []
          : [
              {'id': 'g', 'title': '초대 그룹', 'inviterNickname': '이웃'},
            ];
    }
    return [];
  }

  @override
  Future<dynamic> send(Command command) async {
    accepted = true;
    return {};
  }
}

void main() {
  testWidgets('accepting a group invite immediately refreshes joined rooms', (
    t,
  ) async {
    t.view.physicalSize = const Size(800, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final api = InviteApi();
    await t.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: Scaffold(body: ChatScreen())),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(PopupMenuButton<String>));
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('수락'));
    await t.pumpAndSettle();
    await t.tap(find.text('확인하고 요청'));
    await t.pumpAndSettle();
    expect(find.text('수락한 그룹'), findsOneWidget);
    expect(find.text('초대 그룹'), findsNothing);
  });
}
