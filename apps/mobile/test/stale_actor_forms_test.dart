import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:moishow/api.dart';
import 'package:moishow/attachments.dart';
import 'package:moishow/main.dart';
import 'package:moishow/profile_screen.dart';
import 'package:moishow/push.dart';
import 'api_test.dart' show MemoryStore;

// All bytes and sessions are fixtures. No filesystem or network I/O.
class DeferredFixturePhoto extends XFile {
  final readStarted = Completer<void>();
  final bytes = Completer<Uint8List>();
  DeferredFixturePhoto() : super('/fixture-only/a-private.png');
  @override
  String get name => 'a-private.png';
  @override
  Future<Uint8List> readAsBytes() {
    readStarted.complete();
    return bytes.future;
  }
}

class FixturePicker extends ImagePickerPlatform {
  final DeferredFixturePhoto photo;
  final Completer<XFile?>? selection;
  FixturePicker(this.photo, {this.selection});
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => selection == null ? photo : selection!.future;
}

class FixtureWire implements HttpClientAdapter {
  final writes = <RequestOptions>[];
  bool succeed = false;
  Completer<void>? responseGate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    writes.add(options);
    await responseGate?.future;
    // Preserve actual Api journal for ownership inspection.
    return ResponseBody.fromString(
      succeed
          ? '{"reference":"file:fixture-private"}'
          : '{"code":"FIXTURE_UNAVAILABLE"}',
      succeed ? 200 : 503,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FixtureApi extends Api {
  FixtureApi(FixtureWire wire, MemoryStore intents)
    : super(
        dio: Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
          ..httpClientAdapter = wire,
        store: MemoryStore(),
        intents: intents,
      );
  @override
  Future<dynamic> get(String path) async {
    if (path == '/me/profile') {
      return {
        'version': 0,
        'nickname': 'fixture-A',
        'interests': [],
        'bio': '',
      };
    }
    if (path == '/me') return {'nickname': 'fixture'};
    return [];
  }
}

Future<void> login(Api api, String actor) => api.saveSession({
  'token': 'fixture-token-$actor',
  'scope': 'ACTIVE',
  'userId': actor,
  'expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
});

void main() {
  Future<void> mountPicker(
    WidgetTester t,
    Api api,
    TextEditingController controller,
    ValueChanged<String> uploaded,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvidencePicker(
            api: api,
            path: '/events/fixture-event/expenses',
            scope: 'DISPUTE',
            controller: controller,
            onUploaded: uploaded,
          ),
        ),
      ),
    );
    await t.tap(find.text('사진 선택'));
    await t.pump();
  }

  testWidgets(
    'picker returning after disposal does not read, upload or callback',
    (t) async {
      final old = ImagePickerPlatform.instance, photo = DeferredFixturePhoto();
      final selection = Completer<XFile?>();
      ImagePickerPlatform.instance = FixturePicker(photo, selection: selection);
      addTearDown(() => ImagePickerPlatform.instance = old);
      final wire = FixtureWire(), journal = MemoryStore();
      final api = FixtureApi(wire, journal);
      await login(api, 'A');
      final controller = TextEditingController();
      final callbacks = <String>[];
      await mountPicker(t, api, controller, callbacks.add);
      await t.pumpWidget(const SizedBox());
      controller.dispose();
      selection.complete(photo);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(photo.readStarted.isCompleted, isFalse);
      expect(wire.writes, isEmpty);
      expect(journal.value, isNull);
      expect(callbacks, isEmpty);
    },
  );

  testWidgets(
    'unchanged owner uploads exact scope and calls back once with reference',
    (t) async {
      final old = ImagePickerPlatform.instance, photo = DeferredFixturePhoto();
      photo.bytes.complete(Uint8List.fromList([137, 80, 78, 71]));
      ImagePickerPlatform.instance = FixturePicker(photo);
      addTearDown(() => ImagePickerPlatform.instance = old);
      final wire = FixtureWire()..succeed = true;
      final journal = MemoryStore();
      final api = FixtureApi(wire, journal);
      await login(api, 'A');
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final callbacks = <String>[];
      await mountPicker(t, api, controller, callbacks.add);
      await t.pumpAndSettle();
      expect(wire.writes, hasLength(1));
      expect(
        wire.writes.single.headers['Authorization'],
        'Bearer fixture-token-A',
      );
      final multipart = wire.writes.single.data as FormData;
      expect(Map.fromEntries(multipart.fields)['scope'], 'DISPUTE');
      expect(Map.fromEntries(multipart.fields)['eventId'], 'fixture-event');
      expect(controller.text, 'file:fixture-private');
      expect(callbacks, ['file:fixture-private']);
      expect(jsonDecode(journal.value!), isEmpty);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'late successful upload after disposal does not mutate controller or callback',
    (t) async {
      final old = ImagePickerPlatform.instance, photo = DeferredFixturePhoto();
      photo.bytes.complete(Uint8List.fromList([137, 80, 78, 71]));
      ImagePickerPlatform.instance = FixturePicker(photo);
      addTearDown(() => ImagePickerPlatform.instance = old);
      final wire = FixtureWire()
        ..succeed = true
        ..responseGate = Completer<void>();
      final api = FixtureApi(wire, MemoryStore());
      await login(api, 'A');
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final callbacks = <String>[];
      await mountPicker(t, api, controller, callbacks.add);
      for (var i = 0; i < 10 && wire.writes.isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 10));
      }
      expect(wire.writes, hasLength(1));
      await t.pumpWidget(const SizedBox());
      wire.responseGate!.complete();
      await t.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(callbacks, isEmpty);
    },
  );

  testWidgets(
    'photo read started by A must not journal or POST after actual router logout and B login',
    (t) async {
      final oldPicker = ImagePickerPlatform.instance;
      final photo = DeferredFixturePhoto();
      ImagePickerPlatform.instance = FixturePicker(photo);
      addTearDown(() => ImagePickerPlatform.instance = oldPicker);
      final wire = FixtureWire(), journal = MemoryStore();
      final api = FixtureApi(wire, journal);
      final push = PushRegistrar(
        api,
        () {},
        ownership: MemoryStore(),
        receipts: MemoryStore(),
      );
      await login(api, 'A');
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            apiProvider.overrideWithValue(api),
            pushRegistrarProvider.overrideWithValue(push),
          ],
          child: const MoishowApp(),
        ),
      );
      await t.pumpAndSettle();
      GoRouter.of(t.element(find.byType(AppShell))).go('/profile');
      await t.pumpAndSettle();
      expect(find.byType(ProfileFields), findsOneWidget);
      await t.ensureVisible(find.text('사진 선택'));
      await t.tap(find.text('사진 선택'));
      await t.pump();
      expect(photo.readStarted.isCompleted, isTrue);
      await api.clearSession();
      await t.pumpAndSettle();
      expect(find.byType(ProfileFields), findsNothing);
      expect(find.textContaining('소셜 인증과 SMS'), findsOneWidget);
      await login(api, 'B');
      await t.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      expect(api.session?.userId, 'B');
      photo.bytes.complete(Uint8List.fromList([137, 80, 78, 71]));
      await t.pumpAndSettle();
      final fileWrites = wire.writes.where((r) => r.path == '/files').toList();
      final entries = journal.value == null
          ? []
          : jsonDecode(journal.value!) as List;
      expect(
        fileWrites.map((r) => r.headers['Authorization']).toList(),
        isEmpty,
        reason:
            'A-selected bytes must never upload using B credentials; journal=$entries',
      );
      expect(
        entries,
        isEmpty,
        reason: 'A-selected bytes must never persist in B pending commands',
      );
      await t.pumpWidget(const SizedBox());
    },
  );
}
