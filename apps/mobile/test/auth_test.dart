import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/auth.dart';
import 'api_test.dart' show MemoryStore;

class SocialApi extends Api {
  int challenges = 0, exchanges = 0;
  SocialApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> auth(String path, Json body) async {
    if (path == '/auth/challenges') {
      challenges++;
      return {
        'challengeId': 'challenge$challenges',
        'nonce': 'nonce$challenges',
      };
    }
    if (path == '/auth/social') {
      exchanges++;
      expect(body['challengeId'], 'challenge$exchanges');
      if (exchanges == 1) throw const ApiFailure(null, 'NETWORK_UNAVAILABLE');
      return {
        'token': 'active-service-token',
        'scope': 'ACTIVE',
        'userId': 'u',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      };
    }
    throw StateError('Unexpected request');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'each Google retry obtains and passes a fresh server nonce without restarting',
    () async {
      final nonces = <String>[];
      const channel = MethodChannel('com.moishow/identity');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            nonces.add(call.arguments['nonce']);
            return 'provider-token';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final api = SocialApi();
      final auth = NativeAuth(
        api,
        googleServerClientId: 'configured-test-client',
      );
      await expectLater(auth.login('GOOGLE'), throwsA(isA<ApiFailure>()));
      expect(api.session, isNull);
      await auth.login('GOOGLE');
      expect(nonces, ['nonce1', 'nonce2']);
      expect(api.session!.active, true);
    },
  );
}
