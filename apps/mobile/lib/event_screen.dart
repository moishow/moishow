import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'api.dart';
import 'main.dart';
import 'widgets.dart';
import 'community_widgets.dart';
import 'request_history.dart';
import 'activity_level.dart';

class EventScreen extends ConsumerWidget {
  final String id;
  const EventScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return PageFrame(
      title: '정모·번개',
      children: [
        Remote(
          path: '/events/$id',
          builder: (value, reload) {
            final event = obj(value);
            return Remote(
              path: '/events/$id/access',
              builder: (v, refreshAccess) {
                final access = obj(v);
                final manage =
                    access['manageEvent'] == true ||
                    access['manageSettlement'] == true;
                void act(
                  String title,
                  String path,
                  List<FormFieldSpec> fields,
                  Json base, {
                  String? notice,
                }) => actionForm(
                  context,
                  api,
                  title: title,
                  path: path,
                  fields: fields,
                  base: base,
                  reload: reload,
                  notice: notice,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      label(event),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      '${formatTimestamp(event['startsAt'])} ~ ${formatTimestamp(event['endsAt'])}',
                    ),
                    Text('정산 방식: ${choiceLabels[event['settlementMode']]}'),
                    const SizedBox(height: 20),
                    const Note(
                      '신청 마감과 납부 기한은 별개입니다. 정원 초과는 대기, 마감 뒤에는 본인 합류 요청과 승인이 필요해요. 미납만으로 자동 취소하지 않습니다.',
                    ),
                    if (access['viewSettlement'] == true)
                      entry(
                        '이벤트 최종 정산',
                        onTap: () => context.push('/events/$id/finance'),
                      ),
                    if (access['viewSettlement'] == true)
                      ActivityLevelEntry(
                        clubId: event['clubId'],
                        userId: api.session!.userId,
                      ),
                    RoomLink(
                      eventId: id,
                      open: (room) => context.push('/chat/$room'),
                    ),
                    if (access['manageEvent'] == true)
                      OutlinedButton(
                        onPressed: () => act(
                          '날짜 변경·재참여 의사 확인',
                          '/events/$id/schedule',
                          const [
                            FormFieldSpec(
                              'startsAt',
                              '변경 시작',
                              kind: FieldKind.time,
                            ),
                            FormFieldSpec(
                              'endsAt',
                              '변경 종료',
                              kind: FieldKind.time,
                            ),
                            FormFieldSpec('reason', '변경 사유'),
                          ],
                          {'version': event['version']},
                          notice:
                              '기존 참여는 유지하며 재참여 의사를 확인합니다. 거부한 참가자는 비용 없이 취소·전액 환불 대상이 됩니다.',
                        ),
                        child: const Text('날짜 변경'),
                      ),
                    if (access['manageEvent'] == true)
                      OutlinedButton(
                        onPressed: () => act(
                          '차수 추가',
                          '/events/$id/rounds',
                          const [
                            FormFieldSpec(
                              'capacity',
                              '정원',
                              kind: FieldKind.integer,
                            ),
                            FormFieldSpec(
                              'closesAt',
                              '신청 마감',
                              kind: FieldKind.time,
                            ),
                            FormFieldSpec(
                              'cancellationFee',
                              '고지 취소·노쇼 비용',
                              initial: '0',
                              kind: FieldKind.amount,
                            ),
                          ],
                          {'version': event['version']},
                        ),
                        child: const Text('차수 추가'),
                      ),
                    for (var i = 0; i < rows(event['rounds']).length; i++)
                      Builder(
                        builder: (context) {
                          final round = rows(event['rounds'])[i];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  heading(
                                    '${i + 1}차 · 정원 ${round['capacity']}명',
                                  ),
                                  Text(
                                    '신청 마감 ${formatTimestamp(round['closesAt'])}',
                                  ),
                                  Text(
                                    '취소·노쇼 비용 ${won(round['cancellationFee'])} · 조건 ${round['feeVersion']}',
                                  ),
                                  Text(stateLabel(round['status'])),
                                  if (access['manageEvent'] == true &&
                                      round['status'] != 'CANCELLED')
                                    Wrap(
                                      children: [
                                        TextButton(
                                          onPressed: () => act(
                                            '취소 비용 변경 제안',
                                            '/rounds/${round['id']}/fee',
                                            const [
                                              FormFieldSpec(
                                                'cancellationFee',
                                                '변경 비용',
                                                kind: FieldKind.amount,
                                              ),
                                              FormFieldSpec('reason', '변경 사유'),
                                            ],
                                            {'version': round['version']},
                                            notice:
                                                '이미 신청한 사람은 새 비용에 동의하기 전까지 기존 비용이 유지됩니다. 미응답은 취소 사유가 아닙니다.',
                                          ),
                                          child: const Text('비용 변경 제안'),
                                        ),
                                        TextButton(
                                          onPressed: () => act(
                                            '주최자 차수 취소',
                                            '/rounds/${round['id']}/cancel',
                                            const [
                                              FormFieldSpec('reason', '취소 사유'),
                                            ],
                                            {'version': round['version']},
                                            notice:
                                                '참가자의 고지 비용을 부과하지 않고 실제 납부 전액을 환불 대상으로 남깁니다.',
                                          ),
                                          child: const Text('차수 취소'),
                                        ),
                                      ],
                                    ),
                                  Remote(
                                    path:
                                        '/rounds/${round['id']}/participation',
                                    absent: round['status'] == 'CANCELLED'
                                        ? const Text('취소된 차수입니다.')
                                        : FilledButton(
                                            onPressed: () => act(
                                              '차수 참여 신청',
                                              '/rounds/${round['id']}/participations',
                                              [
                                                if (!DateTime.parse(
                                                  round['closesAt'],
                                                ).isAfter(DateTime.now()))
                                                  const FormFieldSpec(
                                                    'memo',
                                                    '마감 후 합류 요청 메모 (선택)',
                                                    optional: true,
                                                  ),
                                              ],
                                              {'version': round['version']},
                                              notice:
                                                  '고지 취소·노쇼 비용 ${won(round['cancellationFee'])}과 변경 조건에 동의하고 신청합니다. 정원 초과는 대기, 마감 뒤에는 합류 요청으로 접수됩니다.',
                                            ),
                                            child: const Text('이 차수 신청'),
                                          ),
                                    builder: (value, r) {
                                      final p = obj(value);
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          heading(
                                            '내 참여 · ${stateLabel(p['status'])}',
                                          ),
                                          Text(
                                            '내가 동의한 비용 ${won(p['agreedFee'])} · 조건 ${p['agreedFeeVersion']}',
                                          ),
                                          if (p['feeConsent'] == 'PENDING') ...[
                                            const Note(
                                              '비용 변경 동의 대기입니다. 미응답이어도 참여는 유지되고 새 비용은 적용되지 않습니다.',
                                            ),
                                            FilledButton(
                                              onPressed: () => act(
                                                '변경 비용 동의',
                                                '/rounds/${round['id']}/consents/fee',
                                                const [],
                                                {
                                                  'version': p['version'],
                                                  'accepted': true,
                                                },
                                              ),
                                              child: const Text('변경 비용에 동의'),
                                            ),
                                            OutlinedButton(
                                              onPressed: () => act(
                                                '비용 변경 거부·무료 취소',
                                                '/rounds/${round['id']}/consents/fee',
                                                const [],
                                                {
                                                  'version': p['version'],
                                                  'accepted': false,
                                                },
                                              ),
                                              child: const Text(
                                                '비용 변경 거부 · 무료 취소',
                                              ),
                                            ),
                                          ],
                                          if (p['scheduleConsent'] ==
                                              'PENDING') ...[
                                            const Note(
                                              '변경된 일정에 참여할지 확인해주세요. 미응답이어도 참여는 유지됩니다.',
                                            ),
                                            FilledButton(
                                              onPressed: () => act(
                                                '변경 일정 참여',
                                                '/rounds/${round['id']}/consents/schedule',
                                                const [],
                                                {
                                                  'version': p['version'],
                                                  'accepted': true,
                                                },
                                              ),
                                              child: const Text('변경 일정에 참여'),
                                            ),
                                            OutlinedButton(
                                              onPressed: () => act(
                                                '일정 변경 불참·무료 취소',
                                                '/rounds/${round['id']}/consents/schedule',
                                                const [],
                                                {
                                                  'version': p['version'],
                                                  'accepted': false,
                                                },
                                              ),
                                              child: const Text(
                                                '일정 변경 불참 · 무료 취소',
                                              ),
                                            ),
                                          ],
                                          if (![
                                            'CANCELLED',
                                            'NO_SHOW',
                                            'REJECTED',
                                          ].contains(p['status']))
                                            TextButton(
                                              onPressed: () => act(
                                                '본인 참여 취소',
                                                '/rounds/${round['id']}/participations/${p['id']}/cancel',
                                                const [
                                                  FormFieldSpec(
                                                    'reason',
                                                    '취소 사유',
                                                    optional: true,
                                                  ),
                                                ],
                                                {'version': p['version']},
                                                notice:
                                                    '고지한 비용 ${won(p['agreedFee'])}이 적용됩니다. 이미 최초 정산을 등록했다면 원본을 바꾸지 않고 정정 검토 요청으로 남습니다.',
                                              ),
                                              child: const Text('참여 취소'),
                                            ),
                                          if (p['correctionRequestId'] != null)
                                            const Note(
                                              '정정 검토 요청이 접수되었습니다. 원래 기록은 유지됩니다.',
                                            ),
                                          if (p['consentHistory'] is List)
                                            ExpansionTile(
                                              title: const Text('내 동의 이력'),
                                              children: [
                                                for (final h in rows(
                                                  p['consentHistory'],
                                                ))
                                                  entry(
                                                    '${h['kind'] == 'FEE' ? '취소 비용' : '일정'} · ${stateLabel(h['decision'])}',
                                                    subtitle:
                                                        '${formatTimestamp(h['createdAt'])} · 조건 ${h['termVersion']}',
                                                  ),
                                              ],
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    for (final round in rows(event['rounds']))
                      RequestHistoryPanel(
                        path: '/rounds/${round['id']}/request-history',
                        title: access['manageEvent'] == true
                            ? '차수 합류 요청·처리 이력'
                            : '내 차수 합류 요청 이력',
                      ),
                    if (manage)
                      Remote(
                        path: '/events/$id/participations',
                        builder: (v, r) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            heading('참석·합류 확인'),
                            for (final p in rows(v))
                              entry(
                                '${p['nickname']}${p['departed'] == true ? ' · 탈퇴한 멤버' : ''}',
                                subtitle:
                                    '${stateLabel(p['status'])} · 고지 비용 ${won(p['agreedFee'])}',
                                trailing:
                                    access['manageEvent'] == true &&
                                        (p['status'] == 'LATE_REQUESTED' ||
                                            p['status'] == 'CONFIRMED' &&
                                                !DateTime.parse(
                                                  event['startsAt'],
                                                ).isAfter(DateTime.now()))
                                    ? PopupMenuButton<String>(
                                        onSelected: (action) => act(
                                          action == 'approve'
                                              ? '본인 합류 요청 승인'
                                              : action == 'reject'
                                              ? '합류 요청 거절'
                                              : '실제 노쇼 기록',
                                          '/rounds/${p['roundId']}/participations/${p['id']}/$action',
                                          const [
                                            FormFieldSpec('reason', '확인 근거·사유'),
                                          ],
                                          {'version': p['version']},
                                        ),
                                        itemBuilder: (_) => [
                                          if (access['manageEvent'] == true &&
                                              p['status'] == 'LATE_REQUESTED')
                                            const PopupMenuItem(
                                              value: 'approve',
                                              child: Text('합류 승인'),
                                            ),
                                          if (access['manageEvent'] == true &&
                                              p['status'] == 'LATE_REQUESTED')
                                            const PopupMenuItem(
                                              value: 'reject',
                                              child: Text('합류 요청 거절'),
                                            ),
                                          if (access['manageEvent'] == true &&
                                              p['status'] == 'CONFIRMED' &&
                                              !DateTime.parse(
                                                event['startsAt'],
                                              ).isAfter(DateTime.now()))
                                            const PopupMenuItem(
                                              value: 'no-show',
                                              child: Text('실제 노쇼 기록'),
                                            ),
                                        ],
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ),
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
