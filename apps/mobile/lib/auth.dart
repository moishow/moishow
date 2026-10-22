import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'api.dart';

class NativeAuth {
  final Api api;
  final String googleServerClientId;
  final Future<String> Function(String)? appleBrowser;
  NativeAuth(
    this.api, {
    this.googleServerClientId = const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
    ),
    this.appleBrowser,
  });
  Future<void> login(String provider) async {
    if (kIsWeb) {
      throw const ApiFailure(503, 'NATIVE_LOGIN_REQUIRED');
    }
    String? token;
    String? challengeId;
    switch (provider) {
      case 'GOOGLE':
        final clientId = googleServerClientId;
        if (clientId.isEmpty) {
          throw const ApiFailure(503, 'GOOGLE_CLIENT_ID_MISSING');
        }
        // The native SDK accepts a fresh nonce for each interactive attempt.
        // The Flutter wrapper's process-wide initialize nonce cannot safely rotate.
        final challenge = objAuth(await api.auth('/auth/challenges', {}));
        challengeId = challenge['challengeId'];
        token = await const MethodChannel('com.moishow/identity')
            .invokeMethod<String>('googleSignIn', {
              'serverClientId': clientId,
              'clientId': const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
              'nonce': challenge['nonce'],
            });
      case 'APPLE':
        if (defaultTargetPlatform == TargetPlatform.android) {
          final random = Random.secure();
          final verifier = base64UrlEncode(
            List<int>.generate(32, (_) => random.nextInt(256)),
          ).replaceAll('=', '');
          final challenge = base64UrlEncode(
            sha256.convert(ascii.encode(verifier)).bytes,
          ).replaceAll('=', '');
          final started = objAuth(
            await api.auth('/auth/apple/mobile/start', {
              'codeChallenge': challenge,
            }),
          );
          final authorize = Uri.parse(started['authorizeUrl']);
          if (authorize.scheme != 'https' ||
              authorize.host != 'appleid.apple.com' ||
              authorize.path != '/auth/authorize') {
            throw const ApiFailure(401, 'INVALID_APPLE_AUTHORIZE_URL');
          }
          final callback =
              await (appleBrowser ??
                  (url) => FlutterWebAuth2.authenticate(
                    url: url,
                    callbackUrlScheme: 'moishow',
                  ))(authorize.toString());
          final uri = Uri.parse(callback);
          if (uri.scheme != 'moishow' ||
              uri.host != 'apple' ||
              uri.path != '/callback' ||
              uri.queryParameters['state'] != started['state'] ||
              uri.queryParameters['ticket'] == null ||
              uri.queryParameters.containsKey('id_token') ||
              uri.queryParameters.containsKey('token')) {
            throw const ApiFailure(401, 'INVALID_APPLE_CALLBACK');
          }
          await api.saveSession(
            objAuth(
              await api.auth('/auth/apple/mobile/exchange', {
                'ticket': uri.queryParameters['ticket'],
                'codeVerifier': verifier,
              }),
            ),
          );
          return;
        }
        final challenge = await api.auth('/auth/challenges', {});
        challengeId = challenge['challengeId'];
        token = (await SignInWithApple.getAppleIDCredential(
          scopes: [AppleIDAuthorizationScopes.email],
          nonce: challenge['nonce'],
        )).identityToken;
      case 'KAKAO':
        const key = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
        if (key.isEmpty) {
          throw const ApiFailure(503, 'KAKAO_APP_KEY_MISSING');
        }
        KakaoSdk.init(nativeAppKey: key);
        final result = await UserApi.instance.loginWithKakaoAccount();
        token = result.accessToken;
      default:
        throw const ApiFailure(400, 'UNKNOWN_PROVIDER');
    }
    if (token == null || token.isEmpty) {
      throw const ApiFailure(401, 'PROVIDER_TOKEN_MISSING');
    }
    final result = await api.auth('/auth/social', {
      'provider': provider,
      'token': token,
      'challengeId': ?challengeId,
    });
    await api.saveSession(Map<String, dynamic>.from(result));
  }
}

Json objAuth(dynamic value) => Map<String, dynamic>.from(value as Map);
