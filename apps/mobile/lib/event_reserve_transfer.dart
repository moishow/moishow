import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main.dart';
import 'widgets.dart';
import 'models.dart';

class EventReserveTransfer extends ConsumerWidget {
  final String eventId;
  const EventReserveTransfer({super.key, required this.eventId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Remote(
    path: '/events/$eventId/reserve-transfer-context',
    builder: (v, reload) {
      final d = obj(v);
      final club = stringValue(d['clubId'], 'reserve.clubId');
      final version = integerValue(d['reserveVersion'], 'reserve.version');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading('이벤트 적립 전환'),
          Text(
            '이 출처의 적립 가능액 ${won(d['sourceAvailable'])} · 실제 전환 한도 ${won(d['maxTransferable'])}',
          ),
          Text('${d['bankName']} ${d['maskedAccount']}'),
          const Note(
            '모임을 탈퇴한 현 담당자도 본인 이벤트의 적립 업무를 처리할 수 있습니다. 다른 적립금 잔액·원장은 이 화면에서 읽지 않습니다. 일반 환불 미수령액을 적립으로 바꾸지 않습니다.',
          ),
          if (d['canDeposit'] == true)
            OutlinedButton(
              onPressed: () => actionForm(
                context,
                ref.read(apiProvider),
                title: '실제 보관금에서 적립 전환 제안',
                path: '/clubs/$club/reserve/deposits',
                fields: const [
                  FormFieldSpec('amount', '전환할 금액', kind: FieldKind.amount),
                  FormFieldSpec('purpose', '적립 출처·목적'),
                ],
                base: {'version': version, 'eventId': eventId},
                reload: reload,
                notice:
                    '제안만으로 적립 잔액이 늘지 않습니다. 외부 송금 기록과 보관 담당자의 실제 수령 확인이 필요합니다.',
              ),
              child: const Text('실제 보관금에서 적립 전환 제안'),
            ),
          Text('보관 담당 ${d['custodianNickname'] ?? '담당자 확인 필요'}'),
          for (final deposit in rows(d['deposits']))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${deposit['purpose']} · ${won(deposit['amount'])} · ${financialStateLabel(deposit['status'])}',
                    ),
                    if (deposit['sentAt'] != null)
                      Text('실제 송금 ${formatTimestamp(deposit['sentAt'])}'),
                    if (deposit['actualAt'] != null)
                      Text('실제 수령 ${formatTimestamp(deposit['actualAt'])}'),
                    for (final stage in const {
                      'sent': '적립 실제 송금 기록',
                      'confirm': '적립 실제 수령 확인',
                    }.entries)
                      if (deposit[stage.key == 'sent'
                              ? 'canMarkSent'
                              : 'canConfirm'] ==
                          true)
                        OutlinedButton(
                          onPressed: () => actionForm(
                            context,
                            ref.read(apiProvider),
                            title: stage.value,
                            path:
                                '/clubs/$club/reserve/entries/${deposit['id']}/${stage.key}',
                            fields: const [
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
                          child: Text(stage.value),
                        ),
                  ],
                ),
              ),
            ),
          ExpansionTile(
            key: ValueKey(version),
            title: const Text('처리 중 적립의 정확 송금 계좌'),
            children: [
              Remote(
                path: '/clubs/$club/reserve/transfer-instructions',
                builder: (b, r) {
                  final bank = obj(b);
                  return Note(
                    '${bank['bankName']} ${bank['accountNumber']}\n예금주 ${bank['holderName']}',
                  );
                },
              ),
            ],
          ),
        ],
      );
    },
  );
}
