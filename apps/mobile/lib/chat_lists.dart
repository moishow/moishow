import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'main.dart';
import 'widgets.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  int roomsRevision = 0;
  void refreshMembership(VoidCallback reload) {
    reload();
    setState(() => roomsRevision++);
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiProvider);
    return PageFrame(
      title: '채팅',
      children: [
        const Note(
          '개인·그룹 대화·모임 상시방·이벤트방을 최근 메시지순으로 표시합니다. 받은 요청과 그룹 초대는 수락하기 전까지 일반 대화와 분리됩니다.',
        ),
        Remote(
          key: ValueKey(roomsRevision),
          path: '/chat/rooms',
          allPages: true,
          builder: (v, reload) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () => actionForm(
                  context,
                  api,
                  title: '개인 대화 요청',
                  path: '/chat/direct',
                  fields: const [
                    FormFieldSpec('userId', '대화 상대'),
                    FormFieldSpec('body', '첫 메시지'),
                  ],
                  reload: reload,
                ),
                child: const Text('개인 대화 시작'),
              ),
              OutlinedButton(
                onPressed: () => actionForm(
                  context,
                  api,
                  title: '그룹 대화 만들기',
                  path: '/chat/groups',
                  fields: const [
                    FormFieldSpec('title', '그룹 이름'),
                    FormFieldSpec('userIds', '초대할 사람'),
                  ],
                  reload: reload,
                ),
                child: const Text('그룹 대화 만들기'),
              ),
              heading('최근 대화'),
              if (rows(v).isEmpty) empty('참여 중인 대화가 없어요.'),
              for (final room in rows(v))
                entry(
                  label(room),
                  subtitle:
                      '${stateLabel(room['kind'])} · ${room['lastMessage'] ?? ''}',
                  onTap: () => context.push('/chat/${room['id']}'),
                ),
            ],
          ),
        ),
        heading('받은 대화 요청'),
        Remote(
          path: '/chat/requests',
          allPages: true,
          builder: (v, reload) => Column(
            children: [
              if (rows(v).isEmpty) empty('받은 대화 요청이 없어요.'),
              for (final room in rows(v))
                entry(
                  label(room),
                  subtitle: '${room['lastMessage']}',
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => actionForm(
                      context,
                      api,
                      title: action == 'accept' ? '대화 요청 수락' : '대화 요청 거절',
                      path: '/chat/rooms/${room['id']}/$action',
                      fields: const [],
                      reload: () => refreshMembership(reload),
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'accept', child: Text('수락')),
                      PopupMenuItem(value: 'decline', child: Text('거절')),
                    ],
                  ),
                ),
            ],
          ),
        ),
        heading('그룹 초대'),
        Remote(
          path: '/chat/invitations',
          allPages: true,
          builder: (v, reload) => Column(
            children: [
              if (rows(v).isEmpty) empty('받은 그룹 초대가 없어요.'),
              for (final room in rows(v))
                entry(
                  label(room),
                  subtitle:
                      '${room['inviterNickname'] ?? '그룹 멤버'}님의 초대 · 수락 후 대화부터 볼 수 있어요.',
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => actionForm(
                      context,
                      api,
                      title: action == 'accept' ? '그룹 초대 수락' : '그룹 초대 거절',
                      path: '/chat/rooms/${room['id']}/invitations/$action',
                      fields: const [],
                      reload: () => refreshMembership(reload),
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'accept', child: Text('수락')),
                      PopupMenuItem(value: 'decline', child: Text('거절')),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
