export 'event_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'auth.dart';
import 'main.dart';
import 'theme.dart';
import 'widgets.dart';
import 'community_widgets.dart';
import 'pending_inbox.dart';
import 'identity_help.dart';
import 'club_invitation.dart';
import 'club_editor.dart';
import 'attachments.dart';
import 'request_history.dart';
import 'activity_level.dart';
import 'models.dart';
import 'dart:async';
export 'settlement_screens.dart';

String homeTaskRoute(Json task) {
  if (task['kind'] == 'HANDOVER' || task['kind'] == 'OWNER_TRANSFER') {
    return '/settings';
  }
  if (task['kind'] == 'RESERVE' && task['clubId'] is String) {
    return '/clubs/${task['clubId']}/reserve';
  }
  if (task['eventId'] is String) return '/events/${task['eventId']}/finance';
  return '/notifications';
}

class LoginScreen extends StatefulWidget {
  final NativeAuth auth;
  const LoginScreen({super.key, required this.auth});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool busy = false;
  String? error;
  Future<void> login(String provider) async {
    setState(() => busy = true);
    try {
      await widget.auth.login(provider);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                MediaQuery.sizeOf(context).height -
                MediaQuery.paddingOf(context).vertical,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 64,
                      color: Tokens.coral,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '모이는 순간부터\n정산까지, 모이쇼',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text('함께한 돈의 흐름을 분명하게.'),
                    const SizedBox(height: 32),
                    for (final provider in ['KAKAO', 'GOOGLE', 'APPLE'])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton(
                          onPressed: busy ? null : () => login(provider),
                          child: Text(
                            '${{'KAKAO': '카카오', 'GOOGLE': 'Google', 'APPLE': 'Apple'}[provider]}로 계속하기',
                          ),
                        ),
                      ),
                    const KnownProviderHelp(),
                    if (busy) const Center(child: CircularProgressIndicator()),
                    if (widget.auth.api.restoreWarning != null)
                      Note(widget.auth.api.restoreWarning!),
                    if (error != null)
                      Semantics(liveRegion: true, child: Note(error!)),
                    const Text(
                      '소셜 인증과 SMS를 완료해야 가입됩니다. 공급자 설정이 없으면 로그인할 수 없습니다.',
                      style: TextStyle(fontSize: 12, color: Tokens.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class OnboardScreen extends ConsumerStatefulWidget {
  const OnboardScreen({super.key});
  @override
  ConsumerState<OnboardScreen> createState() => _OnboardScreenState();
}

class _OnboardScreenState extends ConsumerState<OnboardScreen> {
  final phone = TextEditingController(),
      code = TextEditingController(),
      nickname = TextEditingController();
  String? challenge, error;
  bool verified = false, busy = false;
  int resendSeconds = 0;
  Timer? resendTimer;
  @override
  void dispose() {
    resendTimer?.cancel();
    phone.dispose();
    code.dispose();
    nickname.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() operation) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiProvider);
    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          title: '전화번호 인증',
          children: [
            const Note('실명·CI를 요구하지 않아요. 다른 소셜 계정에 등록된 번호는 기존 로그인 방식을 이용해주세요.'),
            TextField(
              controller: phone,
              enabled: !busy && challenge == null,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '휴대전화 (01012345678 또는 국가번호)',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy || resendSeconds > 0
                  ? null
                  : () => run(() async {
                      final normalized = normalizePhone(phone.text);
                      final r = await api.auth('/auth/sms', {
                        'phone': normalized,
                      });
                      setState(() {
                        challenge = r['id'];
                        verified = false;
                        resendSeconds = 60;
                        phone.text = normalized;
                      });
                      resendTimer?.cancel();
                      resendTimer = Timer.periodic(const Duration(seconds: 1), (
                        timer,
                      ) {
                        if (!mounted) {
                          timer.cancel();
                          return;
                        }
                        setState(() => resendSeconds--);
                        if (resendSeconds <= 0) timer.cancel();
                      });
                    }),
              child: Text(
                resendSeconds > 0
                    ? 'SMS 다시 보내기 · $resendSeconds초'
                    : challenge == null
                    ? 'SMS 보내기'
                    : 'SMS 다시 보내기',
              ),
            ),
            if (challenge != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: '인증번호 6자리'),
              ),
              OutlinedButton(
                onPressed: busy || verified
                    ? null
                    : () => run(() async {
                        final r = await api.auth(
                          '/auth/sms/$challenge/verify',
                          {'code': code.text},
                        );
                        setState(() => verified = r['verified'] == true);
                      }),
                child: Text(verified ? '번호 확인됨' : '번호 확인'),
              ),
            ],
            if (verified) ...[
              TextField(
                controller: nickname,
                decoration: const InputDecoration(labelText: '서비스 닉네임'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        if (nickname.text.trim().isEmpty) {
                          throw const FormatException('닉네임을 입력해주세요.');
                        }
                        api.needsProfileSetup = true;
                        await api.saveSession(
                          obj(
                            await api.auth('/auth/register', {
                              'nickname': nickname.text.trim(),
                              'verificationId': challenge,
                            }),
                          ),
                        );
                      }),
                child: const Text('가입 완료'),
              ),
            ],
            if (error != null) Note(error!),
            TextButton(
              onPressed: busy ? null : () => api.clearSession(),
              child: const Text('로그인으로 돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime day = DateTime.now();
  @override
  Widget build(BuildContext context) => PageFrame(
    title: '홈',
    actions: [
      IconButton(
        tooltip: '알림함',
        onPressed: () => context.push('/notifications'),
        icon: const Icon(Icons.notifications_none),
      ),
    ],
    children: [
      Remote(
        path: '/me',
        builder: (v, r) => Text(
          '${obj(v)['nickname']}님,\n오늘 챙길 일이 있어요',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      const SizedBox(height: 20),
      Remote(
        path:
            '/home?date=${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        builder: (v, reload) {
          final d = obj(v);
          final tasks = rows(d['tasks']);
          final upcoming = rows(d['upcoming']);
          final monday = DateTime(
            day.year,
            day.month,
            day.day - day.weekday + 1,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Tokens.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '지금 처리할 정산 할 일',
                      style: TextStyle(color: Tokens.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${tasks.length}',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium!.copyWith(color: Tokens.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '요청과 실제 송금·수령 확인은 별개입니다.',
                      style: TextStyle(color: Tokens.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const PendingInbox(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Tokens.sunken,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${day.year}년 ${day.month}월'),
                        IconButton(
                          tooltip: '다른 날짜 선택',
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: day,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (date != null && mounted) {
                              setState(() => day = date);
                            }
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                      ],
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < 7; i++)
                            Padding(
                              padding: EdgeInsets.zero,
                              child: Semantics(
                                button: true,
                                selected:
                                    monday.add(Duration(days: i)).day ==
                                    day.day,
                                label:
                                    '${monday.add(Duration(days: i)).month}월 ${monday.add(Duration(days: i)).day}일 ${const ['월', '화', '수', '목', '금', '토', '일'][i]}요일',
                                child: InkWell(
                                  onTap: () => setState(
                                    () => day = monday.add(Duration(days: i)),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color:
                                          monday.add(Duration(days: i)).day ==
                                              day.day
                                          ? Tokens.blue
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${monday.add(Duration(days: i)).day} ${const ['월', '화', '수', '목', '금', '토', '일'][i]}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            monday.add(Duration(days: i)).day ==
                                                day.day
                                            ? Tokens.white
                                            : Tokens.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              heading('지금 할 일'),
              if (tasks.isEmpty) empty('처리할 정산 업무가 없어요.'),
              for (final task in tasks)
                entry(
                  label(task),
                  subtitle:
                      const {
                        'PAYMENT': '납부 신고',
                        'VERIFY_PAYMENT': '입금 확인',
                        'SEND_REFUND': '환불 송금',
                        'REFUND': '환불 수령 확인',
                        'DISPUTE': '이의 처리',
                        'REGISTER_SETTLEMENT': '최초 정산 등록',
                        'HANDOVER': '인계 확인',
                        'RESERVE': '적립금 확인',
                        'OWNER_TRANSFER': '모임장 승계',
                      }[task['kind']] ??
                      '담당 업무 확인',
                  onTap: () => context.push(homeTaskRoute(task)),
                ),
              heading('선택한 날짜의 일정'),
              if (upcoming.isEmpty) empty('선택한 날짜에 예정된 일정이 없어요.'),
              for (final event in upcoming)
                entry(
                  label(event),
                  subtitle: formatTimestamp(event['startsAt']),
                  onTap: () => context.push('/events/${event['id']}'),
                ),
              OutlinedButton(
                onPressed: () => context.push('/clubs'),
                child: const Text('내 모임'),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String query = '', regionQuery = '', categoryQuery = '';
  final search = TextEditingController(),
      region = TextEditingController(),
      category = TextEditingController();
  void apply() => setState(() {
    query = search.text.trim();
    regionQuery = region.text.trim();
    categoryQuery = category.text.trim();
  });
  @override
  void dispose() {
    search.dispose();
    region.dispose();
    category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: '모임 탐색',
    children: [
      Text('새로운 모임을\n찾아보세요', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 20),
      TextField(
        controller: search,
        decoration: InputDecoration(
          labelText: '모임 이름 검색',
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: apply,
          ),
        ),
        onSubmitted: (_) => apply(),
      ),
      TextField(
        controller: region,
        maxLength: 100,
        decoration: const InputDecoration(
          labelText: '지역 (선택)',
          helperText: '모임에 등록된 지역 이름으로 찾습니다.',
        ),
        onSubmitted: (_) => apply(),
      ),
      TextField(
        controller: category,
        maxLength: 100,
        decoration: const InputDecoration(
          labelText: '분류 (선택)',
          helperText: '모임에 등록된 관심 분류로 찾습니다.',
        ),
        onSubmitted: (_) => apply(),
      ),
      const SizedBox(height: 20),
      Remote(
        path: Uri(
          path: '/clubs/discover',
          queryParameters: {
            'q': query,
            'region': regionQuery,
            'category': categoryQuery,
          },
        ).toString(),
        allPages: true,
        builder: (data, reload) {
          final list = rows(data);
          return Column(
            children: [
              if (list.isEmpty) empty('검색 결과가 없어요.'),
              for (final club in list)
                entry(
                  label(club),
                  subtitle:
                      '${club['joinMode'] == 'APPROVAL' ? '승인 후 가입' : '바로 가입'}${club['activeMemberCount'] is int ? ' · ${club['activeMemberCount']}명' : ''}\n${club['region'] ?? ''} · ${club['category'] ?? ''}',
                  onTap: () => context.push('/clubs/${club['id']}'),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class ClubsScreen extends ConsumerWidget {
  const ClubsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
    title: '내 모임',
    children: [
      Remote(
        path: '/clubs',
        builder: (data, reload) => Column(
          children: [
            FilledButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => ClubEditor(
                  api: ref.read(apiProvider),
                  onDone: (id) => context.push('/clubs/$id'),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('모임 만들기'),
            ),
            const SizedBox(height: 20),
            if (rows(data).isEmpty) empty('아직 가입한 모임이 없어요.'),
            for (final club in rows(data))
              entry(
                label(club),
                subtitle:
                    '${stateLabel(club['role'])} · ${stateLabel(club['membershipStatus'])}',
                onTap: () => context.push('/clubs/${club['id']}'),
              ),
          ],
        ),
      ),
    ],
  );
}

class ClubScreen extends ConsumerWidget {
  final String id;
  const ClubScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return PageFrame(
      title: '모임',
      children: [
        Remote(
          path: '/clubs/$id',
          builder: (value, reload) {
            final club = obj(value);
            final active = club['membershipStatus'] == 'ACTIVE';
            final open = club['status'] == 'ACTIVE';
            final admin =
                open && active && ['OWNER', 'ADMIN'].contains(club['role']);
            final owner = club['role'] == 'OWNER';
            void form(
              String title,
              String path,
              List<FormFieldSpec> fields, {
              Json? base,
            }) => actionForm(
              context,
              api,
              title: title,
              path: path,
              fields: fields,
              base: base ?? {'version': club['version']},
              reload: reload,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label(club),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  '${club['joinMode'] == 'APPROVAL' ? '승인제 모임' : '즉시 가입 모임'} · ${stateLabel(club['membershipStatus'])}',
                ),
                if (club['description'] is String &&
                    club['description'].isNotEmpty)
                  Text(club['description']),
                if (club['region'] is String || club['category'] is String)
                  Text('${club['region'] ?? ''} · ${club['category'] ?? ''}'),
                if (club['activeMemberCount'] is int)
                  Text('활성 부원 ${club['activeMemberCount']}명'),
                if (club['imageFileId'] != null)
                  OutlinedButton(
                    onPressed: () => showEvidence(
                      context,
                      api,
                      'file:${club['imageFileId']}',
                    ),
                    child: const Text('모임 대표 사진 보기'),
                  ),
                if (admin)
                  OutlinedButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => ClubEditor(
                        api: api,
                        club: club,
                        onDone: (_) => reload(),
                      ),
                    ),
                    child: const Text('모임 소개 수정'),
                  ),
                const SizedBox(height: 20),
                if (!open)
                  const Note('해산된 모임입니다. 기존 정산·환불·인계·적립금 기록과 담당 업무는 유지됩니다.'),
                if (!active && open)
                  FilledButton(
                    onPressed: club['membershipStatus'] == 'PENDING'
                        ? null
                        : () => form('모임 가입', '/clubs/$id/join', const [
                            FormFieldSpec('nickname', '모임별 닉네임'),
                            FormFieldSpec(
                              'memo',
                              '가입 신청 메모 (선택)',
                              optional: true,
                            ),
                            FormFieldSpec(
                              'inviteToken',
                              '초대 토큰',
                              optional: true,
                            ),
                          ]),
                    child: Text(
                      club['membershipStatus'] == 'PENDING'
                          ? '가입 승인 대기'
                          : '모임 가입하기',
                    ),
                  ),
                RequestHistoryPanel(
                  path: '/clubs/$id/join-history',
                  title: admin ? '가입 신청·처리 이력' : '내 가입 신청 이력',
                ),
                if (active) ...[
                  if (open)
                    OutlinedButton(
                      onPressed: () => form(
                        '모임별 닉네임 수정',
                        '/clubs/$id/nickname',
                        const [FormFieldSpec('nickname', '모임에서 사용할 이름')],
                      ),
                      child: const Text('모임별 닉네임 수정'),
                    ),
                  if (open)
                    RoomLink(
                      clubId: id,
                      open: (room) => context.push('/chat/$room'),
                    ),
                  if (open) Feed(clubId: id, canNotice: admin),
                  entry(
                    '모임 적립금',
                    subtitle: '외부 보관 계좌의 실제 입출금 기록',
                    onTap: () => context.push('/clubs/$id/reserve'),
                  ),
                  entry(
                    '모임 레벨',
                    onTap: () => showModalBottomSheet(
                      context: context,
                      builder: (_) => Padding(
                        padding: const EdgeInsets.all(20),
                        child: Remote(
                          path: '/clubs/$id/levels/${api.session!.userId}',
                          builder: (v, r) => Column(
                            children: [
                              heading('모임 레벨 ${obj(v)['score']}'),
                              Text('${obj(v)['historyLabel']}'),
                              const Note(
                                '금융 신용등급이 아닙니다. 실제 시각 미확인·이의는 판정을 보류합니다.',
                              ),
                              for (final h in rows(obj(v)['history']))
                                entry(
                                  '${h['outcome']} · ${h['delta']}',
                                  subtitle: '${h['reason']}',
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (open)
                    FilledButton(
                      onPressed: () => context.push('/create?clubId=$id'),
                      child: const Text('정모·번개 만들기'),
                    ),
                  if (open) ...[
                    heading('정모·번개'),
                    Remote(
                      path: '/clubs/$id/events',
                      builder: (v, r) => Column(
                        children: [
                          if (rows(v).isEmpty) empty('등록된 일정이 없어요.'),
                          for (final event in rows(v))
                            entry(
                              label(event),
                              subtitle: formatTimestamp(event['startsAt']),
                              onTap: () =>
                                  context.push('/events/${event['id']}'),
                            ),
                        ],
                      ),
                    ),
                    heading('부원'),
                    Remote(
                      path: '/clubs/$id/members',
                      builder: (v, r) => Column(
                        children: [
                          for (final member in rows(v))
                            entry(
                              label(member),
                              onTap: () => showActivityLevel(
                                context,
                                clubId: id,
                                userId: member['userId'],
                                title: label(member),
                              ),
                              subtitle: stateLabel(member['role']),
                              trailing:
                                  admin &&
                                      member['userId'] != api.session?.userId &&
                                      member['role'] != 'OWNER' &&
                                      (owner || member['role'] != 'ADMIN')
                                  ? PopupMenuButton<String>(
                                      onSelected: (choice) => form(
                                        '부원 관리',
                                        '/clubs/$id/members/${member['userId']}/$choice',
                                        choice == 'role'
                                            ? const [
                                                FormFieldSpec(
                                                  'role',
                                                  '역할',
                                                  kind: FieldKind.choice,
                                                  choices: ['MEMBER', 'ADMIN'],
                                                ),
                                              ]
                                            : [],
                                        base: {
                                          'version': club['version'],
                                          if (choice == 'blacklist')
                                            'enabled': true,
                                        },
                                      ),
                                      itemBuilder: (_) => [
                                        if (owner)
                                          const PopupMenuItem(
                                            value: 'role',
                                            child: Text('역할 변경'),
                                          ),
                                        PopupMenuItem(
                                          value: 'expel',
                                          child: Text('강퇴'),
                                        ),
                                        PopupMenuItem(
                                          value: 'blacklist',
                                          child: Text('가입 차단'),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (admin) ...[
                    ClubInvitation(
                      api: api,
                      clubId: id,
                      version: integerValue(club['version'], 'club.version'),
                      reload: reload,
                    ),
                    heading('가입 신청 검토'),
                    Remote(
                      path: '/clubs/$id/join-requests',
                      builder: (v, r) => Column(
                        children: [
                          if (rows(v).isEmpty) empty('대기 중인 가입 신청이 없어요.'),
                          for (final m in rows(v))
                            entry(
                              label(m),
                              subtitle: m['memo'] is String
                                  ? m['memo']
                                  : m['requestMemo'],
                              trailing: Wrap(
                                children: [
                                  TextButton(
                                    onPressed: () => form(
                                      '가입 승인',
                                      '/clubs/$id/members/${m['userId']}/approve',
                                      [],
                                    ),
                                    child: const Text('승인'),
                                  ),
                                  TextButton(
                                    onPressed: () => form(
                                      '가입 신청 거절',
                                      '/clubs/$id/members/${m['userId']}/reject',
                                      const [FormFieldSpec('reason', '거절 사유')],
                                    ),
                                    child: const Text('거절'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (owner && open)
                    OutlinedButton(
                      onPressed: () => form(
                        '모임장 승계 제안',
                        '/clubs/$id/owner-transfers',
                        const [FormFieldSpec('candidateId', '새 모임장')],
                      ),
                      child: const Text('모임장 승계'),
                    ),
                  if (open)
                    OutlinedButton(
                      onPressed: () => form('모임 탈퇴', '/clubs/$id/leave', []),
                      child: const Text('모임 탈퇴'),
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
