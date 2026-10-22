import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'main.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

/// Personal history pages contain identifiers only; money is read on expansion.
class HistoryPanel extends ConsumerWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final session = api.session;
    if (session == null || !session.active) {
      return const Note('로그인 후 본인의 지난 정산 기록을 확인할 수 있습니다.');
    }
    return _HistoryList(key: ObjectKey(session), api: api, session: session);
  }
}

class _HistoryRecord {
  final String eventId, title, status;
  _HistoryRecord(Json row)
    : eventId = stringValue(row['eventId'], 'history.eventId'),
      title = stringValue(row['title'], 'history.title'),
      status = stringValue(row['status'], 'history.status');
}

class _HistoryList extends StatefulWidget {
  final Api api;
  final Session session;
  const _HistoryList({super.key, required this.api, required this.session});

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  static const pageSize = 20;
  final records = <_HistoryRecord>[];
  int offset = 0;
  bool loading = false, hasMore = true;
  Object? error;

  bool get ownsSession => identical(widget.api.session, widget.session);

  @override
  void initState() {
    super.initState();
    loadMore();
  }

  Future<void> loadMore() async {
    if (loading || !hasMore || !ownsSession) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.api.get(
        '/me/history?offset=$offset&limit=$pageSize',
      );
      final page = objectList(value).map(_HistoryRecord.new).toList();
      if (!mounted || !ownsSession) return;
      setState(() {
        final known = records.map((r) => r.eventId).toSet();
        for (final record in page) {
          if (known.add(record.eventId)) records.add(record);
        }
        offset += page.length;
        hasMore = page.length == pageSize;
        loading = false;
      });
    } catch (failure) {
      if (!mounted || !ownsSession) return;
      setState(() {
        error = failure;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ownsSession) {
      return const Note('계정이 변경되었습니다. 새 계정의 기록을 다시 열어주세요.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Note('탈퇴해도 본인이 참여한 기록과 처리는 유지됩니다. 계산 마감 후에도 미납·환불·이의 처리는 이어집니다.'),
        if (records.isEmpty && !loading && error == null)
          empty('지난 정산 내역이 없어요.'),
        for (final record in records)
          _HistoryEntry(
            key: ValueKey(record.eventId),
            api: widget.api,
            session: widget.session,
            record: record,
          ),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(Tokens.screen),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (error != null) ...[
          Note(error.toString()),
          OutlinedButton.icon(
            onPressed: loadMore,
            icon: const Icon(Icons.refresh),
            label: const Text('목록 다시 불러오기'),
          ),
        ] else if (hasMore && !loading)
          OutlinedButton(onPressed: loadMore, child: const Text('정산 내역 더 보기')),
      ],
    );
  }
}

class _HistoryEntry extends StatefulWidget {
  final Api api;
  final Session session;
  final _HistoryRecord record;
  const _HistoryEntry({
    super.key,
    required this.api,
    required this.session,
    required this.record,
  });

  @override
  State<_HistoryEntry> createState() => _HistoryEntryState();
}

class _HistoryEntryState extends State<_HistoryEntry> {
  Future<dynamic>? finance;
  bool expanded = false;

  String get path =>
      '/events/${Uri.encodeComponent(widget.record.eventId)}/finance';

  void reload() {
    if (!identical(widget.api.session, widget.session)) return;
    final next = widget.api.get(path);
    setState(() {
      finance = next;
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: Text(widget.record.title),
      subtitle: Text(stateLabel(widget.record.status)),
      onExpansionChanged: (value) {
        setState(() => expanded = value);
        if (value) reload();
      },
      children: [
        if (expanded)
          Padding(
            padding: const EdgeInsets.all(Tokens.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<dynamic>(
                  future: finance,
                  builder: (context, snapshot) {
                    if (!identical(widget.api.session, widget.session)) {
                      return const Note('계정이 변경되었습니다. 새 계정의 기록을 다시 열어주세요.');
                    }
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Note(snapshot.error.toString());
                    }
                    try {
                      return _OwnMoney(
                        data: objectValue(snapshot.data),
                        userId: widget.session.userId,
                      );
                    } on FormatException catch (failure) {
                      return Note(failure.message);
                    }
                  },
                ),
                TextButton.icon(
                  onPressed: reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('금액 다시 불러오기'),
                ),
                OutlinedButton(
                  onPressed: () => context.push(path),
                  child: const Text('계산 근거·정정·이의 기록'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _OwnMoney extends StatelessWidget {
  final Json data;
  final String userId;
  const _OwnMoney({required this.data, required this.userId});

  @override
  Widget build(BuildContext context) {
    try {
      final funding = objectValue(data['funding']);
      if (funding['ready'] is! bool) throw const ContractError('funding.ready');
      if (funding['ready'] == false) {
        return const Note(
          '자금 출처 분류 확인이 필요합니다. 개인 금액을 확정해 표시하지 않으며 계산 근거와 남은 업무를 확인할 수 있습니다.',
        );
      }
      final own = objectList(
        funding['positions'],
      ).where((p) => p['userId'] == userId).toList();
      if (own.isEmpty) return const Note('개인 부담 대상이 아닌 담당 기록입니다.');
      if (own.length != 1) {
        throw const ContractError('funding.positions.userId');
      }
      final position = own.single;
      const fields = {
        'obligation': '최종 개인 부담',
        'deposits': '확인 입금',
        'ordinaryRefunded': '지급 기록 환불',
        'personalExpense': '개인 자금 지출',
        'advanceRecovered': '선지출 회수 기록',
        'additional': '추가 납부',
        'ordinaryRefundDue': '일반 환불',
        'advanceDue': '미회수 선지출 반환',
      };
      // Validate the entire own summary before rendering any partial amounts.
      for (final field in fields.keys) {
        integerValue(position[field], 'funding.positions.$field');
      }
      final names = objectValue(data['names']);
      final person = names[userId] == null
          ? null
          : Person({...objectValue(names[userId]), 'userId': userId});
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (person != null)
            Text(
              person.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          if (data['firstRegisteredAt'] != null)
            Text('최초 정산 등록 ${formatTimestamp(data['firstRegisteredAt'])}'),
          for (final field in fields.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.gap),
              child: Text(
                '${field.value} ${won(position[field.key])}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const Text(
            '확인 입금은 신고액과 다릅니다. 일반 환불과 선지출 반환은 구분하며 실제 송금·수령 확인은 원본 정산에서 이어갑니다.',
          ),
        ],
      );
    } on FormatException catch (failure) {
      return Note(failure.message);
    }
  }
}
