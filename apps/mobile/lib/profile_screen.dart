import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'api.dart';
import 'main.dart';
import 'models.dart';
import 'widgets.dart';
import 'attachments.dart';

List<String> normalizeInterests(String text) {
  final result = text
      .split(',')
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList();
  if (result.length > 20 || result.any((v) => v.length > 30)) {
    throw const FormatException('관심사는 20개 이하, 각 30자 이하로 입력해주세요.');
  }
  return result;
}

class UserProfileScreen extends ConsumerWidget {
  final bool setup;
  const UserProfileScreen({super.key, this.setup = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    final page = PageFrame(
      title: setup ? '첫 설정' : '내 프로필',
      children: [
        if (setup)
          const Note('닉네임은 가입 때 정한 이름입니다. 관심사·소개·본인 전용 사진은 선택이며 건너뛸 수 있어요.'),
        Remote(
          path: '/me/profile',
          builder: (v, reload) => ProfileFields(
            key: ValueKey(obj(v)['version']),
            data: obj(v),
            setup: setup,
            reload: reload,
          ),
        ),
        if (setup)
          TextButton(
            onPressed: () {
              api.needsProfileSetup = false;
              context.go('/');
            },
            child: const Text('선택 설정 건너뛰기'),
          ),
      ],
    );
    return setup
        ? Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: page,
                ),
              ),
            ),
          )
        : page;
  }
}

class ProfileFields extends ConsumerStatefulWidget {
  final Json data;
  final bool setup;
  final VoidCallback reload;
  const ProfileFields({
    super.key,
    required this.data,
    required this.setup,
    required this.reload,
  });
  @override
  ConsumerState<ProfileFields> createState() => _ProfileFieldsState();
}

class _ProfileFieldsState extends ConsumerState<ProfileFields> {
  final form = GlobalKey<FormState>();
  final nickname = TextEditingController(),
      interests = TextEditingController(),
      bio = TextEditingController(),
      avatar = TextEditingController();
  bool busy = false,
      uncertain = false,
      conflict = false,
      avatarChanged = false,
      clearAvatar = false;
  String? error;
  @override
  void initState() {
    super.initState();
    nickname.text = stringValue(widget.data['nickname'], 'profile.nickname');
    if (widget.data['interests'] is! List) {
      throw const ContractError('profile.interests');
    }
    interests.text = List<String>.from(widget.data['interests']).join(', ');
    bio.text = widget.data['bio'] ?? '';
    if (widget.data['avatarFileId'] != null) {
      avatar.text = 'file:${widget.data['avatarFileId']}';
    }
  }

  @override
  void dispose() {
    for (final c in [nickname, interests, bio, avatar]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final api = ref.read(apiProvider);
    try {
      await api.send(
        Command('/me/profile', {
          'version': integerValue(widget.data['version'], 'profile.version'),
          'nickname': nickname.text.trim(),
          'interests': normalizeInterests(interests.text),
          'bio': bio.text,
          if (clearAvatar) 'clearAvatar': true,
          if (!clearAvatar && avatarChanged)
            'avatarFileId': avatar.text.substring(5),
        }),
      );
      if (mounted) {
        api.needsProfileSetup = false;
        if (widget.setup) {
          context.go('/');
        } else {
          widget.reload();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          uncertain = e is ApiFailure && (e.status == null || e.status! >= 500);
          conflict = e is ApiFailure && e.status == 409;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiProvider);
    final enabled = !busy && !uncertain && !conflict;
    return Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: nickname,
            enabled: enabled,
            maxLength: 50,
            decoration: const InputDecoration(labelText: '서비스 닉네임'),
            validator: (v) => (v ?? '').trim().isEmpty ? '닉네임은 필수입니다.' : null,
          ),
          TextFormField(
            controller: interests,
            enabled: enabled,
            decoration: const InputDecoration(labelText: '관심사 · 쉼표로 구분 (선택)'),
            validator: (v) {
              try {
                normalizeInterests(v ?? '');
                return null;
              } catch (e) {
                return (e as FormatException).message;
              }
            },
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final tag in ['산책', '운동', '여행'])
                FilterChip(
                  label: Text(tag),
                  selected: interests.text
                      .split(',')
                      .map((v) => v.trim())
                      .contains(tag),
                  onSelected: enabled
                      ? (selected) => setState(() {
                          final values = normalizeInterests(interests.text);
                          if (selected) {
                            values.add(tag);
                          } else {
                            values.remove(tag);
                          }
                          interests.text = values.toSet().join(', ');
                        })
                      : null,
                ),
            ],
          ),
          TextFormField(
            controller: bio,
            enabled: enabled,
            maxLength: 300,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '소개 (선택)'),
          ),
          heading('내 프로필 사진'),
          const Text('본인에게만 보이는 사진입니다. 사진을 등록해도 다른 사람에게 새 열람 권한이 생기지 않습니다.'),
          EvidencePicker(
            api: api,
            path: '/me/profile',
            scope: 'POST',
            controller: avatar,
            enabled: enabled,
            onRemoved: () => setState(() {
              clearAvatar = true;
              avatarChanged = false;
            }),
            onUploaded: (_) => setState(() {
              avatarChanged = true;
              clearAvatar = false;
            }),
          ),
          if (avatar.text.isNotEmpty)
            TextButton(
              onPressed: enabled
                  ? () => setState(() {
                      clearAvatar = true;
                      avatarChanged = false;
                      avatar.clear();
                    })
                  : null,
              child: const Text('프로필 사진 명시적으로 해제'),
            ),
          if (error != null) Semantics(liveRegion: true, child: Note(error!)),
          if (conflict)
            OutlinedButton(
              onPressed: widget.reload,
              child: const Text('최신 프로필 불러오기'),
            ),
          FilledButton(
            onPressed: busy || conflict ? null : submit,
            child: Text(
              uncertain
                  ? '같은 설정 요청 재시도'
                  : widget.setup
                  ? '선택 설정 저장·시작'
                  : '프로필 저장',
            ),
          ),
        ],
      ),
    );
  }
}
