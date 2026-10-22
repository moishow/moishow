import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/main.dart';
import 'mobile_flow_test.dart' show FlowApi;

void main() {
  testWidgets('feed tab shows posts first and opens separate club discovery', (
    t,
  ) async {
    final api = FlowApi();
    await api.saveSession({
      'token': 'test',
      'scope': 'ACTIVE',
      'userId': 'u',
      'expiresAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    });
    await t.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: const MoishowApp(),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('피드'));
    await t.pumpAndSettle();
    expect(find.text('글쓰기'), findsOneWidget);
    expect(find.text('모임 이름 검색'), findsNothing);
    expect(find.text('모임 탐색'), findsNothing);
    await t.tap(find.text('모임 찾기'));
    await t.pumpAndSettle();
    expect(find.text('모임 이름 검색'), findsOneWidget);
    expect(find.text('글쓰기'), findsNothing);
  });
  testWidgets(
    'home follows the canonical task summary weekly calendar and central creation entry',
    (t) async {
      final semantics = t.ensureSemantics();
      final api = FlowApi();
      await api.saveSession({
        'token': 'test',
        'scope': 'ACTIVE',
        'userId': 'u',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: const MoishowApp(),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('지금 처리할 정산 할 일'), findsOneWidget);
      expect(find.text('피드'), findsOneWidget);
      expect(find.byTooltip('정모·번개 만들기'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('정모·번개 만들기')), findsOneWidget);
      expect(find.text('내 모임'), findsOneWidget);
      semantics.dispose();
    },
  );
}
