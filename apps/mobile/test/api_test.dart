import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';

class MemoryStore implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? text) async {
    value = text;
  }
}

class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  bool failFirst = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (failFirst && requests.length == 1) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      '{"ok":true}',
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'KRW accepts exact boundary and rejects fractions, exponent, negative and overflow',
    () {
      expect(parseKrw('0'), 0);
      expect(parseKrw('$maxKrw'), maxKrw);
      expect(parseKrw('-1', signed: true), -1);
      for (final invalid in [
        '1.2',
        '1e3',
        '-1',
        '9007199254740992',
        '10,000',
        '',
      ]) {
        expect(() => parseKrw(invalid), throwsFormatException);
      }
    },
  );
  test('a failed transport retry retains exact command key and body', () async {
    final adapter = RecordingAdapter()..failFirst = true;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;
    final api = Api(dio: dio, store: MemoryStore(), intents: MemoryStore());
    final command = Command('/events/event/finance/reports', {
      'version': 4,
      'amount': 10000,
      'requestId': 'request',
    });
    await expectLater(api.send(command), throwsA(isA<ApiFailure>()));
    await api.send(command);
    expect(adapter.requests.length, 2);
    expect(
      adapter.requests[0].headers['Idempotency-Key'],
      adapter.requests[1].headers['Idempotency-Key'],
    );
    expect(adapter.requests[0].data, adapter.requests[1].data);
    expect(() => command.body['amount'] = 1, throwsUnsupportedError);
  });
  test(
    '409 remains a conflict and does not silently retry or alter amount',
    () async {
      final adapter = RecordingAdapter()..status = 409;
      final api = Api(
        dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter,
        store: MemoryStore(),
        intents: MemoryStore(),
      );
      await expectLater(
        api.send(Command('/refunds', {'version': 2, 'amount': 7000})),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 409)),
      );
      expect(adapter.requests.length, 1);
    },
  );
  test(
    'session persists securely through store and expired sessions are cleared',
    () async {
      final store = MemoryStore();
      final api = Api(store: store, intents: MemoryStore());
      await api.saveSession({
        'token': 'opaque',
        'scope': 'ONBOARDING',
        'userId': 'u',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
      });
      final restored = Api(store: store, intents: MemoryStore());
      await restored.restore();
      expect(restored.session!.active, false);
      expect(restored.session!.scope, 'ONBOARDING');
      await api.saveSession({
        'token': 'expired',
        'scope': 'ACTIVE',
        'userId': 'u',
        'expiresAt': '2000-01-01T00:00:00Z',
      });
      await restored.restore();
      expect(await store.read(), isNull);
    },
  );
  test('401 discards token and notifies gate', () async {
    final adapter = RecordingAdapter()..status = 401;
    final store = MemoryStore();
    final api = Api(
      dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter,
      store: store,
    );
    await api.saveSession({
      'token': 'opaque',
      'scope': 'ACTIVE',
      'userId': 'u',
      'expiresAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    });
    bool notified = false;
    api.onSessionChanged = () => notified = true;
    await expectLater(api.get('/me'), throwsA(isA<ApiFailure>()));
    expect(api.session, isNull);
    expect(await store.read(), isNull);
    expect(notified, true);
  });
}
