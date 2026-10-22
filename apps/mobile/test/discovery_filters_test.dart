import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/main.dart';
import 'package:moishow/screens.dart';
import 'mobile_flow_test.dart' show FlowApi;

class DiscoverApi extends FlowApi {
  final paths = <Uri>[];
  @override
  Future<dynamic> get(String p) async {
    if (p.startsWith('/clubs/discover')) paths.add(Uri.parse(p));
    return [];
  }
}

void main() {
  testWidgets(
    'discovery sends selected region/category and reads paginated matching results',
    (t) async {
      final api = DiscoverApi();
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: Scaffold(body: ExploreScreen())),
        ),
      );
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextField, '지역 (선택)'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, '지역 (선택)'), '서울');
      await t.enterText(find.widgetWithText(TextField, '분류 (선택)'), '운동');
      await t.enterText(find.widgetWithText(TextField, '모임 이름 검색'), '산책');
      await t.tap(find.byIcon(Icons.search));
      await t.pumpAndSettle();
      expect(api.paths.last.queryParameters, containsPair('region', '서울'));
      expect(api.paths.last.queryParameters, containsPair('category', '운동'));
      expect(api.paths.last.queryParameters, containsPair('q', '산책'));
      expect(api.paths.last.queryParameters, containsPair('limit', '200'));
    },
  );
}
