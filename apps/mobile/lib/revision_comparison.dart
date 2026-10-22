import 'dart:convert';

import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

/// Compares immutable server snapshots without reconstructing historical money.
class RevisionComparison extends StatelessWidget {
  final Json revision;
  final String Function(dynamic) nameOf;
  const RevisionComparison({
    super.key,
    required this.revision,
    required this.nameOf,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final reason = stringValue(revision['reason'], 'revision.reason');
      final time = formatTimestamp(revision['createdAt']);
      final before = _PreservedSnapshot.read(revision['snapshot']);
      final after = _PreservedSnapshot.read(revision['afterSnapshot']);
      // Only IDs present in these exact server-filtered snapshots are named.
      final users = {...before.positions.keys, ...after.positions.keys};
      const fields = {
        'obligation': '개인 부담',
        'received': '확인 입금',
        'refunded': '지급 환불 기록',
        'net': '순차액',
        'additional': '추가 납부',
        'refund': '일반 환불',
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            reason == 'INITIAL' ? '최초 계산 원본' : reason,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('기록 시각 $time'),
          const SizedBox(height: Tokens.gap),
          const Note(
            '순차액에는 선지출이 반영될 수 있으며 일반 환불과 구분합니다. 보존된 계산값이며 실제 송금·수령 확인을 뜻하지 않습니다.',
          ),
          if (before.missing) const Note('원본 보존 자료가 없습니다.'),
          if (before.invalid) const Note('원본 보존 자료 형식을 확인해주세요.'),
          if (after.missing) const Note('정정 후 보존 자료가 없습니다.'),
          if (after.invalid) const Note('정정 후 보존 자료 형식을 확인해주세요.'),
          if (users.isEmpty && !before.invalid && !after.invalid)
            const Note('이 보존 자료에는 개인별 금액 기록이 없습니다.'),
          for (final user in users)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.screen),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      nameOf(user),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: Tokens.gap),
                    for (final field in fields.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Tokens.gap),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '원본 · ${field.value} ${before.amount(user, field.key)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              '정정 후 · ${field.value} ${after.amount(user, field.key)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    } on FormatException catch (failure) {
      return Note(failure.message);
    }
  }
}

class _PreservedSnapshot {
  final Map<String, Json> positions;
  final bool missing, invalid;
  const _PreservedSnapshot(
    this.positions, {
    this.missing = false,
    this.invalid = false,
  });

  static _PreservedSnapshot read(dynamic raw) {
    if (raw == null) return const _PreservedSnapshot({}, missing: true);
    try {
      final decoded = objectValue(
        jsonDecode(stringValue(raw, 'revision.snapshot')),
      );
      final positions = <String, Json>{};
      for (final row in objectList(decoded['positions'])) {
        final user = stringValue(row['userId'], 'revision.position.userId');
        if (positions.containsKey(user)) {
          throw const ContractError('revision.duplicateUserId');
        }
        positions[user] = row;
      }
      return _PreservedSnapshot(positions);
    } on FormatException {
      return const _PreservedSnapshot({}, invalid: true);
    }
  }

  String amount(String user, String field) {
    if (missing) return '보존 자료 없음';
    if (invalid) return '자료 확인 필요';
    final position = positions[user];
    if (position == null) return '기록 없음';
    try {
      final value = integerValue(
        position[field],
        'revision.$field',
        signed: field == 'net',
      );
      return won(value);
    } on FormatException {
      return '금액 확인 필요';
    }
  }
}
