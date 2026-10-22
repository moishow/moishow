import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/auth.dart';
import 'api_test.dart' show MemoryStore;

class AppleApi extends Api {
  String? challenge;
  final paths = <String>[];
  AppleApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> auth(String path, Json body) async {
    paths.add(path);
    if (path.endsWith('/start')) {
      challenge = body['codeChallenge'];
      return {
        'state': 'bound-state',
        'authorizeUrl':
            'https://appleid.apple.com/auth/authorize?state=bound-state',
      };
    }
    if (path.endsWith('/exchange')) {
      expect(body['ticket'], 'opaque-ticket');
      expect(
        base64UrlEncode(
          sha256.convert(ascii.encode(body['codeVerifier'])).bytes,
        ).replaceAll('=', ''),
        challenge,
      );
      return {
        'token': 'server-session',
        'scope': 'ONBOARDING',
        'userId': 'u',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
      };
    }
    throw StateError('Unexpected credential path');
  }
}

void main() {
  test(
    'Android Apple uses PKCE-bound opaque ticket and never a token query',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final api = AppleApi();
      final auth = NativeAuth(
        api,
        appleBrowser: (url) async {
          expect(Uri.parse(url).host, 'appleid.apple.com');
          return 'moishow://apple/callback?ticket=opaque-ticket&state=bound-state';
        },
      );
      await auth.login('APPLE');
      expect(api.paths, [
        '/auth/apple/mobile/start',
        '/auth/apple/mobile/exchange',
      ]);
      expect(api.session!.scope, 'ONBOARDING');
    },
  );
  test('spoofed Apple callback state cannot issue a service session', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final api = AppleApi();
    final auth = NativeAuth(
      api,
      appleBrowser: (_) async =>
          'moishow://apple/callback?ticket=opaque-ticket&state=wrong',
    );
    await expectLater(auth.login('APPLE'), throwsA(isA<ApiFailure>()));
    expect(api.session, isNull);
    expect(api.paths, hasLength(1));
  });
}
