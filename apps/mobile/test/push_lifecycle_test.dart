import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/main.dart';
import 'package:moishow/push.dart';
import 'api_test.dart' show MemoryStore;
import 'push_ownership_test.dart' show DeviceApi, DeviceTransport;

void main() {
  testWidgets(
    'app session expiry invokes device revocation rather than subscription disposal alone',
    (t) async {
      final api = DeviceApi(), transport = DeviceTransport();
      final push = PushRegistrar(
        api,
        () {},
        transport: transport,
        ownership: MemoryStore(),
        receipts: MemoryStore(),
      );
      await api.login('A');
      await push.connect();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            apiProvider.overrideWithValue(api),
            pushRegistrarProvider.overrideWithValue(push),
          ],
          child: const MoishowApp(),
        ),
      );
      await t.pumpAndSettle();
      await api.clearSession();
      await t.pumpAndSettle();
      expect(transport.deletions, 1);
      await t.pumpWidget(const SizedBox());
      await transport.close();
    },
  );
}
