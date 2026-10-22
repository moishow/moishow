import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'main.dart';
import 'widgets.dart';
import 'post_screens.dart';

class Feed extends ConsumerWidget {
  final String? clubId;
  final bool canNotice;
  const Feed({super.key, this.clubId, this.canNotice = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return Remote(
      path: '/feed/posts',
      allPages: true,
      builder: (v, reload) {
        final posts = rows(
          v,
        ).where((p) => clubId == null || p['clubId'] == clubId).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading(clubId == null ? '피드' : '모임 글·공지'),
            OutlinedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                builder: (_) => PostComposer(
                  api: api,
                  clubId: clubId,
                  canNotice: canNotice,
                  reload: reload,
                ),
              ),
              child: const Text('글쓰기'),
            ),
            if (posts.isEmpty) empty('아직 게시글이 없어요.'),
            for (final post in posts)
              if (post['kind'] == 'RECRUITMENT')
                entry(
                  '모집 · ${post['title']}',
                  subtitle: formatTimestamp(post['startsAt']),
                  onTap: () => context.push('/events/${post['eventId']}'),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${post['kind'] == 'NOTICE' ? '공지 · ' : ''}${post['nickname']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${post['body']}'),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => actionForm(
                                context,
                                api,
                                title: post['liked'] == true ? '좋아요 취소' : '좋아요',
                                path: '/feed/posts/${post['id']}/like',
                                fields: const [],
                                base: {'enabled': post['liked'] != true},
                                reload: reload,
                              ),
                              child: Text('좋아요 ${post['likeCount']}'),
                            ),
                            TextButton(
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                useSafeArea: true,
                                isScrollControlled: true,
                                builder: (_) => PostDetail(id: '${post['id']}'),
                              ),
                              child: const Text('글·댓글 보기'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class RoomLink extends StatelessWidget {
  final String? eventId, clubId;
  final void Function(String) open;
  const RoomLink({super.key, this.eventId, this.clubId, required this.open});
  @override
  Widget build(BuildContext context) => Remote(
    path: '/chat/rooms',
    allPages: true,
    builder: (v, r) {
      final list = rows(v)
          .where(
            (room) => eventId != null
                ? room['eventId'] == eventId
                : room['clubId'] == clubId && room['kind'] == 'CLUB',
          )
          .toList();
      return Column(
        children: [
          if (list.isEmpty) empty('접근할 수 있는 채팅방이 없어요. 확정 참가·가입 상태를 확인해주세요.'),
          for (final room in list)
            entry(
              '같은 ${eventId != null ? '이벤트' : '모임'} 채팅방',
              onTap: () => open('${room['id']}'),
            ),
        ],
      );
    },
  );
}
