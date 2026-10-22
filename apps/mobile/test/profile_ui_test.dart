import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'api_test.dart' show MemoryStore;
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/profile_screen.dart';

class ProfileApi extends Api {
  Command? command;
  ProfileApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> send(Command c) async {
    command = c;
    return {};
  }
}

void main() {
  testWidgets(
    'detaching profile photo sends explicit clear instead of an empty file reference',
    (t) async {
      final api = ProfileApi();
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileFields(
                  data: const {
                    'version': 0,
                    'nickname': '산책',
                    'interests': [],
                    'bio': '',
                    'avatarFileId': 'photo',
                  },
                  setup: false,
                  reload: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('첨부 해제'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('프로필 저장'));
      await t.tap(find.text('프로필 저장'));
      await t.pumpAndSettle();
      expect(api.command?.body['clearAvatar'], true);
      expect(api.command?.body.containsKey('avatarFileId'), false);
    },
  );
  test(
    'optional interests normalize as ordered unique labels and preserve Korean text',
    () {
      expect(normalizeInterests(' 산책 ,운동, 산책, 여행 '), ['산책', '운동', '여행']);
      expect(normalizeInterests(''), isEmpty);
      expect(() => normalizeInterests('가' * 31), throwsFormatException);
      expect(
        () => normalizeInterests(List.generate(21, (i) => '관심$i').join(',')),
        throwsFormatException,
      );
    },
  );
}
