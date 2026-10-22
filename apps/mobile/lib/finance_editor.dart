import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'widgets.dart';
import 'attachments.dart';
import 'event_composer.dart' show chooseTime;

class PortionDraft {
  String? userId, source, roundId, kind;
  final amount = TextEditingController(), actualAt = TextEditingController();
  void dispose() {
    amount.dispose();
    actualAt.dispose();
  }
}

class FinanceEditor extends StatefulWidget {
  final Api api;
  final String eventId, operation;
  final Json finance, event;
  final Json? report;
  final VoidCallback reload;
  const FinanceEditor({
    super.key,
    required this.api,
    required this.eventId,
    required this.operation,
    required this.finance,
    required this.event,
    required this.reload,
    this.report,
  });
  @override
  State<FinanceEditor> createState() => _FinanceEditorState();
}

class _FinanceEditorState extends State<FinanceEditor> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      title = TextEditingController(),
      reason = TextEditingController(),
      reference = TextEditingController(),
      actualAt = TextEditingController(),
      evidence = TextEditingController();
  final parts = [PortionDraft()];
  String? roundId, error;
  String revisionKind = 'EXPENSE';
  bool busy = false, uncertain = false;
  Command? pending;
  Json people = {};
  bool get receipt =>
      widget.operation == 'VERIFY' || widget.operation == 'RECEIPT_CORRECTION';
  bool get revision => widget.operation == 'REVISION';
  bool get classify => widget.operation == 'CLASSIFY';
  @override
  void initState() {
    super.initState();
    people = {...obj(widget.finance['names'])};
    if (classify) roundId = widget.report!['roundId'];
    if (widget.report != null) {
      amount.text =
          '${widget.operation == 'RECEIPT_CORRECTION' ? widget.report!['amount'] : widget.report!['reportedAmount'] ?? widget.report!['amount']}';
    }
    widget.api
        .get('/clubs/${widget.event['clubId']}/members')
        .then((value) {
          final members = rows(value);
          if (mounted) {
            setState(() {
              for (final p in members) {
                people['${p['userId']}'] = {
                  'nickname': p['nickname'],
                  'departed': false,
                };
              }
            });
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [amount, title, reason, reference, actualAt, evidence]) {
      c.dispose();
    }
    for (final p in parts) {
      p.dispose();
    }
    super.dispose();
  }

  List<Json> get rounds => rows(widget.event['rounds']);
  Json get names => people;
  Json get allocationKinds => receipt
      ? objectValue(widget.report?['allowedAllocationKindsByRound'])
      : {};
  List<String> kindsFor(String? id) =>
      id == null ? [] : List<String>.from(allocationKinds[id] ?? const []);

  Widget text(
    TextEditingController c,
    String name, {
    bool money = false,
    bool signed = false,
    bool optional = false,
    bool date = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      onChanged: c == amount ? (_) => setState(() {}) : null,
      enabled: !busy && !uncertain && !(classify && c == amount),
      readOnly: date,
      onTap: date ? () => chooseTime(context, c) : null,
      keyboardType: money
          ? const TextInputType.numberWithOptions(signed: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: name,
        suffixIcon: date ? const Icon(Icons.calendar_month_outlined) : null,
      ),
      validator: (v) {
        try {
          if ((v ?? '').trim().isEmpty) return optional ? null : '입력해주세요.';
          if (money) parseKrw(v!.trim(), signed: signed);
          if (date) DateTime.parse(v!);
          return null;
        } catch (_) {
          return '원 단위 정수·날짜를 확인해주세요.';
        }
      },
    ),
  );
  Widget person(PortionDraft part) => DropdownButtonFormField<String>(
    isExpanded: true,
    initialValue: part.userId,
    decoration: const InputDecoration(labelText: '지급자'),
    items: names.entries
        .map(
          (e) => DropdownMenuItem(
            value: e.key,
            child: Text(Person({'userId': e.key, ...obj(e.value)}).displayName),
          ),
        )
        .toList(),
    onChanged: busy || uncertain
        ? null
        : (v) => setState(() => part.userId = v),
    validator: (v) => v == null ? '실제 지급자를 선택해주세요.' : null,
  );
  Widget round(String? value, ValueChanged<String?> update) =>
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value,
        decoration: const InputDecoration(labelText: '차수'),
        items: [
          for (var i = 0; i < rounds.length; i++)
            if (!receipt || allocationKinds.containsKey(rounds[i]['id']))
              DropdownMenuItem(
                value: '${rounds[i]['id']}',
                child: Text('${i + 1}차'),
              ),
        ],
        onChanged: busy || uncertain ? null : update,
        validator: (v) => v == null ? '해당 차수를 선택해주세요.' : null,
      );
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    Json body = {
      'version': integerValue(widget.finance['version'], 'book.version'),
    };
    String path = '/events/${widget.eventId}/finance/';
    try {
      final invoice = revision && revisionKind == 'ADJUSTMENTS'
          ? 0
          : parseKrw(amount.text.trim(), signed: revision);
      body['amount'] = invoice;
      if (receipt) {
        path +=
            'reports/${widget.report!['id']}/${widget.operation == 'VERIFY' ? 'verify' : 'correct'}';
        if (widget.operation == 'VERIFY') {
          body['transactionReference'] = reference.text.trim();
        }
        body['actualReceivedAt'] = actualAt.text.isEmpty ? null : actualAt.text;
        body['allocations'] = [
          for (final p in parts)
            {
              'roundId': p.roundId,
              'kind': p.kind,
              'amount': parseKrw(p.amount.text),
            },
        ];
        if (widget.operation == 'RECEIPT_CORRECTION') {
          body['reason'] = reason.text.trim();
        }
      } else {
        body['roundId'] = roundId;
        if (classify) {
          path += 'expenses/${widget.report!['id']}/classify';
          body['reason'] = reason.text.trim();
        } else if (revision) {
          path += 'revisions';
          body['reason'] = reason.text.trim();
        } else {
          path += 'expenses';
          body['title'] = title.text.trim();
        }
        if (revision && revisionKind == 'ADJUSTMENTS') {
          body.remove('amount');
          body['adjustments'] = [
            for (final p in parts)
              {
                'userId': p.userId,
                'amount': parseKrw(p.amount.text, signed: true),
              },
          ];
        } else {
          body['fundings'] = [
            for (final p in parts)
              {
                'paidByUserId': p.userId,
                'source': p.source,
                'amount': parseKrw(p.amount.text, signed: revision),
                if (p.actualAt.text.isNotEmpty) 'actualPaidAt': p.actualAt.text,
              },
          ];
          if (evidence.text.isNotEmpty) body['evidence'] = evidence.text;
        }
      }
      final selected =
          body[receipt
                  ? 'allocations'
                  : revision && revisionKind == 'ADJUSTMENTS'
                  ? 'adjustments'
                  : 'fundings']
              as List;
      int sum = 0;
      for (final p in selected) {
        sum += p['amount'] as int;
        if (sum.abs() > maxKrw) {
          throw const FormatException('합계가 허용 범위를 넘었습니다.');
        }
      }
      if (sum != (revision && revisionKind == 'ADJUSTMENTS' ? 0 : invoice)) {
        throw const FormatException(
          '배분 금액의 합계가 총액과 일치해야 합니다. 개인 조정은 합계 0원이어야 합니다.',
        );
      }
      pending = uncertain ? pending : Command(path, body);
      setState(() {
        busy = true;
        error = null;
      });
      await widget.api.send(pending!);
      widget.reload();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          uncertain = e is ApiFailure && (e.status == null || e.status! >= 500);
        });
        if (e is ApiFailure && e.status == 409) {
          widget.reload();
          Navigator.pop(context);
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading(
              receipt
                  ? '실제 입금·차수별 귀속'
                  : revision
                  ? '원본 보존 정정'
                  : '지출과 실제 자금 출처',
            ),
            const Note(
              '실제 외부 거래를 확인한 근거를 기록합니다. 개인 선지출은 은행 입금으로 꾸미지 않고, 모인 돈 사용과 구분합니다.',
            ),
            if (revision)
              DropdownButtonFormField<String>(
                initialValue: revisionKind,
                decoration: const InputDecoration(labelText: '정정 종류'),
                items: const [
                  DropdownMenuItem(
                    value: 'EXPENSE',
                    child: Text('차수 지출 증감·자금 재분류'),
                  ),
                  DropdownMenuItem(
                    value: 'ADJUSTMENTS',
                    child: Text('차수 참석자별 보전 조정'),
                  ),
                ],
                onChanged: busy || uncertain
                    ? null
                    : (v) => setState(() => revisionKind = v!),
              ),
            if (!receipt) round(roundId, (v) => setState(() => roundId = v)),
            if (!receipt && !revision && !classify) text(title, '지출 항목명'),
            if (!(revision && revisionKind == 'ADJUSTMENTS'))
              text(
                amount,
                receipt ? '실제 확인 입금액' : '총 지출액·증감액',
                money: true,
                signed: revision,
              ),
            if (receipt) ...[
              if (widget.operation == 'VERIFY')
                text(
                  reference,
                  '외부 거래 식별 근거',
                  optional: widget.operation == 'RECEIPT_CORRECTION',
                ),
              text(actualAt, '실제 입금 시각 · 모르면 비워두기', date: true, optional: true),
              const Text('실제 시각을 모르면 납부 지연 판정을 보류합니다.'),
            ],
            if (revision ||
                classify ||
                widget.operation == 'RECEIPT_CORRECTION')
              text(reason, '정정 사유'),
            if (amount.text.trim() == '0' &&
                !(revision && revisionKind == 'ADJUSTMENTS'))
              OutlinedButton(
                onPressed: busy || uncertain
                    ? null
                    : () => setState(() {
                        for (final part in parts) {
                          part.dispose();
                        }
                        parts.clear();
                      }),
                child: const Text('0원 · 배분 없음으로 기록'),
              ),
            if (parts.isEmpty)
              const Note(
                '현재 배분이 없습니다. 0원만 빈 배분으로 제출할 수 있고 양수 기록에는 실제 배분을 추가해야 합니다. 원본은 정정 이력으로 보존합니다.',
              ),
            for (var i = 0; i < parts.length; i++)
              Card(
                key: ObjectKey(parts[i]),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      heading('${i + 1}번째 ${receipt ? '입금 귀속' : '자금 배분'}'),
                      if (receipt) ...[
                        round(
                          parts[i].roundId,
                          (v) => setState(() {
                            parts[i].roundId = v;
                            parts[i].kind = null;
                          }),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: parts[i].kind,
                          decoration: const InputDecoration(labelText: '귀속 종류'),
                          key: ValueKey(
                            '${identityHashCode(parts[i])}:${parts[i].roundId}',
                          ),
                          items: [
                            for (final kind in kindsFor(parts[i].roundId))
                              DropdownMenuItem(
                                value: kind,
                                child: Text(
                                  const {
                                        'ATTENDANCE': '참석 회비',
                                        'CANCELLATION': '실제 수령 취소·노쇼 비용',
                                        'HOST_CONTRIBUTION': '원주최자 부담금',
                                      }[kind] ??
                                      kind,
                                ),
                              ),
                          ],
                          onChanged: busy || uncertain
                              ? null
                              : (v) => setState(() => parts[i].kind = v),
                          validator: (v) => v == null ? '귀속 종류를 선택해주세요.' : null,
                        ),
                      ] else ...[
                        person(parts[i]),
                        if (!(revision && revisionKind == 'ADJUSTMENTS'))
                          DropdownButtonFormField<String>(
                            initialValue: parts[i].source,
                            decoration: const InputDecoration(
                              labelText: '자금 출처',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'PERSONAL',
                                child: Text('지급자 개인 자금'),
                              ),
                              DropdownMenuItem(
                                value: 'EVENT_FUNDS',
                                child: Text('실제 보관 중인 이벤트 수금'),
                              ),
                            ],
                            onChanged: busy || uncertain
                                ? null
                                : (v) => setState(() => parts[i].source = v),
                            validator: (v) =>
                                v == null ? '자금 출처를 직접 선택해주세요.' : null,
                          ),
                      ],
                      text(
                        parts[i].amount,
                        revision && revisionKind == 'ADJUSTMENTS'
                            ? '개인 부담 증감 (합계 0원)'
                            : '해당 배분액',
                        money: true,
                        signed: revision,
                      ),
                      if (!receipt &&
                          !(revision && revisionKind == 'ADJUSTMENTS'))
                        text(
                          parts[i].actualAt,
                          '실제 지출 시각',
                          date: true,
                          optional: true,
                        ),
                      if (parts.length > 1)
                        TextButton(
                          onPressed: busy || uncertain
                              ? null
                              : () =>
                                    setState(() => parts.removeAt(i).dispose()),
                          child: const Text('이 배분 제거'),
                        ),
                    ],
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: busy || uncertain
                  ? null
                  : () => setState(() => parts.add(PortionDraft())),
              icon: const Icon(Icons.add),
              label: const Text('배분 추가'),
            ),
            if (!receipt && !(revision && revisionKind == 'ADJUSTMENTS'))
              EvidencePicker(
                api: widget.api,
                path: '/events/${widget.eventId}/finance/expenses',
                controller: evidence,
                scope: 'EXPENSE',
                enabled: !busy && !uncertain,
              ),
            if (error != null) Semantics(liveRegion: true, child: Note(error!)),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(
                busy
                    ? '서버 기록 확인 중'
                    : uncertain
                    ? '같은 요청 재시도'
                    : '확인하고 기록',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
