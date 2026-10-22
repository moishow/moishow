import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main.dart';
import 'widgets.dart';

class ParticipationCorrections extends ConsumerWidget {
  final String eventId;
  final int version;
  final VoidCallback reload;
  const ParticipationCorrections({
    super.key,
    required this.eventId,
    required this.version,
    required this.reload,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => ExpansionTile(
    title: const Text('등록 후 참석·취소·노쇼 사실 정정'),
    children: [
      const Note('최초 등록 후에는 원본 계산과 고지·동의 이력을 보존하고 정정을 추가합니다.'),
      Remote(
        path: '/events/$eventId/participations',
        builder: (v, r) => Column(
          children: [
            for (final p in rows(v))
              entry(
                '${p['nickname']}${p['departed'] == true ? ' · 탈퇴한 멤버' : ''} · ${stateLabel(p['status'])}',
                subtitle: '고지 동의 비용 ${won(p['agreedFee'])}',
                onTap: () => actionForm(
                  context,
                  ref.read(apiProvider),
                  title: '실제 참석 사실 정정·기본 분배 재계산',
                  path:
                      '/events/$eventId/finance/participations/${p['id']}/correct',
                  fields: const [
                    FormFieldSpec(
                      'status',
                      '실제 참석 상태',
                      kind: FieldKind.choice,
                      choices: ['CONFIRMED', 'CANCELLED', 'NO_SHOW'],
                    ),
                    FormFieldSpec('reason', '기존 기록과 다른 실제 근거'),
                  ],
                  base: {'version': version, 'adjustments': <dynamic>[]},
                  reload: () {
                    r();
                    reload();
                  },
                  notice:
                      '해당 차수의 기존 개인 조정은 제거하고 실제 참석 명단의 기본 분배로 다시 계산합니다. 고지·동의 비용을 임의 소급 변경하지 않습니다. 필요하면 이어서 개인별 보전 정정을 추가하세요.',
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
