import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';
import 'main.dart';
import 'widgets.dart';

class PendingInbox extends ConsumerStatefulWidget {
  const PendingInbox({super.key});
  @override
  ConsumerState<PendingInbox> createState() => _PendingInboxState();
}

class _PendingInboxState extends ConsumerState<PendingInbox> {
  late Future<List<Command>> future;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    future = ref.read(apiProvider).pendingCommands();
    if (mounted) setState(() {});
  }

  String name(Command c) => c.path == '/files'
      ? '사진 업로드'
      : c.path.contains('/reports')
      ? '납부 신고·입금 기록'
      : c.path.contains('/refund')
      ? '환불 기록'
      : c.path.contains('/expenses')
      ? '지출 기록'
      : c.path.contains('/handovers')
      ? '담당 인계'
      : c.path.contains('/messages')
      ? '메시지 전송'
      : '업무 기록';
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Command>>(
    future: future,
    builder: (context, s) {
      if (s.hasError) return Note('저장된 요청 복구 오류: ${s.error}');
      if (!s.hasData || s.data!.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading('연결이 끊긴 요청 복구'),
          const Note('서버 처리 여부가 불확실한 요청입니다. 같은 요청 식별자로 확인하며 중복 기록을 만들지 않습니다.'),
          for (final command in s.data!)
            entry(
              name(command),
              subtitle: command.body['amount'] is int
                  ? won(command.body['amount'])
                  : null,
              trailing: TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await ref.read(apiProvider).send(command);
                          error = null;
                        } catch (e) {
                          error = e.toString();
                        } finally {
                          if (mounted) {
                            setState(() => busy = false);
                            load();
                          }
                        }
                      },
                child: const Text('같은 요청 재시도'),
              ),
            ),
          if (error != null) Semantics(liveRegion: true, child: Note(error!)),
        ],
      );
    },
  );
}
