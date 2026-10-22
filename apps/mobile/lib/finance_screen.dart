import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'api.dart';
import 'main.dart';
import 'models.dart';
import 'widgets.dart';
import 'theme.dart';
import 'attachments.dart';
import 'finance_editor.dart';
import 'case_screens.dart';
import 'transfer_instructions.dart';
import 'participation_corrections.dart';
import 'event_reserve_transfer.dart';
import 'revision_comparison.dart';
import 'activity_level.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  final String id;
  const FinanceScreen({super.key, required this.id});
  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  int epoch = 0;
  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiProvider);
    final id = widget.id;
    return PageFrame(
      title: '이벤트 최종 정산',
      children: [
        Remote(
          path: '/events/$id/access',
          builder: (accessValue, ra) {
            final access = obj(accessValue);
            final manager = access['manageSettlement'] == true;
            return Remote(
              path: '/events/$id',
              builder: (ev, re) {
                final event = obj(ev);
                return Remote(
                  key: ValueKey(epoch),
                  path: '/events/$id/finance',
                  absent: manager
                      ? OutlinedButton(
                          onPressed: () => actionForm(
                            context,
                            api,
                            title: '선택한 정산 방식으로 기록 시작',
                            path: '/events/$id/finance/open',
                            fields: const [],
                            base: {
                              'version': 0,
                              'mode': event['settlementMode'],
                            },
                            reload: () => setState(() => epoch++),
                            notice:
                                '개설 시 선택한 ${choiceLabels[event['settlementMode']]} 방식으로 시작합니다.',
                          ),
                          child: const Text('정산 기록 시작'),
                        )
                      : const Note('담당자가 아직 정산 기록을 시작하지 않았습니다.'),
                  builder: (value, reload) {
                    final snapshot = FinanceSnapshot(value);
                    final d = snapshot.data;
                    final version = snapshot.version;
                    final names = obj(d['names']);
                    final calc = obj(d['calculation']);
                    final funding = d['funding'] is Map
                        ? obj(d['funding'])
                        : null;
                    String who(dynamic user) {
                      final name = names['$user'];
                      if (name == null) throw const ContractError('참가자 이름');
                      return Person({
                        'userId': '$user',
                        ...obj(name),
                      }).displayName;
                    }

                    String roundName(dynamic round) {
                      final list = rows(event['rounds']);
                      final index = list.indexWhere((v) => v['id'] == round);
                      return index < 0 ? '관련 차수' : '${index + 1}차';
                    }

                    void form(
                      String title,
                      String suffix,
                      List<FormFieldSpec> fields, {
                      Json? base,
                      String? notice,
                    }) => actionForm(
                      context,
                      api,
                      title: title,
                      path: suffix.startsWith('/')
                          ? suffix
                          : '/events/$id/finance/$suffix',
                      fields: fields,
                      base: base ?? {'version': version},
                      reload: reload,
                      notice: notice,
                    );
                    void edit(String operation, {Json? report}) =>
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => FinanceEditor(
                            api: api,
                            eventId: id,
                            operation: operation,
                            finance: d,
                            event: event,
                            report: report,
                            reload: reload,
                          ),
                        );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '차수별로 계산하고,\n한 번에 정산해요',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${choiceLabels[d['mode']]} · ${stateLabel(d['status'])}',
                        ),
                        const SizedBox(height: 20),
                        ActivityLevelEntry(
                          clubId: event['clubId'],
                          userId: api.session!.userId,
                        ),
                        if (d['status'] == 'OPEN')
                          const Note(
                            '최초 정산 등록 전 현재 지출 계산입니다. 지출이 0원이어도 별도의 선납 요청은 남아 있을 수 있습니다.',
                          ),
                        if (rows(d['requests']).any(
                          (q) =>
                              q['userId'] == api.session?.userId &&
                              q['status'] != 'SUPERSEDED' &&
                              (q['remaining'] as int) > 0,
                        ))
                          heading('내 납부 요청'),
                        for (final q in rows(d['requests']).where(
                          (q) =>
                              q['userId'] == api.session?.userId &&
                              q['status'] != 'SUPERSEDED' &&
                              (q['remaining'] as int) > 0,
                        ))
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${stateLabel(q['status'])} · 잔여 ${won(q['remaining'])}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  Text(
                                    '납부 기한 ${formatTimestamp(q['deadline'])}',
                                  ),
                                  if (q['status'] == 'PENDING')
                                    const Note(
                                      '신고 확인 대기입니다. 중복 송금 전에 실제 내역을 확인해주세요.',
                                    ),
                                  TransferInstructions(
                                    path:
                                        '/events/$id/finance/requests/${q['id']}/transfer-instructions',
                                    title: '이번 납부의 정확 수령 계좌',
                                  ),
                                  FilledButton(
                                    onPressed: () => form(
                                      '이미 송금한 금액 납부 신고',
                                      'reports',
                                      const [
                                        FormFieldSpec(
                                          'amount',
                                          '실제 송금하고 신고할 금액',
                                          kind: FieldKind.amount,
                                        ),
                                        FormFieldSpec(
                                          'evidence',
                                          '선택 증빙',
                                          optional: true,
                                        ),
                                      ],
                                      base: {
                                        'version': version,
                                        'requestId': q['id'],
                                      },
                                      notice:
                                          '실제 외부 송금 뒤 신고합니다. 신고만으로 입금 확인·완납이 되지 않습니다.',
                                    ),
                                    child: const Text('이미 송금한 금액 신고'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Tokens.blue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '계산된 실제 지출',
                                style: TextStyle(color: Tokens.white),
                              ),
                              Text(
                                won(calc['totalExpense']),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium!
                                    .copyWith(color: Tokens.white),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '실제 송금은 외부에서 진행합니다. 요청과 실입금 확인은 별개입니다.',
                                style: TextStyle(
                                  color: Tokens.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (funding == null || funding['ready'] != true)
                          const Note(
                            '아직 자금 출처 분류가 끝나지 않았습니다. 수취액·개인 선지출·인계 금액을 임의로 정하지 않습니다.',
                          ),
                        if (funding != null && funding['ready'] == true) ...[
                          heading('개인별 최종 순차액'),
                          for (final p in rows(funding['positions']))
                            entry(
                              who(p['userId']),
                              subtitle:
                                  '최종 부담 ${won(p['obligation'])}\n실제 입금 ${won(p['deposits'])} · 개인 자금 지출 ${won(p['personalExpense'])}\n실제 선지출 회수 ${won(p['advanceRecovered'])}\n추가 납부 ${won(p['additional'])} · 일반 환불 ${won(p['ordinaryRefundDue'])}\n미회수 선지출 반환 ${won(p['advanceDue'])}',
                            ),
                          entry(
                            '선지출·실제 보관금과 인계',
                            onTap: () => context.push('/events/$id/advances'),
                          ),
                        ],
                        heading('차수별 계산 근거'),
                        const Text(
                          '실제 받은 취소·노쇼 비용을 지출에서 뺀 금액을 참석자가 나눕니다. 원 단위 나머지는 고정 참가자 순서로 1원씩 배분합니다.',
                        ),
                        for (final r in rows(calc['rounds']))
                          ExpansionTile(
                            title: Text(roundName(r['roundId'])),
                            subtitle: Text(
                              '지출 ${won(r['expense'])} − 실제 수령 취소비 ${won(r['receivedCancellation'])}',
                            ),
                            children: [
                              for (final charge in rows(r['attendeeCharges']))
                                entry(
                                  who(charge['userId']),
                                  subtitle: '부담 ${won(charge['amount'])}',
                                ),
                              entry(
                                '원 단위 적립 잔여',
                                subtitle: won(r['reserveRemainder']),
                              ),
                              entry(
                                '참석자 0명 등 주최자 부담',
                                subtitle: won(r['hostContribution']),
                              ),
                            ],
                          ),
                        if (manager &&
                            d['mode'] == 'PREPAY' &&
                            d['status'] == 'OPEN') ...[
                          heading('차수별 회비 조건과 신청 마감'),
                          for (final round in rows(event['rounds']))
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    heading(roundName(round['id'])),
                                    OutlinedButton(
                                      onPressed: () => form(
                                        '차수 회비·납부 기한 지정',
                                        '/rounds/${round['id']}/payment-requests',
                                        const [
                                          FormFieldSpec(
                                            'amount',
                                            '요청 회비 (0원 가능)',
                                            kind: FieldKind.amount,
                                          ),
                                          FormFieldSpec(
                                            'deadline',
                                            '납부 기한',
                                            kind: FieldKind.time,
                                          ),
                                        ],
                                      ),
                                      child: const Text('회비 조건 저장'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => form(
                                        '신청 마감·확정자 회비 요청',
                                        '/rounds/${round['id']}/billing/close',
                                        const [],
                                        notice:
                                            '설정한 신청 마감 시각 이후 확정자에게만 요청합니다. 기존 요청은 중복 생성하지 않습니다.',
                                      ),
                                      child: const Text('마감된 차수 요청 실행'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        heading('납부 요청과 실제 입금'),
                        if (rows(d['requests']).isEmpty)
                          empty('등록된 납부 요청이 없어요.'),
                        for (final request in rows(d['requests']))
                          entry(
                            '${who(request['userId'])} · ${stateLabel(request['status'])}',
                            subtitle:
                                '요청 ${won(request['amount'])} · 잔여 ${won(request['remaining'])}\n${request['deadline'] == null ? '납부 기한 지정 대기' : formatTimestamp(request['deadline'])}',
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) => action == 'report'
                                  ? form(
                                      '외부 송금 후 납부 신고',
                                      'reports',
                                      const [
                                        FormFieldSpec(
                                          'amount',
                                          '실제 송금 신고액',
                                          kind: FieldKind.amount,
                                        ),
                                        FormFieldSpec(
                                          'evidence',
                                          '송금 증빙',
                                          optional: true,
                                        ),
                                      ],
                                      base: {
                                        'version': version,
                                        'requestId': request['id'],
                                      },
                                      notice:
                                          '복수·초과 입금도 실제 송금한 금액으로 신고할 수 있습니다. 신고만으로 입금 확인이나 완납으로 바뀌지 않습니다.',
                                    )
                                  : form(
                                      '납부 기한 지정·연장',
                                      'requests/${request['id']}/extend',
                                      const [
                                        FormFieldSpec(
                                          'deadline',
                                          '승인 기한',
                                          kind: FieldKind.time,
                                        ),
                                        FormFieldSpec('reason', '승인 근거'),
                                      ],
                                    ),
                              itemBuilder: (_) => [
                                if (request['userId'] == api.session!.userId &&
                                    request['status'] != 'SUPERSEDED')
                                  const PopupMenuItem(
                                    value: 'report',
                                    child: Text('납부 신고'),
                                  ),
                                if (manager &&
                                    request['status'] != 'SUPERSEDED')
                                  const PopupMenuItem(
                                    value: 'extend',
                                    child: Text('기한 지정·연장'),
                                  ),
                              ],
                            ),
                          ),
                        for (final request in rows(d['requests']))
                          if (request['userId'] == api.session!.userId &&
                              ![
                                'PAID',
                                'SUPERSEDED',
                              ].contains(request['status']))
                            TransferInstructions(
                              path:
                                  '/events/$id/finance/requests/${request['id']}/transfer-instructions',
                              title: '내 회비 외부 송금 계좌·예금주 확인',
                            ),
                        for (final report in rows(d['reports']))
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  heading(
                                    '${who(report['userId'])} · ${stateLabel(report['status'])}',
                                  ),
                                  Text(
                                    '신고 ${won(report['reportedAmount'])} · 확인 ${won(report['amount'])}',
                                  ),
                                  Text(
                                    report['actualReceivedAt'] == null
                                        ? '실제 입금 시각 미확인 · 판정 보류'
                                        : '실제 입금 ${formatTimestamp(report['actualReceivedAt'])}',
                                  ),
                                  if (report['reason'] != null)
                                    Text('${report['reason']}'),
                                  if (report['evidence'] != null)
                                    TextButton(
                                      onPressed: () => showEvidence(
                                        context,
                                        api,
                                        '${report['evidence']}',
                                      ),
                                      child: const Text('보호 송금 증빙'),
                                    ),
                                  if (report['allocations'] is List)
                                    for (final allocation in rows(
                                      report['allocations'],
                                    ))
                                      Text(
                                        '${roundName(allocation['roundId'])} ${allocation['kind'] == 'CANCELLATION' ? '취소·노쇼 비용' : '참석 회비'} ${won(allocation['amount'])}',
                                      ),
                                  if (manager && report['status'] == 'PENDING')
                                    Wrap(
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              edit('VERIFY', report: report),
                                          child: const Text('실제 입금·귀속 확인'),
                                        ),
                                        TextButton(
                                          onPressed: () => form(
                                            '신고 반려',
                                            'reports/${report['id']}/reject',
                                            const [
                                              FormFieldSpec('reason', '반려 사유'),
                                            ],
                                          ),
                                          child: const Text('반려'),
                                        ),
                                      ],
                                    ),
                                  if (manager && report['status'] == 'VERIFIED')
                                    TextButton(
                                      onPressed: () => edit(
                                        'RECEIPT_CORRECTION',
                                        report: report,
                                      ),
                                      child: const Text('원본 보존 입금·시각 정정'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        heading('지출 기록'),
                        for (final expense in rows(d['expenses']))
                          entry(
                            '${label(expense)} · ${won(expense['amount'])}',
                            subtitle:
                                '${roundName(expense['roundId'])} · ${expense['evidenceStatus'] == 'NO_EVIDENCE'
                                    ? '증빙 없음'
                                    : expense['evidenceStatus'] == 'ATTACHED'
                                    ? '보호 증빙'
                                    : '증빙 메모'}',
                            trailing: expense['evidence'] != null
                                ? TextButton(
                                    onPressed: () => showEvidence(
                                      context,
                                      api,
                                      '${expense['evidence']}',
                                    ),
                                    child: const Text('증빙 보기'),
                                  )
                                : null,
                          ),
                        for (final expense in rows(d['expenses'])) ...[
                          if (expense['fundings'] is List &&
                              rows(expense['fundings']).isNotEmpty)
                            ExpansionTile(
                              title: Text('${label(expense)} · 실제 자금 출처'),
                              children: [
                                for (final f in rows(expense['fundings']))
                                  entry(
                                    who(f['paidByUserId']),
                                    subtitle:
                                        '${f['source'] == 'PERSONAL' ? '개인 자금 선지출' : '이벤트 수금 사용'} ${won(f['amount'])}\n${f['actualPaidAt'] ?? '지출 시각 미기록'}',
                                  ),
                              ],
                            ),
                          if (manager && expense['fundingStatus'] == 'UNKNOWN')
                            OutlinedButton(
                              onPressed: () =>
                                  edit('CLASSIFY', report: expense),
                              child: Text('${label(expense)} · 미분류 자금 출처 확인'),
                            ),
                        ],
                        if (manager && d['status'] == 'OPEN')
                          OutlinedButton(
                            onPressed: () => edit('EXPENSE'),
                            child: const Text('지출 추가'),
                          ),
                        if (manager && d['status'] == 'OPEN')
                          FilledButton(
                            onPressed: () => form(
                              '최초 정산 등록',
                              'register',
                              const [
                                FormFieldSpec(
                                  'deadline',
                                  '이벤트 최종 납부 기한',
                                  kind: FieldKind.time,
                                ),
                              ],
                              notice:
                                  '종료 후 72시간은 최초 등록 판정 기준이며 참가자의 자동 납부 기한이 아닙니다.',
                            ),
                            child: const Text('최초 정산 등록'),
                          ),
                        if (manager && d['status'] != 'OPEN')
                          OutlinedButton(
                            onPressed: () => edit('REVISION'),
                            child: const Text('원본 보존 정정 추가'),
                          ),
                        if (manager && d['status'] == 'REGISTERED')
                          OutlinedButton(
                            onPressed: () => form(
                              '계산 마감',
                              'close',
                              const [],
                              notice: '계산만 마감합니다. 미납·환불·이의·후속 입금은 계속 처리해야 합니다.',
                            ),
                            child: const Text('계산 마감'),
                          ),
                        if (rows(d['revisions']).isNotEmpty)
                          ExpansionTile(
                            title: const Text('계산 원본·정정 이력'),
                            children: [
                              for (final revision in rows(d['revisions']))
                                entry(
                                  '${revision['reason'] == 'INITIAL' ? '최초 계산 원본' : revision['reason']}',
                                  subtitle: formatTimestamp(
                                    revision['createdAt'],
                                  ),
                                  onTap: () => showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('보존된 계산 비교'),
                                      content: SingleChildScrollView(
                                        child: RevisionComparison(
                                          revision: revision,
                                          nameOf: who,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (manager && d['status'] != 'OPEN')
                          ParticipationCorrections(
                            eventId: id,
                            version: version,
                            reload: reload,
                          ),
                        heading('환불 요청·실제 송금·수령'),
                        if (manager)
                          OutlinedButton(
                            onPressed: () => form('환불 요청 기록', 'refunds', const [
                              FormFieldSpec('userId', '환불 대상'),
                              FormFieldSpec(
                                'amount',
                                '환불 요청액',
                                kind: FieldKind.amount,
                              ),
                            ], notice: '요청 등록만으로 송금 완료가 되지 않습니다.'),
                            child: const Text('환불 요청'),
                          ),
                        if (!manager &&
                            obj(
                                  d['permissions'] ?? {},
                                )['canRequestOwnRefund'] ==
                                true)
                          OutlinedButton(
                            onPressed: () => form(
                              '내 환불 요청',
                              'refunds',
                              const [
                                FormFieldSpec(
                                  'amount',
                                  '환불 요청액',
                                  kind: FieldKind.amount,
                                ),
                              ],
                              base: {
                                'version': version,
                                'userId': api.session!.userId,
                              },
                            ),
                            child: const Text('내 환불 요청'),
                          ),
                        for (final refund in rows(d['refunds']))
                          entry(
                            '${who(refund['userId'])} · ${financialStateLabel(refund['status'])}',
                            subtitle:
                                '요청 ${won(refund['amount'])} · 실제 송금 ${won(refund['sentAmount'])}',
                            trailing: manager && refund['status'] == 'REQUESTED'
                                ? TextButton(
                                    onPressed: () => form(
                                      '외부 송금 후 실제 환불 기록',
                                      'refunds/${refund['id']}/sent',
                                      const [
                                        FormFieldSpec(
                                          'actualSentAt',
                                          '실제 송금 시각',
                                          kind: FieldKind.time,
                                        ),
                                        FormFieldSpec(
                                          'transactionReference',
                                          '거래 식별 근거',
                                        ),
                                        FormFieldSpec(
                                          'amount',
                                          '실제 송금액',
                                          kind: FieldKind.amount,
                                        ),
                                      ],
                                    ),
                                    child: const Text('실제 송금 기록'),
                                  )
                                : refund['userId'] == api.session!.userId &&
                                      refund['status'] == 'SENT'
                                ? TextButton(
                                    onPressed: () => form(
                                      '내 계좌 실제 환불 수령 확인',
                                      'refunds/${refund['id']}/confirm',
                                      const [],
                                      notice: '계좌 입금을 실제 확인한 경우에만 기록해주세요.',
                                    ),
                                    child: const Text('실제 수령 확인'),
                                  )
                                : null,
                          ),
                        if (manager)
                          for (final refund in rows(d['refunds']))
                            if (refund['status'] == 'REQUESTED')
                              TransferInstructions(
                                path:
                                    '/events/$id/finance/refunds/${refund['id']}/transfer-instructions',
                                title: '${who(refund['userId'])} 환불 송금 계좌 확인',
                              ),
                        if (manager &&
                            (d['lateFeesAwaitingChoice'] as int? ?? 0) > 0)
                          OutlinedButton(
                            onPressed: () =>
                                form('늦게 받은 취소 비용 처리', 'late-fees', const [
                                  FormFieldSpec(
                                    'status',
                                    '처리 방식',
                                    kind: FieldKind.choice,
                                    choices: ['REFUND', 'RESERVE'],
                                  ),
                                  FormFieldSpec('reason', '처리 근거'),
                                ]),
                            child: Text(
                              '늦은 취소비 ${won(d['lateFeesAwaitingChoice'])} 처리',
                            ),
                          ),
                        if (manager)
                          ExpansionTile(
                            title: const Text('이 이벤트의 적립금 전환 업무'),
                            children: [EventReserveTransfer(eventId: id)],
                          ),
                        heading('이의와 공개 처리 결과'),
                        if (obj(d['permissions'] ?? {})['canCreateDispute'] ==
                            true)
                          OutlinedButton(
                            onPressed: () => form('이의 제기', 'disputes', const [
                              FormFieldSpec('reason', '이의 사유'),
                              FormFieldSpec(
                                'evidence',
                                '비공개 증빙',
                                optional: true,
                              ),
                            ]),
                            child: const Text('이의 제기'),
                          ),
                        for (final dispute in rows(d['disputes']))
                          entry(
                            stateLabel(dispute['status']),
                            subtitle: dispute['publicResult'] != null
                                ? '공개 결과 ${dispute['publicResult']} · 정정 ${won(dispute['correctionAmount'])}'
                                : '공개된 처리 결과가 없습니다.',
                            onTap:
                                manager ||
                                    dispute['userId'] == api.session!.userId
                                ? () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder: (_) => SingleChildScrollView(
                                      padding: const EdgeInsets.all(20),
                                      child: DisputeDetail(
                                        eventId: id,
                                        id: '${dispute['id']}',
                                      ),
                                    ),
                                  )
                                : null,
                            trailing: dispute['userId'] == api.session!.userId
                                ? TextButton(
                                    onPressed: () => form(
                                      '무응답·정확한 이의 대리 처리 요청',
                                      '/support/requests',
                                      const [
                                        FormFieldSpec('reason', '처리 요청 사유'),
                                      ],
                                      base: {
                                        'eventId': id,
                                        'financialDisputeId': dispute['id'],
                                      },
                                    ),
                                    child: const Text('대리 처리 요청'),
                                  )
                                : null,
                          ),
                        Remote(
                          path: '/events/$id/support/results',
                          builder: (v, r) => Column(
                            children: [
                              for (final result in rows(v))
                                entry(
                                  stateLabel(
                                    result['disputeStatus'] ?? result['status'],
                                  ),
                                  subtitle: result['result'] == null
                                      ? '공개 결과 대기'
                                      : '${result['result']} · 정정 ${won(result['correctionAmount'])}',
                                ),
                            ],
                          ),
                        ),
                        if (manager)
                          OutlinedButton(
                            onPressed: () => form(
                              '정산 담당·잔여금·반환 의무 인계',
                              '/events/$id/handovers',
                              const [
                                FormFieldSpec('candidateId', '인수할 담당자'),
                                FormFieldSpec(
                                  'inventoryAmount',
                                  '명세와 대조한 실제 인계 현금',
                                  kind: FieldKind.amount,
                                ),
                                FormFieldSpec(
                                  'inventoryNote',
                                  '인계 내역·선지출 반환 의무',
                                ),
                              ],
                              base: {
                                'version': d['eventVersion'],
                                'bookVersion': version,
                              },
                              notice:
                                  '수락 후 실제 현금 수령 확인으로 권한을 이전합니다. 기존 주최자의 미회수 선지출 반환 의무는 별도로 남습니다.',
                            ),
                            child: const Text('정산 인계 제안'),
                          ),
                        entry(
                          '진행 중인 인계·모임장 승계 확인',
                          onTap: () => context.push('/settings'),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
