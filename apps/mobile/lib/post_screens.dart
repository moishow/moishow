import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';
import 'main.dart';
import 'widgets.dart';
import 'attachments.dart';

class PostComposer extends StatefulWidget {
  final Api api;
  final String? clubId;
  final bool canNotice;
  final Json? post;
  final VoidCallback reload;
  const PostComposer({
    super.key,
    required this.api,
    this.clubId,
    this.canNotice = false,
    this.post,
    required this.reload,
  });
  @override
  State<PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<PostComposer> {
  final body = TextEditingController(), photo = TextEditingController();
  final photos = <String>[];
  String kind = 'POST';
  String? error;
  bool busy = false, uncertain = false;
  @override
  void initState() {
    super.initState();
    body.text = widget.post?['body'] ?? '';
    if (widget.post?['photoIds'] is List) {
      photos.addAll(List<String>.from(widget.post!['photoIds']));
    }
    kind = widget.post?['kind'] ?? 'POST';
  }

  @override
  void dispose() {
    body.dispose();
    photo.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (body.text.trim().isEmpty) {
      setState(() => error = '내용을 입력해주세요.');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.api.send(
        Command(
          widget.post == null
              ? '/feed/posts'
              : '/feed/posts/${widget.post!['id']}/edit',
          {
            'body': body.text.trim(),
            'photoIds': List<String>.from(photos),
            if (widget.post != null) 'version': widget.post!['version'],
            if (widget.post == null) ...{
              'kind': kind,
              if (widget.clubId != null) 'clubId': widget.clubId,
            },
          },
        ),
      );
      widget.reload();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          uncertain = e is ApiFailure && (e.status == null || e.status! >= 500);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(widget.post == null ? '글쓰기' : '글 수정'),
          if (widget.canNotice && widget.post == null)
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: '글 종류'),
              items: const [
                DropdownMenuItem(value: 'POST', child: Text('모임 글')),
                DropdownMenuItem(value: 'NOTICE', child: Text('공지')),
              ],
              onChanged: busy || uncertain
                  ? null
                  : (v) => setState(() => kind = v!),
            ),
          TextField(
            controller: body,
            maxLines: 5,
            enabled: !busy && !uncertain,
            decoration: const InputDecoration(labelText: '내용'),
          ),
          const SizedBox(height: 12),
          for (final id in photos)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        showEvidence(context, widget.api, 'file:$id'),
                    child: const Text('첨부 사진 보기'),
                  ),
                ),
                IconButton(
                  tooltip: '첨부 사진 해제',
                  onPressed: busy || uncertain
                      ? null
                      : () => setState(() => photos.remove(id)),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          EvidencePicker(
            api: widget.api,
            path: '/feed/posts',
            controller: photo,
            scope: 'POST',
            clubId: widget.clubId,
            enabled: !busy && !uncertain,
            onUploaded: (reference) => setState(() {
              photos.add(reference.substring(5));
              photo.clear();
            }),
          ),
          if (error != null) Semantics(liveRegion: true, child: Note(error!)),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(uncertain ? '같은 글 요청 재시도' : '서버에 저장'),
          ),
        ],
      ),
    ),
  );
}

