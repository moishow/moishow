import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/participation_corrections.dart';
import 'api_test.dart' show MemoryStore;

class CorrectionApi extends Api {
  CorrectionApi() : super(store: MemoryStore(), intents: MemoryStore());
  @override
  Future<dynamic> get(String p) async => [
    {
      'id': 'p',
      'roundId': 'r',
      'userId': 'u',
      'nickname': '산책자',
      'status': 'CONFIRMED',
      'agreedFee': 1000,
    },
  ];
}

void main() {
  testWidgets(
    'registered attendance changes append financial correction with named participant and explicit redistribution',
    (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(CorrectionApi())],
          child: MaterialApp(
            home: Scaffold(
              body: ParticipationCorrections(
                eventId: 'e',
                version: 5,
                reload: () {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('등록 후 참석·취소·노쇼 사실 정정'));
      await t.pumpAndSettle();
      await t.tap(find.text('산책자 · 참여 확정'));
      await t.pumpAndSettle();
      expect(find.textContaining('해당 차수의 기존 개인 조정은 제거'), findsOneWidget);
      expect(find.text('실제 참석 상태'), findsOneWidget);
    },
  );
}
