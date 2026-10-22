import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:moishow/api.dart';
import 'dart:async';
import 'dart:typed_data';
import 'api_test.dart' show MemoryStore, RecordingAdapter;

class DelayedAdapter implements HttpClientAdapter {
  final started = Completer<void>(), response = Completer<ResponseBody>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) {
    started.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'response after account switch cannot update the new account UI',
    () async {
      final adapter = DelayedAdapter(),
          store = MemoryStore(),
          intents = MemoryStore();
      final api = Api(
        dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter,
        store: store,
        intents: intents,
      );
      Future<void> session(String id) => api.saveSession({
        'token': 'session-$id',
        'scope': 'ACTIVE',
        'userId': id,
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      await session('old');
      final request = api.send(Command('/reports', {'amount': 10000}));
      await adapter.started.future;
      await session('new');
      adapter.response.complete(
        ResponseBody.fromString(
          '{"ok":true}',
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      await expectLater(
        request,
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
        ),
      );
    },
  );
  test(
    'restart and reordered DTO fields recover exact uncertain request key',
    () async {
      final intents = MemoryStore();
      final first = RecordingAdapter()..failFirst = true;
      final api = Api(
        dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = first,
        store: MemoryStore(),
        intents: intents,
      );
      final original = Command('/reports', {'amount': 10000, 'version': 2});
      await expectLater(api.send(original), throwsA(isA<ApiFailure>()));
      final second = RecordingAdapter();
      final restarted = Api(
        dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = second,
        store: MemoryStore(),
        intents: intents,
      );
      await restarted.send(
        Command('/reports', {'version': 2, 'amount': 10000}),
      );
      expect(second.requests.single.headers['Idempotency-Key'], original.key);
      expect(await restarted.pendingCommands(), isEmpty);
    },
  );
}
