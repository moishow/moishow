import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pushRegistrarProvider = Provider<PushRegistrar?>((ref) => null);

FirebaseOptions? nativeFirebaseOptions() {
  const key = String.fromEnvironment('FIREBASE_API_KEY'),
      app = String.fromEnvironment('FIREBASE_APP_ID'),
      sender = String.fromEnvironment('FIREBASE_SENDER_ID'),
      project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  if (key.isEmpty || app.isEmpty || sender.isEmpty || project.isEmpty) {
    return null;
  }
  return const FirebaseOptions(
    apiKey: key,
    appId: app,
    messagingSenderId: sender,
    projectId: project,
    iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
  );
}

class PushReceiptStorage implements TokenStore {
  const PushReceiptStorage();
  static const storage = FlutterSecureStorage();
  @override
  Future<String?> read() => storage.read(key: 'moishow.push.receipts');
  @override
  Future<void> write(String? value) => value == null
      ? storage.delete(key: 'moishow.push.receipts')
      : storage.write(key: 'moishow.push.receipts', value: value);
}

class PushReceipts {
  final TokenStore store;
  PushReceipts(this.store);
  Future<bool> accept(String id) async {
    final raw = await store.read();
    final ids = raw == null ? <String>[] : List<String>.from(jsonDecode(raw));
    if (ids.contains(id)) return false;
    ids.add(id);
    await store.write(jsonEncode(ids));
    return true;
  }
}

@pragma('vm:entry-point')
Future<void> moishowBackgroundMessage(RemoteMessage message) async {
  final options = nativeFirebaseOptions();
  if (options == null) return;
  if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
  final id = message.data['notificationId'];
  if (id is String) await PushReceipts(const PushReceiptStorage()).accept(id);
}

abstract interface class PushTransport {
  Future<void> initialize();
  Future<bool> authorized(bool request);
  Future<String?> getToken();
  Future<void> deleteToken();
  Stream<String> get onTokenRefresh;
  Stream<RemoteMessage> get onOpened;
  Stream<RemoteMessage> get onForeground;
  Future<RemoteMessage?> getInitialMessage();
}

class NativePushTransport implements PushTransport {
  @override
  Future<void> initialize() async {
    final options = nativeFirebaseOptions();
    if (kIsWeb || options == null) {
      throw const ApiFailure(503, 'FIREBASE_CONFIGURATION_MISSING');
    }
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    FirebaseMessaging.onBackgroundMessage(moishowBackgroundMessage);
  }

  FirebaseMessaging get messaging => FirebaseMessaging.instance;
  @override
  Future<bool> authorized(bool request) async {
    final s = request
        ? await messaging.requestPermission()
        : await messaging.getNotificationSettings();
    return [
      AuthorizationStatus.authorized,
      AuthorizationStatus.provisional,
    ].contains(s.authorizationStatus);
  }

  @override
  Future<String?> getToken() async {
    await messaging.setAutoInitEnabled(true);
    return messaging.getToken();
  }

  @override
  Future<void> deleteToken() async {
    await messaging.setAutoInitEnabled(false);
    await messaging.deleteToken();
  }

  @override
  Stream<String> get onTokenRefresh => messaging.onTokenRefresh;
  @override
  Stream<RemoteMessage> get onOpened => FirebaseMessaging.onMessageOpenedApp;
  @override
  Stream<RemoteMessage> get onForeground => FirebaseMessaging.onMessage;
  @override
  Future<RemoteMessage?> getInitialMessage() => messaging.getInitialMessage();
}

class PushOwnershipStorage implements TokenStore {
  const PushOwnershipStorage();
  static const storage = FlutterSecureStorage();
  @override
  Future<String?> read() => storage.read(key: 'moishow.push.owner');
  @override
  Future<void> write(String? value) => value == null
      ? storage.delete(key: 'moishow.push.owner')
      : storage.write(key: 'moishow.push.owner', value: value);
}

Future<void> _deviceOperations = Future.value(),
    _ownershipOperations = Future.value();
Future<T> _deviceSerial<T>(Future<T> Function() action) {
  final result = _deviceOperations.then((_) => action());
  _deviceOperations = result.then<void>(
    (_) {},
    onError: (Object _, StackTrace _) {},
  );
  return result;
}

Future<T> _ownerSerial<T>(Future<T> Function() action) {
  final result = _ownershipOperations.then((_) => action());
  _ownershipOperations = result.then<void>(
    (_) {},
    onError: (Object _, StackTrace _) {},
  );
  return result;
}

class PushRegistrar {
  final Api api;
  final void Function() openInbox;
  final void Function()? foreground;
  final PushTransport transport;
  final TokenStore ownership, receipts;
  StreamSubscription<String>? refresh;
  StreamSubscription<RemoteMessage>? opens, messages;
  String? deviceId, _boundUser, _boundSession;
  int _epoch = 0, _registration = 0;
  bool _disposed = false;
  PushRegistrar(
    this.api,
    this.openInbox, {
    this.foreground,
    PushTransport? transport,
    TokenStore? ownership,
    TokenStore? receipts,
  }) : transport = transport ?? NativePushTransport(),
       ownership = ownership ?? const PushOwnershipStorage(),
       receipts = receipts ?? const PushReceiptStorage();
  bool _current(int epoch, String user, String session) =>
      !_disposed &&
      _epoch == epoch &&
      api.session?.active == true &&
      api.session?.userId == user &&
      api.session?.token == session;
  Future<void> _cancel() async {
    final r = refresh, o = opens, m = messages;
    refresh = null;
    opens = null;
    messages = null;
    await r?.cancel();
    await o?.cancel();
    await m?.cancel();
  }

