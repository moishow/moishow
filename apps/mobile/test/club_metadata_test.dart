import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/club_editor.dart';
import 'api_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'club composer exposes original optional metadata and actual protected image selection',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClubEditor(
              api: Api(store: MemoryStore(), intents: MemoryStore()),
              onDone: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('모임 소개 (선택)'), findsOneWidget);
      expect(find.text('지역 (선택)'), findsOneWidget);
      expect(find.text('분류 (선택)'), findsOneWidget);
      expect(find.text('사진 선택'), findsOneWidget);
    },
  );
}
