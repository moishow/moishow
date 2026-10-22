import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main.dart';
import 'widgets.dart';

class RequestHistoryPanel extends ConsumerWidget {
  final String path, title;
  const RequestHistoryPanel({
    super.key,
    required this.path,
    required this.title,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => ExpansionTile(
    title: Text(title),
    children: [
      const Note('신청 메모와 거절 사유는 신청자와 검토 담당자에게만 보입니다.'),
      Remote(
        path: path,
        builder: (v, reload) => Column(
          children: [
            if (rows(v).isEmpty) empty('저장된 신청·처리 이력이 없어요.'),
            for (final h in rows(v))
              entry(
                '${h['nickname'] ?? (h['userId'] == ref.read(apiProvider).session?.userId ? '내 신청' : '모임 신청 기록')}${h['departed'] == true ? ' · 탈퇴한 멤버' : ''} · ${stateLabel(h['status'])}',
                subtitle:
                    '${h['memo'].isEmpty ? '신청 메모 없음' : h['memo']}\n${h['reason'].isEmpty ? '처리 사유 없음' : h['reason']}\n${h['actorNickname'] ?? '처리 기록'}${h['actorDeparted'] == true ? ' · 탈퇴한 멤버' : ''} · ${formatTimestamp(h['createdAt'])}',
              ),
          ],
        ),
      ),
    ],
  );
}