class PostDetail extends ConsumerWidget {
  final String id;
  const PostDetail({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Remote(
        path: '/feed/posts/$id',
        builder: (v, reload) {
          final post = obj(v);
          final mine = post['userId'] == api.session!.userId;
          void report(Json item, String contentType) => actionForm(
            context,
            api,
            title: contentType == 'POST' ? '게시글 신고' : '댓글 신고',
            path: '/reports',
            fields: const [FormFieldSpec('reason', '신고 사유')],
            base: {
              'targetUserId': item['userId'],
              'type': post['clubId'] == null
                  ? 'PERSONAL_CONTENT'
                  : 'CLUB_CONTENT',
              if (post['clubId'] != null) 'clubId': post['clubId'],
              'contentId': item['id'],
              'contentType': contentType,
            },
            reload: reload,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading(
                '${post['kind'] == 'NOTICE' ? '공지 · ' : ''}${post['nickname']}',
              ),
              Text('${post['body']}'),
              Text(formatTimestamp(post['createdAt'])),
              if (post['photoIds'] is List)
                for (final file in post['photoIds'])
                  OutlinedButton(
                    onPressed: () => showEvidence(context, api, 'file:$file'),
                    child: const Text('보호 사진 보기'),
                  ),
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => actionForm(
                      context,
                      api,
                      title: post['liked'] == true ? '좋아요 취소' : '좋아요',
                      path: '/feed/posts/$id/like',
                      fields: const [],
                      base: {'enabled': post['liked'] != true},
                      reload: reload,
                    ),
                    child: Text('좋아요 ${post['likeCount']}'),
                  ),
                  if (mine) ...[
                    TextButton(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        useSafeArea: true,
                        isScrollControlled: true,
                        builder: (_) => PostComposer(
                          api: api,
                          clubId: post['clubId'],
                          post: post,
                          reload: reload,
                        ),
                      ),
                      child: const Text('수정'),
                    ),
                    TextButton(
                      onPressed: () => actionForm(
                        context,
                        api,
                        title: '내 글 삭제',
                        path: '/feed/posts/$id/delete',
                        fields: const [],
                        base: {'version': post['version']},
                        reload: reload,
                      ),
                      child: const Text('삭제'),
                    ),
                  ] else ...[
                    TextButton(
                      onPressed: () => report(post, 'POST'),
                      child: const Text('게시글 신고'),
                    ),
                    TextButton(
                      onPressed: () => actionForm(
                        context,
                        api,
                        title: '첫 대화 요청',
                        path: '/chat/direct',
                        fields: const [FormFieldSpec('body', '첫 메시지')],
                        base: {'userId': post['userId']},
                        reload: reload,
                      ),
                      child: const Text('대화 요청'),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (action) => actionForm(
                        context,
                        api,
                        title: action.startsWith('follow') ? '팔로우 설정' : '차단 설정',
                        path:
                            '/users/${post['userId']}/${action.startsWith('follow') ? 'follow' : 'block'}',
                        fields: const [],
                        base: {'enabled': action.endsWith('on')},
                        reload: reload,
                        notice: '차단은 피드·개인 대화에 적용하고 기존 정산·환불·이의 접근은 유지합니다.',
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'follow:on', child: Text('팔로우')),
                        PopupMenuItem(
                          value: 'follow:off',
                          child: Text('팔로우 해제'),
                        ),
                        PopupMenuItem(value: 'block:on', child: Text('차단')),
                        PopupMenuItem(value: 'block:off', child: Text('차단 해제')),
                      ],
                    ),
                  ],
                ],
              ),
              heading('댓글'),
              Remote(
                path: '/feed/posts/$id/comments',
                allPages: true,
                builder: (comments, r) => Column(
                  children: [
                    for (final comment in rows(comments))
                      entry(
                        '${comment['nickname']}',
                        subtitle: '${comment['body']}',
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'report') {
                              report(comment, 'COMMENT');
                              return;
                            }
                            actionForm(
                              context,
                              api,
                              title: action == 'edit' ? '내 댓글 수정' : '내 댓글 삭제',
                              path: '/feed/comments/${comment['id']}/$action',
                              fields: action == 'edit'
                                  ? [
                                      FormFieldSpec(
                                        'body',
                                        '댓글 내용',
                                        initial: '${comment['body']}',
                                      ),
                                    ]
                                  : const [],
                              base: {'version': comment['version']},
                              reload: r,
                            );
                          },
                          itemBuilder: (_) =>
                              comment['userId'] == api.session!.userId
                              ? const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('수정'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('삭제'),
                                  ),
                                ]
                              : const [
                                  PopupMenuItem(
                                    value: 'report',
                                    child: Text('신고'),
                                  ),
                                ],
                        ),
                      ),
                    OutlinedButton(
                      onPressed: () => actionForm(
                        context,
                        api,
                        title: '댓글 작성',
                        path: '/feed/posts/$id/comments',
                        fields: const [FormFieldSpec('body', '댓글 내용')],
                        reload: r,
                      ),
                      child: const Text('댓글 작성'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
