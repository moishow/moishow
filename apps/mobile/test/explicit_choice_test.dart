import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/widgets.dart';
import 'api_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'commands never silently choose the first role or financial state',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommandForm(
              api: Api(store: MemoryStore(), intents: MemoryStore()),
              title: '사실 정정',
              path: '/correct',
              fields: const [
                FormFieldSpec(
                  'status',
                  '상태',
                  kind: FieldKind.choice,
                  choices: ['CONFIRMED', 'NO_SHOW'],
                ),
              ],
              base: const {},
              onDone: () {},
            ),
          ),
        ),
      );
      expect(
        t
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        isNull,
      );
      await t.tap(find.text('확인하고 요청'));
      await t.pumpAndSettle();
      expect(find.text('직접 선택해주세요.'), findsOneWidget);
    },
  );
}
