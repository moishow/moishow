import 'package:flutter/material.dart';
import 'widgets.dart';
import 'models.dart';

Future<void> showActivityLevel(
  BuildContext context, {
  required String clubId,
  required String userId,
  required String title,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Remote(
      path: '/clubs/$clubId/levels/$userId',
      builder: (v, reload) {
        final d = obj(v);
        final score = integerValue(d['score'], 'level.score');
        if (score > 100) throw const ContractError('레벨 범위가 다릅니다.');
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading('$title · $score점'),
            Text(stringValue(d['historyLabel'], 'level.historyLabel')),
            const Note(
              '금융 신용등급이 아닌 모임 활동 기록입니다. 같은 모임·이벤트 관계 안에서만 확인하며 시각 미확인·이의는 판정을 보류합니다.',
            ),
            for (final h in rows(d['history']))
              entry(
                '${h['role'] == 'HOST'
                    ? '주최'
                    : h['role'] == 'PARTICIPANT'
                    ? '참가'
                    : '활동'} · ${stateLabel(h['outcome'])} · ${integerValue(h['delta'], 'level.delta', signed: true)}',
                subtitle:
                    '${h['reason']}${h['updatedAt'] != null ? '\n${formatTimestamp(h['updatedAt'])}' : ''}',
              ),
          ],
        );
      },
    ),
  ),
);

class ActivityLevelEntry extends StatelessWidget {
  final String clubId, userId;
  const ActivityLevelEntry({
    super.key,
    required this.clubId,
    required this.userId,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () => showActivityLevel(
      context,
      clubId: clubId,
      userId: userId,
      title: '이 모임의 내 활동 레벨',
    ),
    child: const Text('이 모임의 내 활동 레벨'),
  );
}
