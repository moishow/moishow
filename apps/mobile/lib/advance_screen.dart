import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main.dart';
import 'transfer_instructions.dart';
import 'models.dart';
import 'widgets.dart';

class AdvanceScreen extends ConsumerWidget {
  final String id;
  const AdvanceScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return PageFrame(
      title: '선지출·보관금과 반환 의무',
      children: [
        Remote(
          path: '/events/$id/advances',
          builder: (v, reload) {
            final d = obj(v);
            final version = integerValue(d['version'], 'advance.version');
            final manager = d['responsibleId'] == api.session!.userId;
            final names = obj(d['names']);
            String who(dynamic user) =>
                Person({'userId': '$user', ...obj(names['$user'])}).displayName;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Note(
                  '개인 선지출은 은행 납부와 구분합니다. 담당자가 바뀌어도 기존 지급자에게 돌려줄 의무는 사라지지 않아요. 반환 요청·실송금·채권자 수령 확인을 따로 기록합니다.',
                ),
                CustodyTransfers(id: id),
                heading('미회수 선지출 반환 의무'),
                if (rows(d['liabilities']).isEmpty) empty('남은 선지출 반환 의무가 없어요.'),
                for (final liability in rows(d['liabilities']))
                  entry(
                    who(liability['creditorId']),
                    subtitle: '미회수 ${won(liability['amount'])}',
                    trailing:
                        manager &&
                            liability['creditorId'] != api.session!.userId
                        ? TextButton(
                            onPressed: () => actionForm(
                              context,
                              api,
                              title: '선지출 반환 요청',
                              path: '/events/$id/advances/repayments',
                              fields: const [
                                FormFieldSpec(
                                  'amount',
                                  '반환 요청액',
                                  kind: FieldKind.amount,
                                ),
                                FormFieldSpec('reason', '반환 근거'),
                              ],
                              base: {
                                'version': version,
                                'creditorId': liability['creditorId'],
                              },
                              reload: reload,
                            ),
                            child: const Text('선지출 반환 요청'),
                          )
                        : null,
                  ),
                heading('담당자별 실제 보관금'),
                for (final c in rows(d['custody']))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading(who(c['actorId'])),
                          Text(
                            '실제 보관금 ${won(c['cashHeld'])}\n인계 가능한 현금 ${won(c['transferableCash'])}\n미회수 선지출 ${won(c['advanceDue'])}',
                          ),
                          if (c['deficit'] is int && c['deficit'] > 0)
                            Note(
                              '자금 부족 ${won(c['deficit'])}이 있습니다. 출처·실거래를 정정하기 전 인계할 수 없습니다.',
                            ),
                          if (c['actorId'] == api.session!.userId &&
                              manager &&
                              integerValue(
                                    c['proposedSelfRecovery'],
                                    'selfRecovery',
                                  ) >
                                  0) ...[
                            Text(
                              '선택 가능한 자기 회수 ${won(c['proposedSelfRecovery'])}',
                            ),
                            const Note(
                              '자기 회수는 보관 중인 돈과 내 선지출 채권을 상계하는 명시적 기록입니다. 외부 송금 완료가 아닙니다.',
                            ),
                            OutlinedButton(
                              onPressed: () => actionForm(
                                context,
                                api,
                                title: '보관금에서 내 선지출 회수 기록',
                                path: '/events/$id/advances/self-recoveries',
                                fields: const [
                                  FormFieldSpec(
                                    'amount',
                                    '실제로 상계할 자기 회수액',
                                    kind: FieldKind.amount,
                                  ),
                                  FormFieldSpec('reason', '상계 근거'),
                                ],
                                base: {'version': version},
                                reload: reload,
                              ),
                              child: const Text('보관금에서 내 선지출 회수 기록'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const Text('자기 회수 제안은 선택하기 전 실제 회수나 외부 송금 완료가 아닙니다.'),
                heading('반환 요청·실제 송금·수령 이력'),
                for (final repayment in rows(d['repayments']))
                  entry(
                    '${who(repayment['creditorId'])} · ${financialStateLabel(repayment['status'])}',
                    subtitle:
                        '${won(repayment['amount'])}\n${repayment['sentAt'] == null ? '실제 송금 기록 전' : formatTimestamp(repayment['sentAt'])}',
                    trailing: PopupMenuButton<String>(
                      onSelected: (step) => actionForm(
                        context,
                        api,
                        title: step == 'confirm'
                            ? '선지출 반환 실제 수령 확인'
                            : step == 'sent'
                            ? '외부 송금 후 선지출 반환 기록'
                            : '미송금 반환 요청 취소',
                        path:
                            '/events/$id/advances/repayments/${repayment['id']}/$step',
                        fields: step == 'cancel'
                            ? const []
                            : const [
                                FormFieldSpec('reference', '실제 거래 확인 근거'),
                                FormFieldSpec(
                                  'actualAt',
                                  '실제 송금·수령 시각',
                                  kind: FieldKind.time,
                                ),
                              ],
                        base: {'version': version},
                        reload: reload,
                      ),
                      itemBuilder: (_) => [
                        if (manager &&
                            repayment['status'] == 'REQUESTED') ...const [
                          PopupMenuItem(value: 'sent', child: Text('실제 송금 기록')),
                          PopupMenuItem(
                            value: 'cancel',
                            child: Text('미송금 요청 취소'),
                          ),
                        ],
                        if (repayment['creditorId'] == api.session!.userId &&
                            repayment['status'] == 'SENT')
                          const PopupMenuItem(
                            value: 'confirm',
                            child: Text('실제 수령 확인'),
                          ),
                      ],
                    ),
                  ),
                for (final repayment in rows(d['repayments']))
                  if (manager && repayment['status'] == 'REQUESTED')
                    TransferInstructions(
                      path:
                          '/events/$id/advances/repayments/${repayment['id']}/transfer-instructions',
                      title: '${who(repayment['creditorId'])} 선지출 반환 계좌',
                    ),
                heading('자기 회수 이력'),
                for (final recovery in rows(d['recoveries']))
                  entry(
                    who(recovery['actorId']),
                    subtitle:
                        '명시적 자기 회수 ${won(recovery['amount'])} · ${formatTimestamp(recovery['createdAt'])}',
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class CustodyTransfers extends ConsumerWidget {
  final String id;
  const CustodyTransfers({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return Remote(
      path: '/events/$id/custody-transfers',
      builder: (v, reload) {
        final d = obj(v);
        final names = obj(d['names']);
        final user = api.session?.userId;
        final version = integerValue(d['version'], 'custody.version');
        String name(dynamic id) =>
            Person({'id': id, ...obj(names[id])}).displayName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading('추가 보관금 인계'),
            const Note(
              '과거 사실 정정 뒤 남은 실제 보관금을 현 담당자에게 보냅니다. 담당 권한은 바뀌지 않습니다. 수령자는 서버가 현 담당자로 고정합니다.',
            ),
            Text('현 담당자 ${name(d['responsibleId'])}'),
            if (user != d['responsibleId'])
              OutlinedButton(
                onPressed: () => actionForm(
                  context,
                  api,
                  title: '남은 실제 보관금 인계 요청',
                  path: '/events/$id/custody-transfers',
                  fields: const [
                    FormFieldSpec(
                      'amount',
                      '보낼 실제 보관금',
                      kind: FieldKind.amount,
                    ),
                    FormFieldSpec('reason', '추가 인계 근거'),
                  ],
                  base: {'version': version},
                  reload: reload,
                ),
                child: const Text('남은 보관금 인계 요청'),
              ),
            for (final x in rows(d['transfers']))
              if (x['senderId'] == user && x['status'] == 'REQUESTED')
                TransferInstructions(
                  path:
                      '/events/$id/custody-transfers/${x['id']}/transfer-instructions',
                  title: '현 담당자의 추가 보관금 수령 계좌',
                ),
            for (final x in rows(d['transfers']))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${name(x['senderId'])} → ${name(x['recipientId'])}',
                      ),
                      Text(
                        '${won(x['amount'])} · ${financialStateLabel(x['status'])}',
                      ),
                      if (x['sentAt'] != null)
                        Text('실제 송금 ${formatTimestamp(x['sentAt'])}'),
                      if (x['receivedAt'] != null)
                        Text('실제 수령 ${formatTimestamp(x['receivedAt'])}'),
                      for (final step in ['sent', 'confirm', 'cancel'])
                        if ((step == 'confirm' &&
                                x['recipientId'] == user &&
                                x['status'] == 'SENT') ||
                            (step != 'confirm' &&
                                x['senderId'] == user &&
                                x['status'] == 'REQUESTED'))
                          OutlinedButton(
                            onPressed: () => actionForm(
                              context,
                              api,
                              title: const {
                                'sent': '실제 송금 기록',
                                'confirm': '실제 수령 확인',
                                'cancel': '미송금 요청 취소',
                              }[step]!,
                              path:
                                  '/events/$id/custody-transfers/${x['id']}/$step',
                              fields: step == 'cancel'
                                  ? const []
                                  : const [
                                      FormFieldSpec('reference', '실제 거래 확인 근거'),
                                      FormFieldSpec(
                                        'actualAt',
                                        '실제 거래 시각',
                                        kind: FieldKind.time,
                                      ),
                                    ],
                              base: {'version': version},
                              reload: reload,
                            ),
                            child: Text(
                              const {
                                'sent': '실제 송금 기록',
                                'confirm': '실제 수령 확인',
                                'cancel': '미송금 요청 취소',
                              }[step]!,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
