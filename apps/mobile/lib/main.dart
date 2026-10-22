import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'auth.dart';
import 'theme.dart';
import 'screens.dart';
import 'account_screens.dart';
import 'event_composer.dart';
import 'advance_screen.dart';
import 'push.dart';
import 'profile_screen.dart';
import 'post_screens.dart';
import 'community_widgets.dart';
import 'widgets.dart' show PageFrame;
import 'dart:async';
import 'package:flutter/foundation.dart';

final apiProvider = Provider<Api>((ref) => Api());
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = Api();
  await api.restore();
  runApp(
    ProviderScope(
      overrides: [apiProvider.overrideWithValue(api)],
      child: const MoishowApp(),
    ),
  );
}

class MoishowApp extends ConsumerStatefulWidget {
  const MoishowApp({super.key});
  @override
  ConsumerState<MoishowApp> createState() => _MoishowAppState();
}

class _MoishowAppState extends ConsumerState<MoishowApp> {
  late final GoRouter router;
  late final NativeAuth auth;
  late final Api api;
  late final PushRegistrar push;
  Timer? expiry;
  final messenger = GlobalKey<ScaffoldMessengerState>();
  late final VoidCallback sessionListener;
  final refresh = ValueNotifier(0);
  @override
  void initState() {
    super.initState();
    api = ref.read(apiProvider);
    auth = NativeAuth(api);
    router = GoRouter(
      refreshListenable: refresh,
      redirect: (context, state) {
        final session = api.session;
        final path = state.uri.path;
        if (session == null || !session.expiresAt.isAfter(DateTime.now())) {
          return path == '/login' ? null : '/login';
        }
        if (!session.active) {
          return path == '/onboard' ? null : '/onboard';
        }
        if (path == '/onboard' && api.needsProfileSetup) {
          return '/onboard/preferences';
        }
        if (path == '/login' || path == '/onboard') {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, s) => LoginScreen(auth: auth),
        ),
        GoRoute(path: '/onboard', builder: (_, s) => const OnboardScreen()),
        GoRoute(
          path: '/onboard/preferences',
          builder: (_, s) => const UserProfileScreen(setup: true),
        ),
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(path: state.uri.path, child: child),
          routes: [
            GoRoute(path: '/', builder: (_, s) => const HomeScreen()),
            GoRoute(
              path: '/create',
              builder: (_, s) =>
                  EventComposer(clubId: s.uri.queryParameters['clubId']),
            ),
            GoRoute(path: '/explore', builder: (_, s) => const ExploreScreen()),
            GoRoute(
              path: '/feed',
              builder: (context, s) => PageFrame(
                title: '피드',
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push('/explore'),
                    icon: const Icon(Icons.search),
                    label: const Text('모임 찾기'),
                  ),
                  const Feed(),
                ],
              ),
            ),
            GoRoute(path: '/clubs', builder: (_, s) => const ClubsScreen()),
            GoRoute(
              path: '/clubs/:id',
              builder: (_, s) => ClubScreen(id: s.pathParameters['id']!),
            ),
            GoRoute(
              path: '/events/:id',
              builder: (_, s) => EventScreen(id: s.pathParameters['id']!),
            ),
            GoRoute(
              path: '/events/:id/finance',
              builder: (_, s) => FinanceScreen(id: s.pathParameters['id']!),
            ),
            GoRoute(
              path: '/events/:id/advances',
              builder: (_, s) => AdvanceScreen(id: s.pathParameters['id']!),
            ),
            GoRoute(
              path: '/clubs/:id/reserve',
              builder: (_, s) => ReserveScreen(id: s.pathParameters['id']!),
            ),
            GoRoute(path: '/chat', builder: (_, s) => const ChatScreen()),
            GoRoute(
              path: '/chat/:id',
              builder: (_, s) => ChatRoomScreen(id: s.pathParameters['id']!),
            ),
            GoRoute(
              path: '/posts/:id',
              builder: (_, s) => Scaffold(
                appBar: AppBar(title: const Text('게시글')),
                body: PostDetail(id: s.pathParameters['id']!),
              ),
            ),
            GoRoute(path: '/my', builder: (_, s) => const MyScreen()),
            GoRoute(
              path: '/profile',
              builder: (_, s) => const UserProfileScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, s) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/notifications',
              builder: (_, s) => const NotificationsScreen(),
            ),
            GoRoute(path: '/cases', builder: (_, s) => const CasesScreen()),
            GoRoute(
              path: '/ops',
              builder: (_, s) => const CasesScreen(operatorQueue: true),
            ),
          ],
        ),
      ],
    );
    push =
        ref.read(pushRegistrarProvider) ??
        PushRegistrar(
          api,
          () => router.go('/notifications'),
          foreground: () => messenger.currentState?.showSnackBar(
            SnackBar(
              content: const Text('새 알림이 있습니다.'),
              action: SnackBarAction(
                label: '확인',
                onPressed: () => router.go('/notifications'),
              ),
            ),
          ),
        );
    sessionListener = sessionChanged;
    api.onSessionChanged = sessionListener;
    sessionChanged();
  }

  void sessionChanged() {
    expiry?.cancel();
    final session = api.session;
    if (session != null) {
      final delay = session.expiresAt.difference(DateTime.now());
      if (delay.isNegative) {
        unawaited(api.clearSession());
        return;
      }
      expiry = Timer(delay, () => unawaited(api.clearSession()));
      if (session.active &&
          (push.transport is! NativePushTransport ||
              !kIsWeb && nativeFirebaseOptions() != null)) {
        unawaited(push.connect().catchError((_) {}));
      }
    } else {
      unawaited(push.sessionChanged().catchError((_) {}));
    }
    refresh.value++;
  }

  @override
  void dispose() {
    if (identical(api.onSessionChanged, sessionListener)) {
      api.onSessionChanged = null;
    }
    expiry?.cancel();
    unawaited(push.dispose());
    router.dispose();
    refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [pushRegistrarProvider.overrideWithValue(push)],
    child: MaterialApp.router(
      title: '모이쇼',
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: Tokens.theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messenger,
    ),
  );
}

class AppShell extends StatelessWidget {
  final String path;
  final Widget child;
  const AppShell({super.key, required this.path, required this.child});
  @override
  Widget build(BuildContext context) {
    final index = path.startsWith('/feed') || path.startsWith('/explore')
        ? 1
        : path.startsWith('/clubs')
        ? 1
        : path.startsWith('/create')
        ? 2
        : path.startsWith('/chat')
        ? 3
        : path.startsWith('/my') || path == '/settings'
        ? 4
        : 0;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) {
              if (i == 2) {
                context.push('/create');
              } else {
                context.go(['/', '/feed', '/create', '/chat', '/my'][i]);
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: '홈',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                label: '피드',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.add_circle,
                  size: 48,
                  color: Tokens.blue,
                  semanticLabel: '정모·번개 만들기',
                ),
                label: '',
                tooltip: '정모·번개 만들기',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                label: '채팅',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: '마이',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
