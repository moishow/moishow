import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/handover_review.dart';
import 'package:moishow/transfer_instructions.dart';
import 'api_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'accepted positive cash handover exposes only its exact transfer instructions',
    (t) async {
      final api = Api(store: MemoryStore(), intents: MemoryStore());
      await api.saveSession({
        'token': 'test',
        'scope': 'ACTIVE',
        'userId': 'p',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HandoverReview(
                  handover: const {
                    'id': 'h',
                    'eventId': 'e',
                    'proposerId': 'p',
                    'candidateId': 'c',
                    'version': 1,
                    'status': 'ACCEPTED',
                    'inventoryAmount': 100,
                    'inventory': {},
                    'returns': [],
                  },
                  reload: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(TransferInstructions), findsOneWidget);
      expect(
        t.widget<TransferInstructions>(find.byType(TransferInstructions)).path,
        '/handovers/h/transfer-instructions',
      );
    },
  );
}
