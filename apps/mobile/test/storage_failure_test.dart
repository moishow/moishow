import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'api_test.dart' show MemoryStore;

class FailingStore implements TokenStore {
  final bool onRead;
  FailingStore(this.onRead);
  @override
  Future<String?> read() async {
    if (onRead) throw StateError('fixture storage read failure');
    return null;
  }

  @override
  Future<void> write(String? v) async {
    if (!onRead) throw StateError('fixture storage write failure');
  }
}

void main() {
  test('logout still notifies routing when secure deletion fails', () async {
    final api = Api(store: FailingStore(false), intents: MemoryStore());
    api.session = Session({
      'token': 'test',
      'scope': 'ACTIVE',
      'userId': 'u',
      'expiresAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    });
    bool notified = false;
    api.onSessionChanged = () => notified = true;
    await expectLater(api.clearSession(), throwsA(anything));
    expect(api.session, isNull);
    expect(notified, true);
  });

  test(
    'storage restoration failure returns to login instead of a blank crashed app',
    () async {
      final api = Api(store: FailingStore(true), intents: MemoryStore());
      await expectLater(api.restore(), completes);
      expect(api.session, isNull);
    },
  );
  test(
    'failed secure session write does not activate an unstored session',
    () async {
      final api = Api(store: FailingStore(false), intents: MemoryStore());
      await expectLater(
        api.saveSession({
          'token': 'server-issued',
          'scope': 'ACTIVE',
          'userId': 'u',
          'expiresAt': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        }),
        throwsA(anything),
      );
      expect(api.session, isNull);
    },
  );
}
