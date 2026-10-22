export 'case_screens.dart';
export 'chat_lists.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'api.dart';
import 'main.dart';
import 'widgets.dart';
import 'handover_inbox.dart';
import 'push_controls.dart';
import 'bank_account.dart';
import 'my_extras.dart';
import 'history_panel.dart';
import 'push.dart';

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
    title: '마이',
    actions: [
      IconButton(
        onPressed: () => context.push('/settings'),
        icon: const Icon(Icons.settings_outlined),
        tooltip: '설정',
      ),
    ],
    children: [
      Remote(
        path: '/me',
        builder: (v, r) {
          final me = obj(v);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading('${me['nickname']}님'),
              entry('프로필 수정', onTap: () => context.push('/profile')),
              entry('신고·처리 요청', onTap: () => context.push('/cases')),
            ],
          );
        },
      ),
      const MyLevels(),
      const OperatorEntry(),
      heading('지난 정산 내역'),
      const HistoryPanel(),
    ],
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return PageFrame(
      title: '설정',
      children: [
        const HandoverInbox(),
        const PushControls(),
        Remote(
          path: '/notification-preferences',
          builder: (v, r) => Column(
            children: [
              SwitchListTile(
                title: const Text('푸시 알림'),
                subtitle: const Text('꺼도 인앱 알림함과 업무 기록은 유지됩니다.'),
                value: obj(v)['pushEnabled'] == true,
                onChanged: (value) => actionForm(
                  context,
                  api,
                  title: value ? '푸시 알림 켜기' : '푸시 알림 끄기',
                  path: '/notification-preferences',
                  fields: const [],
                  base: {'pushEnabled': value},
                  reload: r,
                ),
              ),
            ],
          ),
        ),
        heading('계좌·계정'),
        const BankAccountPanel(),
        const Note(
          '개인 계좌 예금주 확인은 별도 공급자 연동이 필요합니다. 미연결 상태를 계좌 확인 완료로 표시하지 않습니다.',
        ),
        OutlinedButton(
          onPressed: () => actionForm(
            context,
            api,
            title: '계정 삭제',
            path: '/me/delete',
            fields: const [],
            reload: () {
              api.clearSession();
            },
            notice:
                '담당 업무 완료 또는 인수·잔여금 실제 수령 확인 후 삭제할 수 있습니다. 계산 마감만으로 삭제 조건이 충족되지는 않습니다.',
          ),
          child: const Text('남은 담당 업무 확인 후 계정 삭제'),
        ),
        OutlinedButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            Object? failure;
            try {
              await ref.read(pushRegistrarProvider)?.disconnect();
            } catch (e) {
              failure = e;
            }
            try {
              await api.auth('/auth/logout', {});
            } catch (e) {
              failure ??= e;
            } finally {
              await api.clearSession();
            }
            if (failure != null && messenger.mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text('로그아웃했습니다. 기기 연결 정리 확인: $failure')),
              );
            }
          },
          child: const Text('로그아웃'),
        ),
      ],
    );
  }
}

