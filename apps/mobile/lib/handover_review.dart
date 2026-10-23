import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'main.dart';
import 'transfer_instructions.dart';
import 'widgets.dart';
import 'models.dart';
import 'bank_verification.dart';
import 'api.dart' show Json;

class HandoverReview extends ConsumerWidget {
  final Map<String, dynamic> handover;
  final VoidCallback reload;
  const HandoverReview({
    super.key,
    required this.handover,
    required this.reload,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    final h = handover;
    final me = api.session!.userId;
    final candidate = h['candidateId'] == me;
    final proposer = h['proposerId'] == me;
    final event = h['eventId'] != null;
    final inventory = obj(h['inventory']);
    final names = obj(inventory['names'] ?? h['names'] ?? {});
    String who(dynamic user) =>
        Person({'userId': '$user', ...obj(names['$user'])}).displayName;
    Future<void> change(String action) async {
      Json verified = {};
      String? verifiedOwner;
      if (action == 'confirm' && !event) {
        final owner = api.session?.token;
        final result = await verifyBankAccount(
          context,
          api,
          purpose: 'RESERVE_HANDOVER',
          contextId: h['id'],
        );
        if (result == null || !context.mounted || owner != api.session?.token) {
          return;
        }
        verified = result;
        verifiedOwner = owner;
      }
      if (!context.mounted) return;
      await actionForm(
        context,
        verified.isEmpty ? api : verifiedBankCommandApi(api, verifiedOwner),
        title: action == 'accept'
            ? '명세 전체 인수 수락'
            : action == 'confirm'
            ? '실제 수령·0원 인계 확인'
            : action == 'sent'
            ? '외부 실제 송금 기록'
            : '송금 전 인계 제안 정리',
        path: '/handovers/${h['id']}/$action',
        fields: ['accept', 'decline', 'cancel'].contains(action)
            ? const []
            : [
                const FormFieldSpec('reference', '실제 거래·0원 인계 근거'),
                const FormFieldSpec(
                  'actualAt',
                  '실제 송금·수령 시각',
                  kind: FieldKind.time,
                ),
                if (action == 'confirm')
                  const FormFieldSpec(
                    'confirmedAmount',
                    '실제로 받은 금액 (0원 포함)',
                    kind: FieldKind.amount,
                  ),
              ],
        base: {
          'version': integerValue(h['version'], 'handover.version'),
          ...verified,
        },
        reload: reload,
        notice:
            '실제 받은 현금과 함께 미회수 선지출·일반 환불·남은 업무를 확인합니다. 명세가 바뀐 뒤 실제 수령하면 수령 사실만 보존하고 새 명세를 다시 수락해야 합니다.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading(
              '${event ? '이벤트 정산' : '적립금 보관'} 인계 · ${handoverStateLabel(h['status'])}',
            ),
            Text(
              '${h['proposerNickname'] ?? '기존 담당자'} → ${h['candidateNickname'] ?? '인수 후보'}',
            ),
            Text('${h['inventoryNote']}'),
            Text('원 인계 명세 현금 ${won(h['inventoryAmount'])}'),
            if (inventory['advanceLiabilities'] is List) ...[
              heading('미회수 선지출 반환 의무'),
              if (rows(inventory['advanceLiabilities']).isEmpty)
                const Text('명세에 남은 선지출 반환 의무가 없습니다.'),
              for (final l in rows(inventory['advanceLiabilities']))
                entry(who(l['creditorId']), subtitle: won(l['amount'])),
            ],
            if (inventory['ordinaryRefundLiabilities'] is List) ...[
              heading('참가자 일반 환불 의무'),
              for (final l in rows(inventory['ordinaryRefundLiabilities']))
                entry(who(l['userId']), subtitle: won(l['amount'])),
            ],
            if (inventory['collectionDuties'] is List) ...[
              heading('남은 납부 요청'),
              for (final due in rows(inventory['collectionDuties']))
                entry(who(due['userId']), subtitle: won(due['amount'])),
            ],
            if (inventory['pendingTransactions'] is List) ...[
              heading('미확인·미송금 업무'),
              for (final p in rows(inventory['pendingTransactions']))
                entry(
                  stateLabel(p['status']),
                  subtitle: p['amount'] is int
                      ? won(p['amount'])
                      : '담당 확인이 필요한 업무',
                ),
            ],
            if (h['status'] == 'RECEIVED_STALE') ...[
              const Note(
                '실제 수령은 기록했지만 명세가 바뀌어 권한은 아직 이전되지 않았습니다. 최신 명세를 다시 확인하고 수락해야 합니다.',
              ),
              if (h['currentInventory'] is Map)
                Note(
                  '현재 기존 담당자 보관 현금 ${won(h['currentInventory']['proposerCashHeld'])}\n후보가 이미 받은 현금 ${won(h['currentInventory']['candidateCashHeld'])}은 재송금할 금액이 아닙니다.',
                ),
              if (proposer)
                OutlinedButton(
                  onPressed: () =>
                      context.push('/events/${h['eventId']}/finance'),
                  child: const Text('최신 명세로 다시 인계 제안'),
                ),
              if (candidate)
                OutlinedButton(
                  onPressed: () => actionForm(
                    context,
                    api,
                    title: '변경 명세 거부 후 보관금 반환 요청',
                    path: '/handovers/${h['id']}/returns',
                    fields: const [
                      FormFieldSpec(
                        'amount',
                        '실제로 돌려줄 보관금',
                        kind: FieldKind.amount,
                      ),
                      FormFieldSpec('reason', '반환 사유'),
                    ],
                    base: {
                      'version': integerValue(h['bookVersion'], 'book.version'),
                    },
                    reload: reload,
                  ),
                  child: const Text('받은 보관금 반환 요청'),
                ),
            ],
            if (proposer &&
                h['status'] == 'ACCEPTED' &&
                integerValue(h['inventoryAmount'], 'handover.amount') > 0)
              TransferInstructions(
                path:
                    '/${event ? 'handovers' : 'custodian-handovers'}/${h['id']}/transfer-instructions',
                title: '인계 건의 정확 수령 계좌',
              ),
            if (candidate && h['status'] == 'PROPOSED')
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => change('accept'),
                    child: const Text('명세 전체 인수 수락'),
                  ),
                  TextButton(
                    onPressed: () => change('decline'),
                    child: const Text('제안 거절'),
                  ),
                ],
              ),
            if (proposer && ['PROPOSED', 'ACCEPTED'].contains(h['status']))
              TextButton(
                onPressed: () => change('cancel'),
                child: const Text('실송금 전 제안 취소'),
              ),
            if (proposer &&
                h['status'] == 'ACCEPTED' &&
                h['inventoryAmount'] != 0)
              FilledButton(
                onPressed: () => change('sent'),
                child: const Text('외부 실제 송금 기록'),
              ),
            if (candidate &&
                (h['status'] == 'FUNDS_PENDING' ||
                    h['status'] == 'ACCEPTED' && h['inventoryAmount'] == 0))
              FilledButton(
                onPressed: () => change('confirm'),
                child: const Text('실제 수령·0원 인계 확인'),
              ),
            if (candidate && h['returns'] is List)
              for (final r in rows(h['returns']))
                if (r['status'] == 'REQUESTED')
                  TransferInstructions(
                    path:
                        '/handovers/${h['id']}/returns/${r['id']}/transfer-instructions',
                    title: '반환 건의 정확 수령 계좌',
                  ),
            if (h['returns'] is List)
              for (final returned in rows(h['returns']))
                entry(
                  '보관금 반환 · ${financialStateLabel(returned['status'])}',
                  subtitle: won(returned['amount']),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => actionForm(
                      context,
                      api,
                      title: action == 'sent'
                          ? '보관금 반환 실제 송금'
                          : action == 'confirm'
                          ? '원담당 실제 수령 확인'
                          : '미송금 반환 요청 취소',
                      path:
                          '/handovers/${h['id']}/returns/${returned['id']}/$action',
                      fields: action == 'cancel'
                          ? const []
                          : const [
                              FormFieldSpec('reference', '실제 거래 근거'),
                              FormFieldSpec(
                                'actualAt',
                                '실제 거래 시각',
                                kind: FieldKind.time,
                              ),
                            ],
                      base: {
                        'version': integerValue(
                          h['bookVersion'],
                          'book.version',
                        ),
                      },
                      reload: reload,
                    ),
                    itemBuilder: (_) => [
                      if (candidate &&
                          returned['status'] == 'REQUESTED') ...const [
                        PopupMenuItem(value: 'sent', child: Text('실제 송금 기록')),
                        PopupMenuItem(
                          value: 'cancel',
                          child: Text('미송금 요청 취소'),
                        ),
                      ],
                      if (proposer && returned['status'] == 'SENT')
                        const PopupMenuItem(
                          value: 'confirm',
                          child: Text('실제 수령 확인'),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
