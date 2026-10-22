import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

typedef Json = Map<String, dynamic>;
const maxKrw = 9007199254740991;
int parseKrw(String text, {bool signed = false}) {
  if (!RegExp(signed ? r'^-?\d+$' : r'^\d+$').hasMatch(text)) {
    throw const FormatException('원 단위 정수만 입력해주세요.');
  }
  final value = int.tryParse(text);
  if (value == null || value.abs() > maxKrw) {
    throw const FormatException('허용 금액 범위를 확인해주세요.');
  }
  return value;
}

class ApiFailure implements Exception {
  final int? status;
  final String code;
  const ApiFailure(this.status, this.code);
  String get message => switch (code) {
    'RECIPIENT_BANK_ACCOUNT_REQUIRED' =>
      '송금받을 분의 확인된 계좌가 없습니다. 수령자가 계좌를 등록·확인해야 합니다.',
    'FUNDING_RECONCILIATION_REQUIRED' => '지출의 자금 출처 분류가 끝나지 않아 인계할 수 없습니다.',
    'CASH_INVENTORY_MISMATCH' => '현재 실제 보관금과 명세가 다릅니다. 최신 명세를 확인해주세요.',
    'NEGATIVE_CASH_INVENTORY' => '실제 자금 부족이 있어 인계를 진행할 수 없습니다.',
    'FIREBASE_CONFIGURATION_MISSING' =>
      '이 기기 푸시 연결 설정이 준비되지 않았습니다. 인앱 알림은 계속 확인할 수 있습니다.',
    'NOTIFICATION_PERMISSION_REQUIRED' => '기기 알림 권한이 허용되지 않았습니다. 인앱 알림은 유지됩니다.',
    _ => switch (status) {
      401 => '로그인이 만료되었습니다. 다시 로그인해주세요.',
      403 => '이 업무를 처리할 권한이 없습니다.',
      404 => '자료를 찾을 수 없습니다. 아직 제공되지 않는 기능일 수 있어요.',
      409 => '다른 변경이 있습니다. 최신 자료를 다시 불러온 뒤 확인해주세요.',
      429 => '요청이 많습니다. 잠시 후 다시 시도해주세요.',
      503 => '공급자 또는 서버 연결을 사용할 수 없습니다. 완료되지 않았어요.',
      _ => '요청을 완료하지 못했습니다. 연결과 입력을 확인해주세요.',
    },
  };
  @override
  String toString() => '$message ($code)';
}

class Session {
  final String token, scope, userId;
  final DateTime expiresAt;
  Session(Json data)
    : token = data['token'],
      scope = data['scope'],
      userId = data['userId'],
      expiresAt = DateTime.parse(data['expiresAt']);
  bool get active => scope == 'ACTIVE' && expiresAt.isAfter(DateTime.now());
  Json toJson() => {
    'token': token,
    'scope': scope,
    'userId': userId,
    'expiresAt': expiresAt.toIso8601String(),
  };
}

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class SecureTokenStore implements TokenStore {
  final FlutterSecureStorage storage;
  const SecureTokenStore([this.storage = const FlutterSecureStorage()]);
  @override
  Future<String?> read() => storage.read(key: 'moishow.session');
  @override
  Future<void> write(String? value) => value == null
      ? storage.delete(key: 'moishow.session')
      : storage.write(key: 'moishow.session', value: value);
}

class SecureIntentStore implements TokenStore {
  final FlutterSecureStorage storage;
  const SecureIntentStore([this.storage = const FlutterSecureStorage()]);
  @override
  Future<String?> read() => storage.read(key: 'moishow.pending.commands');
  @override
  Future<void> write(String? value) => value == null
      ? storage.delete(key: 'moishow.pending.commands')
      : storage.write(key: 'moishow.pending.commands', value: value);
}

dynamic freezeJson(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((key, item) => MapEntry(key as String, freezeJson(item))),
    );
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(freezeJson));
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  throw const FormatException('JSON 계약에 맞지 않는 입력입니다.');
}

String canonicalJson(dynamic value) {
  dynamic sorted(dynamic item) {
    if (item is Map) {
      final keys = item.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: sorted(item[key])};
    }
    if (item is List) return item.map(sorted).toList();
    return item;
  }

  return jsonEncode(sorted(value));
}

/// One command retains its key/body after transport failure. A changed form is
/// a new command; version conflicts require a resource reload and new command.
class Command {
  final String path, key;
  final Json body;
  Command(this.path, Json body, {String? key})
    : body = freezeJson(body) as Json,
      key = key ?? const Uuid().v4();
}