String? notificationDestination(Json n) {
  if (n['eventId'] is String) {
    return '/events/${Uri.encodeComponent(n['eventId'])}/finance';
  }
  final group = n['groupKey'];
  if (group is! String) return null;
  final parts = group.split(':');
  if (parts.length != 3 || parts.last.isEmpty) return null;
  if (parts.first == 'chat' && ['request', 'group-invite'].contains(parts[1])) {
    return '/chat';
  }
  if (parts.first == 'social' && ['comments', 'likes'].contains(parts[1])) {
    return '/posts/${Uri.encodeComponent(parts.last)}';
  }
  return null;
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
    title: '알림함',
    children: [
      Remote(
        path: '/notifications',
        builder: (v, r) => Column(
          children: [
            if (rows(v).isEmpty) empty('도착한 알림이 없어요.'),
            for (final n in rows(v))
              entry(
                label(n),
                subtitle:
                    '${const {'MONEY': '정산', 'SOCIAL': '소셜', 'SUPPORT': '처리 안내'}[n['kind']] ?? '알림'} · ${n['count']}건 · ${formatTimestamp(n['createdAt'])}',
                trailing: TextButton(
                  onPressed: () => actionForm(
                    context,
                    ref.read(apiProvider),
                    title: '알림 읽음 처리',
                    path: '/notifications/${n['id']}/read',
                    fields: const [],
                    reload: r,
                  ),
                  child: Text(n['read'] == true ? '읽음' : '읽음 표시'),
                ),
                onTap: notificationDestination(n) == null
                    ? null
                    : () => context.push(notificationDestination(n)!),
              ),
          ],
        ),
      ),
    ],
  );
}

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String id;
  const ChatRoomScreen({super.key, required this.id});
  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen>
    with WidgetsBindingObserver {
  final message = TextEditingController();
  StompClient? client;
  List<Json> messages = [];
  String? error;
  bool loading = true, sending = false, connected = false;
  Command? pending;
  Json? room;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
    connect();
  }

  Future<void> load() async {
    try {
      int cursor = 0;
      final rooms = await ref.read(apiProvider).listAll('/chat/rooms');
      final metadata = rooms.where((v) => v['id'] == widget.id).firstOrNull;
      final incoming = <Json>[];
      while (true) {
        final page = rows(
          await ref
              .read(apiProvider)
              .get('/chat/rooms/${widget.id}/messages?after=$cursor'),
        );
        incoming.addAll(page);
        final next = page.fold<int>(cursor, (highest, row) {
          final sequence = (row['sequence'] as num?)?.toInt() ?? 0;
          return sequence > highest ? sequence : highest;
        });
        if (page.length < 200 || next <= cursor) break;
        cursor = next;
      }
      if (mounted) {
        setState(() {
          final unique = <String, Json>{
            for (final row in incoming) '${row['id']}': row,
          };
          room = metadata;
          messages = unique.values.toList()
            ..sort(
              (a, b) => ((a['sequence'] as num?)?.toInt() ?? 0).compareTo(
                (b['sequence'] as num?)?.toInt() ?? 0,
              ),
            );
          error = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  void connect() {
    final api = ref.read(apiProvider);
    final base = Uri.parse(api.dio.options.baseUrl);
    final url = base
        .replace(
          scheme: base.scheme == 'https' ? 'wss' : 'ws',
          path: '${base.path}/chat/socket',
        )
        .toString();
    client = StompClient(
      config: StompConfig(
        url: url,
        stompConnectHeaders: {'Authorization': 'Bearer ${api.session!.token}'},
        reconnectDelay: const Duration(seconds: 5),
        onConnect: (frame) {
          if (mounted) setState(() => connected = true);
          client!.subscribe(
            destination: '/topic/chat/${widget.id}',
            callback: (frame) {
              if (frame.body != null) {
                try {
                  jsonDecode(frame.body!);
                  unawaited(load());
                } catch (_) {}
              }
            },
          );
          unawaited(load());
        },
        onDisconnect: (_) {
          if (mounted) setState(() => connected = false);
        },
        onWebSocketError: (e) {
          if (mounted) setState(() => connected = false);
        },
        onStompError: (frame) {
          if (mounted) setState(() => connected = false);
        },
      ),
    );
    client!.activate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    client?.deactivate();
    message.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      client?.deactivate();
      connect();
      unawaited(load());
    } else if (state == AppLifecycleState.paused) {
      client?.deactivate();
    }
  }

  Future<void> send() async {
    if (message.text.trim().isEmpty || room?['canWrite'] != true) return;
    setState(() => sending = true);
    final body = message.text.trim();
    if (pending == null || pending!.body['body'] != body) {
      pending = Command('/chat/rooms/${widget.id}/messages', {'body': body});
    }
    try {
      await ref.read(apiProvider).send(pending!);
      message.clear();
      pending = null;
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppBar(
        title: Text(room == null ? '채팅방' : label(room!)),
        actions: [
          IconButton(
            tooltip: '대화 멤버',
            icon: const Icon(Icons.group_outlined),
            onPressed: () => showModalBottomSheet(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              builder: (_) => Padding(
                padding: const EdgeInsets.all(20),
                child: Remote(
                  path: '/chat/rooms/${widget.id}/members',
                  allPages: true,
                  builder: (v, r) => SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        heading('대화 멤버'),
                        for (final member in rows(v))
                          entry(
                            '${member['nickname']}',
                            subtitle: stateLabel(member['status']),
                          ),
                        if (room?['canInvite'] == true)
                          OutlinedButton(
                            onPressed: () => actionForm(
                              context,
                              ref.read(apiProvider),
                              title: '그룹에 초대',
                              path: '/chat/rooms/${widget.id}/invitations',
                              fields: const [
                                FormFieldSpec('userIds', '초대할 사람'),
                              ],
                              reload: r,
                            ),
                            child: const Text('그룹에 초대'),
                          ),
                        if (room?['kind'] == 'GROUP_DM')
                          OutlinedButton(
                            onPressed: () => actionForm(
                              context,
                              ref.read(apiProvider),
                              title: '그룹 대화 나가기',
                              path: '/chat/rooms/${widget.id}/leave',
                              fields: const [],
                              reload: () {
                                Navigator.pop(context);
                                context.go('/chat');
                              },
                              notice: '내 읽기·쓰기·구독 권한이 즉시 끝나며 남은 멤버의 기록은 유지됩니다.',
                            ),
                            child: const Text('그룹 대화 나가기'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '다시 불러오기',
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      Text(connected ? '실시간 연결됨' : '실시간 연결 대기 · 새로고침으로 메시지 확인'),
      if (error != null)
        Padding(padding: const EdgeInsets.all(20), child: Note(error!)),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (messages.isEmpty) empty('아직 메시지가 없어요.'),
                  for (final m in messages)
                    entry(
                      '${m['nickname'] ?? '멤버'}',
                      subtitle:
                          '${m['body']}\n${formatTimestamp(m['createdAt'])}',
                      trailing:
                          m['userId'] != ref.read(apiProvider).session?.userId
                          ? IconButton(
                              tooltip: '이 메시지 신고',
                              icon: const Icon(Icons.flag_outlined),
                              onPressed: () => actionForm(
                                context,
                                ref.read(apiProvider),
                                title: '이 메시지 신고',
                                path: '/reports',
                                fields: const [
                                  FormFieldSpec('reason', '신고 사유'),
                                ],
                                base: {
                                  'type': 'PERSONAL_CONTENT',
                                  'targetUserId': m['userId'],
                                  'contentId': m['id'],
                                  'contentType': 'MESSAGE',
                                },
                                reload: load,
                              ),
                            )
                          : null,
                    ),
                ],
              ),
      ),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: message,
                maxLines: null,
                decoration: const InputDecoration(labelText: '메시지'),
              ),
            ),
            IconButton(
              tooltip: '보내기',
              onPressed: sending || room?['canWrite'] != true ? null : send,
              icon: sending
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.send_outlined),
            ),
          ],
        ),
      ),
    ],
  );
}