  Future<void> sessionChanged() async {
    if (transport is NativePushTransport &&
        (kIsWeb || nativeFirebaseOptions() == null)) {
      await dispose();
      return;
    }
    if (api.session?.active == true) {
      await connect();
    } else {
      await disconnect();
    }
  }

  Future<void> connect({bool requestPermission = false}) async {
    final session = api.session;
    if (session?.active != true) {
      throw const ApiFailure(401, 'ACTIVE_SESSION_REQUIRED');
    }
    _disposed = false;
    final epoch = ++_epoch;
    final user = session!.userId, authorization = session.token;
    await _cancel();
    void guard() {
      if (!_current(epoch, user, authorization)) {
        throw const ApiFailure(401, 'SESSION_CHANGED');
      }
    }

    final token = await _deviceSerial(() async {
      guard();
      await transport.initialize();
      guard();
      final raw = await _ownerSerial(() => ownership.read());
      guard();
      final old = raw == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(raw));
      if (old != null &&
          (old['userId'] != user || old['rotationRequired'] == true)) {
        await transport.deleteToken();
        guard();
        await _ownerSerial(() async {
          guard();
          await ownership.write(null);
        });
      }
      if (!await transport.authorized(requestPermission)) {
        throw const ApiFailure(403, 'NOTIFICATION_PERMISSION_REQUIRED');
      }
      guard();
      final value = await transport.getToken();
      guard();
      if (value == null) throw const ApiFailure(503, 'FCM_TOKEN_UNAVAILABLE');
      return value;
    });
    Future<void> register(String value) async {
      guard();
      final order = ++_registration;
      await _ownerSerial(() async {
        guard();
        await ownership.write(
          jsonEncode({
            'userId': user,
            'rotationRequired': true,
            'deviceId': deviceId,
          }),
        );
      });
      guard();
      final result = await api.send(
        Command('/push/devices', {
          'token': value,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'IOS'
              : 'ANDROID',
        }),
      );
      guard();
      if (order != _registration) return;
      if (result is! Map || result['id'] is! String) {
        throw const FormatException('푸시 기기 응답이 다릅니다.');
      }
      final id = result['id'] as String;
      await _ownerSerial(() async {
        guard();
        if (order != _registration) return;
        await ownership.write(
          jsonEncode({
            'userId': user,
            'deviceId': id,
            'rotationRequired': false,
          }),
        );
        guard();
        if (order == _registration) {
          deviceId = id;
          _boundUser = user;
          _boundSession = authorization;
        }
      });
    }

    await register(token);
    guard();
    refresh = transport.onTokenRefresh.listen((value) {
      unawaited(
        () async {
          if (!_current(epoch, user, authorization)) return;
          final actual = await transport.getToken();
          if (actual != value || !_current(epoch, user, authorization)) return;
          await register(value);
        }().catchError((_) {}),
      );
    });
    opens = transport.onOpened.listen((_) {
      if (_current(epoch, user, authorization)) openInbox();
    });
    messages = transport.onForeground.listen((message) {
      unawaited(
        () async {
          final id = message.data['notificationId'];
          if (id is String &&
              _current(epoch, user, authorization) &&
              await PushReceipts(receipts).accept(id) &&
              _current(epoch, user, authorization)) {
            foreground?.call();
          }
        }().catchError((_) {}),
      );
    });
    final initial = await transport.getInitialMessage();
    if (initial != null && _current(epoch, user, authorization)) openInbox();
  }

  Future<void> disconnect() async {
    final epoch = ++_epoch;
    final oldId = deviceId, oldUser = _boundUser, oldSession = _boundSession;
    deviceId = null;
    _boundUser = null;
    _boundSession = null;
    await _cancel();
    if (oldId != null &&
        api.session?.active == true &&
        api.session?.userId == oldUser &&
        api.session?.token == oldSession) {
      try {
        await api.request(
          'DELETE',
          '/push/devices/$oldId',
          key: Command('/push/devices/$oldId', {}).key,
        );
      } on ApiFailure {
        /* Expired or unreachable server cleanup still requires provider token revocation below. */
      }
    }
    await _deviceSerial(() async {
      if (epoch != _epoch || _disposed) return;
      final raw = await _ownerSerial(() => ownership.read());
      if (raw == null && oldId == null) return;
      await transport.initialize();
      if (epoch != _epoch || _disposed) return;
      final old = raw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw));
      await _ownerSerial(() async {
        if (epoch == _epoch) {
          await ownership.write(jsonEncode({...old, 'rotationRequired': true}));
        }
      });
      if (epoch != _epoch) return;
      await transport.deleteToken();
      if (epoch != _epoch) return;
      await _ownerSerial(() async {
        if (epoch == _epoch) await ownership.write(null);
      });
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _epoch++;
    await _cancel();
  }
}
