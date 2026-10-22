import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/screens.dart';

void main() {
  test(
    'home duties use their actual resource including tasks without event IDs',
    () {
      expect(
        homeTaskRoute({'kind': 'RESERVE', 'clubId': 'c'}),
        '/clubs/c/reserve',
      );
      expect(homeTaskRoute({'kind': 'OWNER_TRANSFER'}), '/settings');
      expect(homeTaskRoute({'kind': 'HANDOVER', 'eventId': 'e'}), '/settings');
      expect(
        homeTaskRoute({'kind': 'PAYMENT', 'eventId': 'e'}),
        '/events/e/finance',
      );
      expect(homeTaskRoute({'kind': 'unknown'}), '/notifications');
    },
  );
}
