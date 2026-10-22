import 'handover_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main.dart';
import 'widgets.dart';

class HandoverInbox extends ConsumerWidget {
  const HandoverInbox({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    final mine = api.session!.userId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('담당 업무·모임장 인수'),
        Remote(
          path: '/me/handovers',
          builder: (v, reload) => Column(
            children: [
              if (rows(v).isEmpty) empty('진행 중인 담당 인계가 없어요.'),
              for (final h in rows(v))
                HandoverReview(handover: h, reload: reload),
            ],
          ),
        ),
        Remote(
          path: '/me/owner-transfers',
          builder: (v, reload) => Column(
            children: [
              for (final transfer in rows(v))
                entry(
                  '모임장 승계 제안',
                  subtitle: '${transfer['status']}',
                  trailing: transfer['candidateId'] == mine
                      ? TextButton(
                          onPressed: () => actionForm(
                            context,
                            api,
                            title: '모임장 승계 수락',
                            path: '/owner-transfers/${transfer['id']}/accept',
                            fields: const [],
                            base: {'version': transfer['version']},
                            reload: reload,
                          ),
                          child: const Text('수락'),
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
