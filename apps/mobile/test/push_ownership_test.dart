import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/push.dart';
import 'api_test.dart' show MemoryStore;

class DeviceTransport implements PushTransport {
  int generation = 0, deletions = 0;
  final changes = StreamController<String>.broadcast();
  final events = StreamController<RemoteMessage>.broadcast();
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> authorized(bool request) async => true;
  @override
  Future<String?> getToken() async => 'device-$generation';
  @override
  Future<void> deleteToken() async {
    deletions++;
    generation++;
  }

  @override
  Stream<String> get onTokenRefresh => changes.stream;
  @override
  Stream<RemoteMessage> get onOpened => events.stream;
  @override
  Stream<RemoteMessage> get onForeground => events.stream;
  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
  void rotate() {
    generation++;
    changes.add('device-$generation');
  }

  Future<void> close() async {
    await changes.close();
    await events.close();
  }
}

class DeviceApi extends Api {
  final owners = <String, String>{};
  final entered = Completer<void>();
  final release = Completer<void>();
  bool delayA = false;
  int registrations = 0;
  DeviceApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> send(Command c) async {
    final user = session!.userId, token = c.body['token'] as String;
    registrations++;
    if (owners[token] != null && owners[token] != user) {
      throw const ApiFailure(409, 'DEVICE_ALREADY_REGISTERED');
    }
    owners[token] = user;
    if (delayA && user == 'A') {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    }
    return {'id': '$user:$token'};
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Json? body,
    String? key,
  }) async => {};
  Future<void> login(String user) => saveSession({
    'token': 'session-$user',
    'scope': 'ACTIVE',
    'userId': user,
    'expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
  });
}

void main() {
  test(
    'expired A device is revoked before B gets a fresh registration and stale refresh is ignored',
    () async {
      final api = DeviceApi(),
          transport = DeviceTransport(),
          owner = MemoryStore();
      final push = PushRegistrar(
        api,
        () {},
        transport: transport,
        ownership: owner,
        receipts: MemoryStore(),
      );
      await api.login('A');
      await push.connect();
      await api.clearSession();
      await push.sessionChanged();
      expect(transport.deletions, 1);
      await api.login('B');
      await push.connect();
      expect(push.deviceId, 'B:device-1');
      expect(jsonDecode(owner.value!)['userId'], 'B');
      final oldCount = api.registrations;
      transport.changes.add('device-0');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(api.registrations, oldCount);
      transport.rotate();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(push.deviceId, 'B:device-2');
      await push.dispose();
      await transport.close();
    },
  );
  test(
    'late A registration response cannot overwrite B device or revoke B rotated token',
    () async {
      final api = DeviceApi()..delayA = true;
      final transport = DeviceTransport(), owner = MemoryStore();
      final push = PushRegistrar(
        api,
        () {},
        transport: transport,
        ownership: owner,
        receipts: MemoryStore(),
      );
      await api.login('A');
      final first = push.connect();
      await api.entered.future;
      await api.clearSession();
      await push.sessionChanged();
      await api.login('B');
      await push.connect();
      final rejected = expectLater(
        first,
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
        ),
      );
      api.release.complete();
      await rejected;
      expect(push.deviceId, 'B:device-1');
      expect(jsonDecode(owner.value!)['userId'], 'B');
      expect(transport.deletions, 1);
      await push.dispose();
      await transport.close();
    },
  );
}
