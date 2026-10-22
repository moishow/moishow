import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/account_screens.dart';

void main() {
  test(
    'social groups route to actual private resources without inventing a financial event',
    () {
      expect(
        notificationDestination({'groupKey': 'social:comments:p'}),
        '/posts/p',
      );
      expect(
        notificationDestination({'groupKey': 'social:likes:p'}),
        '/posts/p',
      );
      expect(notificationDestination({'groupKey': 'chat:request:r'}), '/chat');
      expect(
        notificationDestination({'groupKey': 'chat:group-invite:r'}),
        '/chat',
      );
      expect(notificationDestination({'eventId': 'e'}), '/events/e/finance');
      expect(notificationDestination({'groupKey': 'unknown'}), isNull);
    },
  );
}
