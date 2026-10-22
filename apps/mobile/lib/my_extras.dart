import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'api.dart';
import 'main.dart';
import 'widgets.dart';

class MyLevels extends ConsumerWidget {
  const MyLevels({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Remote(
    path: '/clubs',
    builder: (v, r) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('모임 레벨'),
        if (rows(v).isEmpty) empty('레벨을 확인할 소속 모임이 없습니다.'),
        for (final club in rows(v))
          entry(
            '${club['name']}',
            subtitle: '모임 참여 이력 · 금융 신용등급이 아닙니다.',
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Remote(
                  path:
                      '/clubs/${club['id']}/levels/${ref.read(apiProvider).session!.userId}',
                  builder: (level, r) {
                    final data = obj(level);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        heading('${club['name']} · ${data['score']}점'),
                        Text('${data['historyLabel']}'),
                        const Note(
                          '최초 50점, 0~100점의 모임 참여 기록입니다. 실제 입금 시각 미확인·이의는 판정을 보류하며 같은 이벤트/역할을 중복 가점하지 않습니다.',
                        ),
                        for (final h in rows(data['history']))
                          entry(
                            '${stateLabel(h['outcome'])} · ${h['delta']}',
                            subtitle: '${h['reason']}',
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class OperatorEntry extends ConsumerStatefulWidget {
  const OperatorEntry({super.key});
  @override
  ConsumerState<OperatorEntry> createState() => _OperatorEntryState();
}

class _OperatorEntryState extends ConsumerState<OperatorEntry> {
  late Future<bool> allowed;
  @override
  void initState() {
    super.initState();
    allowed = ref
        .read(apiProvider)
        .get('/operator/cases')
        .then((_) => true)
        .catchError((Object e) {
          if (e is ApiFailure && e.status == 403) return false;
          throw e;
        });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: allowed,
    builder: (context, s) => s.data == true
        ? entry(
            '운영 대시보드',
            subtitle: '서버가 확인한 운영 권한',
            onTap: () => context.push('/ops'),
          )
        : const SizedBox.shrink(),
  );
}
