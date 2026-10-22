import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/finance_editor.dart';
import 'package:moishow/api.dart';
import 'api_test.dart' show MemoryStore;

class EditorApi extends Api {
  EditorApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String path) async => [];
}

void main() {
  testWidgets(
    'host contribution options come only from private per-report allowed kinds and correction preserves actual amount',
    (t) async {
      t.view.physicalSize = const Size(800, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinanceEditor(
              api: EditorApi(),
              eventId: 'e',
              operation: 'RECEIPT_CORRECTION',
              finance: const {'version': 3, 'names': {}},
              event: const {
                'clubId': 'c',
                'rounds': [
                  {'id': 'r'},
                  {'id': 'unrelated'},
                ],
              },
              report: const {
                'id': 'p',
                'reportedAmount': 100,
                'amount': 150,
                'allowedAllocationKindsByRound': {
                  'r': ['HOST_CONTRIBUTION'],
                },
              },
              reload: () {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '150'), findsOneWidget);
      await t.tap(find.byType(DropdownButtonFormField<String>).first);
      await t.pumpAndSettle();
      expect(find.text('2차'), findsNothing);
      await t.tap(find.text('1차').last);
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<String>).last);
      await t.pumpAndSettle();
      expect(find.text('원주최자 부담금'), findsOneWidget);
      expect(find.text('참석 회비'), findsNothing);
    },
  );
}
