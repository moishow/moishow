import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/widgets.dart';
import 'package:moishow/theme.dart';
import 'api_test.dart' show MemoryStore, RecordingAdapter;
import 'package:dio/dio.dart';

void main() {
  test('native theme uses exact semantic tokens and numeric headings', () {
    expect(Tokens.theme.colorScheme.secondary, Tokens.muted);
    expect(Tokens.theme.navigationBarTheme.height, 64);
    expect(
      Tokens.theme.textTheme.headlineMedium!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });
  test('command freezes nested funding and allocations', () {
    final nested = <String, dynamic>{
      'allocations': <dynamic>[
        <String, dynamic>{'amount': 20},
      ],
    };
    final command = Command('/reports', nested);
    (nested['allocations'][0] as Map)['amount'] = 999;
    expect(command.body['allocations'][0]['amount'], 20);
    expect(
      () => command.body['allocations'][0]['amount'] = 1,
      throwsUnsupportedError,
    );
  });
  test('missing/invalid money never renders a fabricated zero', () {
    expect(() => won(null), throwsA(isA<FormatException>()));
    expect(() => won('100'), throwsA(isA<FormatException>()));
    expect(won(0), '0원');
  });
  test('malformed list is a schema error, not an empty success', () {
    expect(() => rows({'items': []}), throwsFormatException);
    expect(() => rows([null]), throwsFormatException);
  });
  testWidgets('resource selection never requires typing an opaque user UUID', (
    tester,
  ) async {
    final adapter = RecordingAdapter();
    final api = Api(
      dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter,
      store: MemoryStore(),
      intents: MemoryStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandForm(
            api: api,
            title: '환불 대상',
            path: '/refunds',
            fields: const [FormFieldSpec('userId', '환불 대상 사용자 ID')],
            base: const {},
            onDone: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
  });
}
