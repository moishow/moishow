import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/push.dart';
import 'api_test.dart' show MemoryStore;

void main() {
  test(
    'duplicate provider notification IDs are displayed once across restart',
    () async {
      final store = MemoryStore();
      final first = PushReceipts(store);
      expect(await first.accept('notification-1'), true);
      expect(await first.accept('notification-1'), false);
      expect(await PushReceipts(store).accept('notification-1'), false);
      expect(await first.accept('notification-2'), true);
    },
  );
  test(
    'missing native Firebase configuration is explicit and never a registered device',
    () {
      expect(nativeFirebaseOptions(), isNull);
    },
  );
}
