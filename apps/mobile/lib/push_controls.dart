import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'main.dart';
import 'push.dart';
import 'widgets.dart';

class PushControls extends ConsumerStatefulWidget {
  const PushControls({super.key});
  @override
  ConsumerState<PushControls> createState() => _PushControlsState();
}

class _PushControlsState extends ConsumerState<PushControls> {
  late final PushRegistrar registrar;
  bool owned = false;
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    final shared = ref.read(pushRegistrarProvider);
    owned = shared == null;
    registrar =
        shared ??
        PushRegistrar(ref.read(apiProvider), () {
          if (mounted) context.go('/notifications');
        });
  }

  @override
  void dispose() {
    if (owned) registrar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      OutlinedButton.icon(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                try {
                  await registrar.connect(requestPermission: true);
                  if (mounted) {
                    setState(
                      () => message =
                          '이 기기 알림 등록을 서버에 기록했습니다. 실제 수신은 별도 확인이 필요합니다.',
                    );
                  }
                } catch (e) {
                  if (mounted) setState(() => message = e.toString());
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        icon: const Icon(Icons.notifications_outlined),
        label: const Text('이 기기 푸시 연결'),
      ),
      if (message != null) Semantics(liveRegion: true, child: Note(message!)),
    ],
  );
}
