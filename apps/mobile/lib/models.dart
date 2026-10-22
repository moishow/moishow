import 'api.dart';

/// Server contract violations are visible errors. Missing money is never zero.
class ContractError extends FormatException {
  const ContractError(String field) : super('서버 자료 형식을 확인해주세요: $field');
}

Json objectValue(dynamic value) {
  if (value is! Map) throw const ContractError('object');
  return Map<String, dynamic>.from(value);
}

List<Json> objectList(dynamic value) {
  if (value is! List) throw const ContractError('list');
  return value.map(objectValue).toList();
}

int integerValue(dynamic value, String field, {bool signed = false}) {
  if (value is! int || value.abs() > maxKrw || (!signed && value < 0)) {
    throw ContractError(field);
  }
  return value;
}

String stringValue(dynamic value, String field) {
  if (value is! String || value.isEmpty) throw ContractError(field);
  return value;
}

class Person {
  final String id, nickname;
  final bool departed;
  Person(Json json)
    : id = stringValue(json['userId'] ?? json['id'], 'person.id'),
      nickname = stringValue(json['nickname'], 'person.nickname'),
      departed = json['departed'] == true;
  String get displayName => '$nickname${departed ? ' · 탈퇴한 멤버' : ''}';
}

class FinanceSnapshot {
  final Json data;
  final int version;
  final List<Json> positions;
  FinanceSnapshot(dynamic value)
    : data = objectValue(value),
      version = integerValue(objectValue(value)['version'], 'finance.version'),
      positions = objectList(
        objectValue(objectValue(value)['calculation'])['positions'],
      ) {
    for (final p in positions) {
      stringValue(p['userId'], 'position.user');
      for (final field in [
        'obligation',
        'received',
        'refunded',
        'additional',
        'refund',
      ]) {
        integerValue(p[field], 'position.$field');
      }
    }
    for (final key in [
      'requests',
      'reports',
      'expenses',
      'refunds',
      'disputes',
      'revisions',
    ]) {
      objectList(data[key]);
    }
  }
}