class Api {
  final Dio dio;
  final TokenStore store;
  final TokenStore intents;
  Future<void> _journalTail = Future.value();
  Session? session;
  bool needsProfileSetup = false;
  String? restoreWarning;
  void Function()? onSessionChanged;
  Api({Dio? dio, TokenStore? store, TokenStore? intents})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://localhost:8080/api/v1',
              ),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ),
      store = store ?? const SecureTokenStore(),
      intents = intents ?? const SecureIntentStore();
  Future<T> _journal<T>(Future<T> Function() task) {
    final future = _journalTail.then((_) => task());
    _journalTail = future.then<void>((_) {}, onError: (_) {});
    return future;
  }

  Future<List<Json>> _entries() async {
    final raw = await intents.read();
    if (raw == null) return [];
    final list = jsonDecode(raw);
    if (list is! List) throw const FormatException('저장된 요청을 복구하지 못했습니다.');
    return list.map((v) => Map<String, dynamic>.from(v as Map)).toList();
  }

  Future<List<Command>> pendingCommands() => _journal(
    () async => (await _entries())
        .where((v) => v['userId'] == session?.userId)
        .map(
          (v) => Command(
            v['path'],
            Map<String, dynamic>.from(v['body']),
            key: v['key'],
          ),
        )
        .toList(),
  );
  Future<void> discardCommand(String key) => _journal(() async {
    final list = await _entries();
    list.removeWhere((v) => v['key'] == key && v['userId'] == session?.userId);
    await intents.write(jsonEncode(list));
  });
  Future<void> _finishCommand(String key, String? owner) => _journal(() async {
    final list = await _entries();
    list.removeWhere((v) => v['key'] == key && v['userId'] == owner);
    await intents.write(jsonEncode(list));
  });
  Future<void> restore() async {
    session = null;
    String? raw;
    try {
      raw = await store.read();
    } catch (_) {
      restoreWarning =
          '보안 저장소를 복구하지 못했습니다. 다시 로그인해주세요. 저장된 업무 요청을 임의로 삭제하지 않습니다.';
      return;
    }
    if (raw != null) {
      try {
        final saved = Session(jsonDecode(raw));
        if (saved.expiresAt.isAfter(DateTime.now())) {
          session = saved;
        } else {
          await store.write(null);
        }
      } catch (_) {
        await store.write(null);
      }
    }
  }

  Future<void> saveSession(Json value) async {
    final candidate = Session(value);
    await store.write(jsonEncode(candidate.toJson()));
    session = candidate;
    onSessionChanged?.call();
  }

  Future<void> clearSession() async {
    session = null;
    needsProfileSetup = false;
    try {
      await store.write(null);
    } finally {
      onSessionChanged?.call();
    }
  }

  Future<dynamic> get(String path) => request('GET', path);
  Future<List<Json>> listAll(String path) async {
    final result = <Json>[];
    int offset = 0;
    while (true) {
      final uri = Uri.parse(path);
      final page = await get(
        uri
            .replace(
              queryParameters: {
                ...uri.queryParameters,
                'offset': '$offset',
                'limit': '200',
              },
            )
            .toString(),
      );
      if (page is! List) throw const FormatException('목록 응답 형식이 다릅니다.');
      result.addAll(page.map((v) => Map<String, dynamic>.from(v as Map)));
      if (page.length < 200) break;
      offset += page.length;
    }
    return result;
  }

  Future<dynamic> auth(String path, Json body) =>
      request('POST', path, body: body);
  Future<dynamic> send(Command command) async {
    final userId = session?.userId;
    final ownerToken = session?.token;
    final prepared = await _journal(() async {
      final list = await _entries();
      final old = list
          .where(
            (v) =>
                v['userId'] == userId &&
                v['path'] == command.path &&
                canonicalJson(v['body']) == canonicalJson(command.body),
          )
          .firstOrNull;
      final chosen = old == null
          ? command
          : Command(
              old['path'],
              Map<String, dynamic>.from(old['body']),
              key: old['key'],
            );
      if (old == null) {
        list.add({
          'userId': userId,
          'path': chosen.path,
          'body': chosen.body,
          'key': chosen.key,
        });
        await intents.write(jsonEncode(list));
      }
      return chosen;
    });
    try {
      if (ownerToken != session?.token) {
        throw const ApiFailure(401, 'SESSION_CHANGED');
      }
      final response = await request(
        'POST',
        prepared.path,
        body: prepared.body,
        key: prepared.key,
      );
      await _finishCommand(prepared.key, userId);
      if (ownerToken != session?.token) {
        throw const ApiFailure(401, 'SESSION_CHANGED');
      }
      return response;
    } on ApiFailure catch (e) {
      if (e.status != null && e.status! >= 400 && e.status! < 500) {
        await _journal(() async {
          final list = await _entries();
          list.removeWhere(
            (v) => v['key'] == prepared.key && v['userId'] == userId,
          );
          await intents.write(jsonEncode(list));
        });
      }
      rethrow;
    }
  }

  Future<Uint8List> readFile(String id) async {
    final owner = session?.token;
    try {
      final r = await dio.get<List<int>>(
        '/files/$id',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $owner'},
        ),
      );
      if (owner != session?.token) {
        throw const ApiFailure(401, 'SESSION_CHANGED');
      }
      return Uint8List.fromList(r.data!);
    } on DioException catch (e) {
      throw ApiFailure(e.response?.statusCode, 'PROTECTED_FILE_UNAVAILABLE');
    }
  }

  Future<dynamic> request(
    String method,
    String path, {
    Json? body,
    String? key,
  }) async {
    final authToken = session?.token;
    try {
      final response = await dio.request<dynamic>(
        path,
        data: path == '/files' && body != null
            ? FormData.fromMap({
                'scope': body['scope'],
                if (body['clubId'] != null) 'clubId': body['clubId'],
                if (body['eventId'] != null) 'eventId': body['eventId'],
                'file': MultipartFile.fromBytes(
                  base64Decode(body['fileBase64']),
                  filename: 'evidence',
                  contentType: DioMediaType.parse(body['contentType']),
                ),
              })
            : body,
        options: Options(
          method: method,
          headers: {
            if (authToken != null) 'Authorization': 'Bearer $authToken',
            'Idempotency-Key': ?key,
          },
        ),
      );
      if (authToken != session?.token) {
        throw const ApiFailure(401, 'SESSION_CHANGED');
      }
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && authToken == session?.token) {
        await clearSession();
      }
      final data = e.response?.data;
      throw ApiFailure(
        e.response?.statusCode,
        data is Map
            ? '${data['code'] ?? data['error'] ?? 'REQUEST_FAILED'}'
            : 'NETWORK_UNAVAILABLE',
      );
    }
  }
}
