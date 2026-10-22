import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/community_widgets.dart';
import 'api_test.dart' show MemoryStore;

class FeedApi extends Api {
  final commands = <Command>[];
  FeedApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String path) async {
    if (path.contains('/comments')) return [];
    final post = {
      'id': 'post',
      'userId': 'author',
      'nickname': '산책 이웃',
      'kind': 'POST',
      'body': '같이 걸어요',
      'version': 2,
      'status': 'ACTIVE',
      'createdAt': '2026-10-22T00:00:00Z',
      'photoIds': [],
      'likeCount': 2,
      'liked': false,
      'clubId': null,
    };
    return path.split('?').first == '/feed/posts' ? [post] : post;
  }

  @override
  Future<dynamic> send(Command command) async {
    commands.add(command);
    return {'ok': true};
  }
}

void main() {
  testWidgets(
    'post interactions include real reactions and exact reported content',
    (tester) async {
      final api = FeedApi();
      await api.saveSession({
        'token': 'test-only',
        'scope': 'ACTIVE',
        'userId': 'viewer',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: Feed())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('좋아요 2'), findsOneWidget);
    },
  );
}
