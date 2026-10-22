import 'api.dart';
import 'models.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main.dart';
import 'widgets.dart';
import 'attachments.dart';

class CasesScreen extends ConsumerWidget {
  final bool operatorQueue;
  const CasesScreen({super.key, this.operatorQueue = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return PageFrame(
      title: operatorQueue ? '운영 대시보드' : '신고·처리 요청',
      children: [
        Remote(
          path: operatorQueue ? '/operator/cases' : '/support/cases',
          builder: (v, reload) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!operatorQueue)
                OutlinedButton(
                  onPressed: () => actionForm(
                    context,
                    api,
                    title: '사용자 신고',
                    path: '/reports',
                    fields: const [
                      FormFieldSpec('targetUserId', '신고 대상'),
                      FormFieldSpec('reason', '신고 사유'),
                    ],
                    base: const {'type': 'USER'},
                    reload: reload,
                  ),
                  child: const Text('사용자 신고'),
                ),
              if (rows(v).isEmpty) empty('처리 요청이 없어요.'),
              for (final item in rows(v))
                entry(
                  '${item['caseType'] == 'REPORT' ? '신고' : '처리 요청'} · ${stateLabel(item['status'])}',
                  subtitle:
                      '${item['route'] == 'OPERATOR' ? '운영자' : '담당'} 처리 단계',
                  trailing: item['canClaim'] == true
                      ? TextButton(
                          onPressed: () => actionForm(
                            context,
                            api,
                            title: '정확한 사건 담당자로 맡기',
                            path: '/support/cases/${item['id']}/claim',
                            fields: const [],
                            base: {'version': item['version']},
                            reload: reload,
                          ),
                          child: const Text('담당자로 맡기'),
                        )
                      : null,
                  onTap: item['canReadDetails'] == true
                      ? () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => CaseDetail(id: '${item['id']}'),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class CaseDetail extends ConsumerWidget {
  final String id;
  const CaseDetail({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Remote(
        path: '/support/cases/$id',
        builder: (value, reload) {
          final d = obj(value);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading('처리 요청 · ${stateLabel(d['status'])}'),
              Text('${d['reason'] ?? ''}'),
              if (d['contentSnapshot'] != null)
                Note('신고 당시 원문\n${d['contentSnapshot']}'),
              if (d['photoIds'] is List)
                for (final photo in d['photoIds'])
                  OutlinedButton(
                    onPressed: () => showEvidence(context, api, 'file:$photo'),
                    child: const Text('신고 당시 보호 사진'),
                  ),
              for (final h in rows(d['history']))
                entry(
                  choiceLabels[h['action']] ?? '처리 기록',
                  subtitle:
                      '${h['reason']}\n${formatTimestamp(h['createdAt'])}',
                ),
              if (d['canDecide'] == true)
                OutlinedButton(
                  onPressed: () => actionForm(
                    context,
                    api,
                    title: '근거와 처리 결과 기록',
                    path: '/support/cases/$id/decisions',
                    fields: [
                      FormFieldSpec(
                        'action',
                        '처리',
                        kind: FieldKind.choice,
                        choices: [
                          'PROGRESS',
                          'RESOLVE',
                          if (d['contentId'] != null) 'CONTENT_REMOVE',
                          if (d['route'] == 'OPERATOR') ...[
                            'WARN',
                            'RESTRICT',
                            'CORRECTION_REQUEST',
                            'HANDOVER_REQUEST',
                          ],
                        ],
                      ),
                      const FormFieldSpec('reason', '근거·처리 사유'),
                    ],
                    base: {'version': d['version']},
                    reload: reload,
                  ),
                  child: const Text('처리 결과 기록'),
                ),
              if (d['isRequester'] == true && d['status'] != 'RESOLVED')
                OutlinedButton(
                  onPressed: () => actionForm(
                    context,
                    api,
                    title: '무응답 대리·운영자 상향 요청',
                    path: '/support/cases/$id/escalate',
                    fields: const [],
                    base: {'version': d['version']},
                    reload: reload,
                    notice:
                        '현재 처리 단계에서 72시간 진행 안내가 없을 때 요청할 수 있습니다. 최초 회신 목표는 해결·환불 보장이 아닙니다.',
                  ),
                  child: const Text('무응답 상향 요청'),
                ),
              if (d['financialDisputeId'] != null && d['eventId'] != null)
                DisputeDetail(
                  eventId: '${d['eventId']}',
                  id: '${d['financialDisputeId']}',
                ),
            ],
          );
        },
      ),
    );
  }
}

class DisputeDetail extends ConsumerWidget {
  final String eventId, id;
  const DisputeDetail({super.key, required this.eventId, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return Remote(
      path: '/events/$eventId/finance/disputes/$id',
      builder: (v, reload) {
        final d = obj(v);
        void action(
          String suffix,
          String title,
          List<FormFieldSpec> fields,
          Map<String, dynamic> extra,
        ) => actionForm(
          context,
          api,
          title: title,
          path: '/events/$eventId/finance/disputes/$id/$suffix',
          fields: fields,
          base: {'version': d['version'], ...extra},
          reload: reload,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading('이의 · ${stateLabel(d['status'])}'),
            Text('${d['reason'] ?? ''}'),
            if (d['evidence'] != null)
              OutlinedButton(
                onPressed: () => showEvidence(context, api, '${d['evidence']}'),
                child: const Text('당사자·정확 담당자 보호 증빙'),
              ),
            if (d['publicResult'] != null)
              Note(
                '공개 결과: ${d['publicResult']}\n정정 금액 ${won(d['correctionAmount'])}',
              ),
            if (d['canReview'] == true)
              OutlinedButton(
                onPressed: () => action('review', '이의 검토 시작', const [
                  FormFieldSpec('reason', '검토 안내'),
                ], {}),
                child: const Text('검토 시작'),
              ),
            if (d['canAppendFinancialRevision'] == true)
              OutlinedButton(
                onPressed: () => context.push('/events/$eventId/finance'),
                child: const Text('원본 보존 정정 기록 추가'),
              ),
            if (d['canResolve'] == true)
              OutlinedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => DisputeResolution(
                    api: api,
                    eventId: eventId,
                    id: id,
                    data: d,
                    reload: reload,
                  ),
                ),
                child: const Text('인정·반려 결과 기록'),
              ),
            if (d['canWithdraw'] == true)
              OutlinedButton(
                onPressed: () => action(
                  'resolve',
                  '이의 철회',
                  const [FormFieldSpec('reason', '철회 사유')],
                  {'status': 'WITHDRAWN'},
                ),
                child: const Text('내 이의 철회'),
              ),
          ],
        );
      },
    );
  }
}

class DisputeResolution extends StatefulWidget {
  final Api api;
  final String eventId, id;
  final Json data;
  final VoidCallback reload;
  const DisputeResolution({
    super.key,
    required this.api,
    required this.eventId,
    required this.id,
    required this.data,
    required this.reload,
  });
  @override
  State<DisputeResolution> createState() => _DisputeResolutionState();
}

class _DisputeResolutionState extends State<DisputeResolution> {
  final form = GlobalKey<FormState>();
  final reason = TextEditingController(),
      publicResult = TextEditingController();
  String? status, revision, error;
  bool busy = false, uncertain = false;
  Command? pending;
  @override
  void dispose() {
    reason.dispose();
    publicResult.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final linked = rows(
      widget.data['relatedRevisions'],
    ).where((r) => r['id'] == revision).firstOrNull;
    final body = {
      'version': integerValue(widget.data['version'], 'dispute.version'),
      'status': status,
      'reason': reason.text.trim(),
      'publicResult': publicResult.text.trim(),
      'correctionAmount': linked == null
          ? 0
          : integerValue(
              linked['correctionAmount'],
              'revision.correctionAmount',
              signed: true,
            ),
      if (linked != null) 'revisionId': linked['id'],
    };
    pending = uncertain
        ? pending
        : Command(
            '/events/${widget.eventId}/finance/disputes/${widget.id}/resolve',
            body,
          );
    setState(() => busy = true);
    try {
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
  Widget build(BuildContext context) {
    final enabled = !busy && !uncertain;
    return Padding(
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
              heading('이의 처리 결과'),
              const Note(
                '이 화면에서 직접 금액을 바꾸지 않습니다. 이미 저장된 해당 이의의 정정 원본을 연결하거나 금액 변경 없음을 명시합니다.',
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: '결과'),
                items: const [
                  DropdownMenuItem(value: 'ACCEPTED', child: Text('인정')),
                  DropdownMenuItem(value: 'REJECTED', child: Text('반려')),
                ],
                onChanged: enabled ? (v) => setState(() => status = v) : null,
                validator: (v) => v == null ? '결과를 선택해주세요.' : null,
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: '연결할 정정 기록'),
                items: [
                  const DropdownMenuItem(
                    value: 'NONE',
                    child: Text('금액 변경 없음 (0원)'),
                  ),
                  for (final r in rows(widget.data['relatedRevisions']))
                    DropdownMenuItem(
                      value: '${r['id']}',
                      child: Text(
                        '${formatTimestamp(r['createdAt'])} · ${won(r['correctionAmount'])}',
                      ),
                    ),
                ],
                onChanged: enabled ? (v) => setState(() => revision = v) : null,
                validator: (v) =>
                    v == null ? '정정 기록 또는 금액 변경 없음을 선택해주세요.' : null,
              ),
              TextFormField(
                controller: reason,
                enabled: enabled,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '당사자 안내·근거'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? '사유가 필요합니다.' : null,
              ),
              TextFormField(
                controller: publicResult,
                enabled: enabled,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '공개할 처리 결과'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? '공개 결과가 필요합니다.' : null,
              ),
              if (error != null)
                Semantics(liveRegion: true, child: Note(error!)),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(uncertain ? '같은 처리 요청 재시도' : '근거와 결과 기록'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
