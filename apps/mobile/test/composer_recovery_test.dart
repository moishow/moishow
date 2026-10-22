import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/main.dart';
import 'package:moishow/event_composer.dart';
import 'mobile_flow_test.dart' show FlowApi;

void main() {
  testWidgets(
    'reopening interrupted creation resumes saved immutable commands without a second event',
    (t) async {
      final api = FlowApi();
      await api.saveSession({
        'token': 'test',
        'scope': 'ACTIVE',
        'userId': 'u',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      FlutterSecureStorage.setMockInitialValues({
        'moishow.event.workflow.u': jsonEncode({
          'event': {'id': 'e', 'version': 0},
          'clubId': 'club',
          'mode': 'POSTPAY',
          'rounds': [
            {
              'capacity': 5,
              'closesAt': '2026-12-01T10:00:00Z',
              'cancellationFee': 0,
            },
          ],
          'doneRounds': [],
          'commands': {
            'create': {
              'path': '/clubs/club/events',
              'key': 'saved-key',
              'body': {
                'title': '보존할 개설',
                'kind': 'LIGHTNING',
                'startsAt': '2026-12-01T11:00:00Z',
                'endsAt': '2026-12-01T12:00:00Z',
                'settlementMode': 'POSTPAY',
              },
            },
          },
        }),
      });
      await t.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: Scaffold(body: EventComposer())),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('같은 개설 요청 이어서 처리'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '보존할 개설'), findsOneWidget);
    },
  );
}
