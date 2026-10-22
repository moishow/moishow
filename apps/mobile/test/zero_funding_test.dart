import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/finance_editor.dart';
import 'api_test.dart' show MemoryStore;

class ZeroApi extends Api {
  Command? command;
  ZeroApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String p) async => [];
  @override
  Future<dynamic> send(Command c) async {
    command = c;
    return {'version': 4};
  }
}

void main() {
  for (final operation in ['RECEIPT_CORRECTION', 'EXPENSE']) {
    testWidgets(
      'explicit zero $operation submits an empty allocation rather than a fake zero portion',
      (t) async {
        t.view.physicalSize = const Size(800, 1800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final api = ZeroApi();
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FinanceEditor(
                api: api,
                eventId: 'e',
                operation: operation,
                finance: const {'version': 3, 'names': {}},
                event: const {
                  'clubId': 'c',
                  'rounds': [
                    {'id': 'r'},
                  ],
                },
                report: operation == 'EXPENSE'
                    ? null
                    : const {
                        'id': 'report',
                        'amount': 100,
                        'reportedAmount': 100,
                        'allowedAllocationKindsByRound': {
                          'r': ['ATTENDANCE'],
                        },
                      },
                reload: () {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.enterText(
          find.widgetWithText(
            TextFormField,
            operation == 'EXPENSE' ? '총 지출액·증감액' : '실제 확인 입금액',
          ),
          '0',
        );
        if (operation == 'EXPENSE') {
          await t.enterText(
            find.widgetWithText(TextFormField, '지출 항목명'),
            '0원 실제 지출',
          );
          await t.tap(find.byType(DropdownButtonFormField<String>).first);
          await t.pumpAndSettle();
          await t.tap(find.text('1차').last);
          await t.pumpAndSettle();
        } else {
          await t.enterText(
            find.widgetWithText(TextFormField, '정정 사유'),
            '존재하지 않은 입금 기록의 전액 정정',
          );
        }
        await t.tap(find.text('0원 · 배분 없음으로 기록'));
        await t.pumpAndSettle();
        final total = find.widgetWithText(
          TextFormField,
          operation == 'EXPENSE' ? '총 지출액·증감액' : '실제 확인 입금액',
        );
        await t.enterText(total, '1');
        await t.ensureVisible(find.text('확인하고 기록'));
        await t.tap(find.text('확인하고 기록'));
        await t.pumpAndSettle();
        expect(api.command, isNull);
        expect(find.textContaining('배분 금액의 합계'), findsOneWidget);
        await t.enterText(total, '0');
        await t.ensureVisible(find.text('확인하고 기록'));
        await t.tap(find.text('확인하고 기록'));
        await t.pumpAndSettle();
        expect(api.command?.body['amount'], 0);
        expect(
          api.command?.body[operation == 'EXPENSE'
              ? 'fundings'
              : 'allocations'],
          isEmpty,
        );
      },
    );
  }
}
