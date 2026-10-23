export 'finance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'main.dart';
import 'widgets.dart';
import 'models.dart';
import 'bank_verification.dart';

const amount = FormFieldSpec('amount', '금액 (원)', kind: FieldKind.amount);
const reason = FormFieldSpec('reason', '처리 사유');
const evidence = FormFieldSpec('evidence', '증빙 참조 (선택)', optional: true);
const actual = FormFieldSpec(
  'actualReceivedAt',
  '실제 입금 시각',
  kind: FieldKind.time,
  optional: true,
);
const transactionFields = [
  FormFieldSpec('reference', '외부 거래 확인 근거'),
  FormFieldSpec('actualAt', '실제 거래 시각', kind: FieldKind.time),
];

class ReserveScreen extends ConsumerWidget {
  final String id;
  const ReserveScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return PageFrame(
      title: '모임 적립금',
      children: [
        const Note(
          '외부 보관 계좌의 기록입니다. 실제 입출금 확인 뒤 잔액에 반영되며 개인 계좌의 다른 거래는 공개되지 않습니다.',
        ),
        Remote(
          path: '/clubs/$id',
          builder: (v, clubReload) {
            final club = obj(v);
            final owner = club['role'] == 'OWNER';
            final admin = owner || club['role'] == 'ADMIN';
            final active = club['status'] == 'ACTIVE';
            void action(
              String title,
              String suffix,
              List<FormFieldSpec> fields,
              Json base,
              VoidCallback reload, {
              String? notice,
            }) => actionForm(
              context,
              api,
              title: title,
              path: '/clubs/$id/$suffix',
              fields: fields,
              base: base,
              reload: reload,
              notice: notice,
            );
            final setup = admin && active
                ? OutlinedButton(
                    onPressed: () => verifiedBankAction(
                      context,
                      api,
                      purpose: 'RESERVE',
                      contextId: id,
                      title: '처음 보관 계좌 등록',
                      path: '/clubs/$id/reserve/account',
                      base: const {'version': 0},
                      reload: clubReload,
                    ),
                    child: const Text('처음 보관 계좌 등록'),
                  )
                : const Note('등록된 보관 계좌가 없습니다.');
            return Remote(
              path: '/clubs/$id/reserve',
              absent: Column(
                children: [
                  setup,
                  if (owner && active)
                    OutlinedButton(
                      onPressed: () => action(
                        '적립금 없는 모임 해산',
                        'dissolve',
                        const [],
                        {
                          'version': integerValue(
                            club['version'],
                            'club.version',
                          ),
                          'ownerReceiptConfirmed': true,
                        },
                        clubReload,
                        notice: '계좌가 없더라도 이벤트 담당자와 계산 마감 조건을 서버에서 확인합니다.',
                      ),
                      child: const Text('모임 해산'),
                    ),
                ],
              ),
              builder: (v, reload) {
                final d = obj(v);
                final version = integerValue(d['version'], 'reserve.version');
                final names = obj(d['names']);
                String person(dynamic id) => names.containsKey(id)
                    ? Person({'id': id, ...obj(names[id])}).displayName
                    : '기록된 담당자';
                void form(
                  String title,
                  String suffix,
                  List<FormFieldSpec> fields, {
                  String? notice,
                }) => action(
                  title,
                  suffix,
                  fields,
                  {'version': version},
                  reload,
                  notice: notice,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      won(d['balance']),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text('사용 가능 ${won(d['available'])}'),
                    Text(
                      '보관 담당 ${d['custodianNickname'] ?? person(d['custodianId'])}',
                    ),
                    Text('${d['bankName']} ${d['maskedAccount']}'),
                    if (integerValue(
                          d['unbackedAmount'],
                          'reserve.unbackedAmount',
                        ) >
                        0)
                      Note(
                        '출처 부족액 ${won(d['unbackedAmount'])}. 새 사용·해산은 막히며 이미 발생한 거래는 별도 사실 기록으로 남깁니다.',
                      ),
                    if (admin)
                      ExpansionTile(
                        title: const Text('정확한 적립 송금 계좌 확인'),
                        children: [
                          Remote(
                            path: '/clubs/$id/reserve/transfer-instructions',
                            builder: (v, r) {
                              final b = obj(v);
                              return Note(
                                '${b['bankName']} ${b['accountNumber']}\n예금주 ${b['holderName']}',
                              );
                            },
                          ),
                        ],
                      ),
                    heading('적립 출처와 사용 내역'),
                    for (final e in rows(d['entries']))
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(label(e)),
                              Text(
                                '${won(e['amount'])} · ${financialStateLabel(e['status'])}',
                              ),
                              Text(
                                '등록 ${person(e['createdBy'])} · ${formatTimestamp(e['createdAt'])}',
                              ),
                              if (e['actualAt'] != null)
                                Text('실제 거래 ${formatTimestamp(e['actualAt'])}'),
                              if (e['actualRecordReason'] != null)
                                Note(
                                  '이미 발생한 거래 기록 사유: ${e['actualRecordReason']}\n기록 시 부족액 ${won(e['unbackedAtActualRecord'])}',
                                ),
                              for (final step in const {
                                'sent': '실제 송금 기록',
                                'confirm': '실제 수령 확인',
                                'execute': '실제 출금 확인',
                                'cancel': '미송금 요청 취소',
                              }.entries)
                                if (e[const {
                                      'sent': 'canMarkSent',
                                      'confirm': 'canConfirm',
                                      'execute': 'canExecute',
                                      'cancel': 'canCancel',
                                    }[step.key]] ==
                                    true)
                                  OutlinedButton(
                                    onPressed: () => form(
                                      step.value,
                                      'reserve/entries/${e['id']}/${step.key}',
                                      step.key == 'cancel'
                                          ? const []
                                          : transactionFields,
                                    ),
                                    child: Text(step.value),
                                  ),
                              if (e['canRecordActual'] == true)
                                OutlinedButton(
                                  onPressed: () => form(
                                    '이미 발생한 거래 기록',
                                    'reserve/entries/${e['id']}/record-actual',
                                    const [
                                      ...transactionFields,
                                      FormFieldSpec(
                                        'actualRecordReason',
                                        '이미 발생한 거래를 지금 기록하는 사유',
                                      ),
                                    ],
                                    notice:
                                        '새 사용 허가가 아닙니다. 이미 발생한 출금만 원래 목적·금액 그대로 기록합니다. 사유와 기록 시 부족액은 모임 부원에게 공개됩니다.',
                                  ),
                                  child: const Text('이미 발생한 거래 기록'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (admin && active) ...[
                      OutlinedButton(
                        onPressed: () => form(
                          '적립금 사용 요청',
                          'reserve/spends',
                          const [amount, FormFieldSpec('purpose', '사용 목적')],
                        ),
                        child: const Text('적립금 사용'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            form('원 이벤트로 실제 반환 요청', 'reserve/reversals', const [
                              FormFieldSpec('eventId', '반환할 출처 이벤트'),
                              amount,
                              FormFieldSpec('purpose', '반환 목적'),
                            ]),
                        child: const Text('출처 이벤트로 반환'),
                      ),
                      OutlinedButton(
                        onPressed: () => verifiedBankAction(
                          context,
                          api,
                          purpose: 'RESERVE',
                          contextId: id,
                          title: '보관 계좌 등록·확인',
                          path: '/clubs/$id/reserve/account',
                          base: {'version': version},
                          reload: reload,
                        ),
                        child: const Text('보관 계좌 설정'),
                      ),
                    ],
                    if (d['custodianId'] == api.session?.userId && active)
                      OutlinedButton(
                        onPressed: () => form(
                          '보관 담당자 인계 제안',
                          'reserve/custodian-handovers',
                          const [
                            FormFieldSpec('candidateId', '새 보관 담당자'),
                            FormFieldSpec('inventoryNote', '인계 내역'),
                          ],
                        ),
                        child: const Text('보관 담당자 인계'),
                      ),
                    if (owner && active) ...[
                      heading('모임 해산'),
                      const Note(
                        '잔여 적립금은 모임장에게 귀속합니다. 실제 지급 정리와 수령 확인 후 해산하며 미납·환불·이의와 기존 담당 업무는 유지됩니다.',
                      ),
                      OutlinedButton(
                        onPressed: () => form(
                          '모임장 귀속 지급 정리',
                          'dissolution/payout',
                          const [],
                        ),
                        child: const Text('잔여 적립금 귀속 정리'),
                      ),
                      OutlinedButton(
                        onPressed: () => action(
                          '모임 해산',
                          'dissolve',
                          const [],
                          {'version': version, 'ownerReceiptConfirmed': true},
                          reload,
                          notice: '모임장 귀속 지급과 실제 수령을 확인한 뒤 진행합니다.',
                        ),
                        child: const Text('실제 확인 후 해산'),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
