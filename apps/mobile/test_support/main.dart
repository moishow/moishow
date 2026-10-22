import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moishow/api.dart';
import 'package:moishow/main.dart';
import 'package:moishow/theme.dart';
import 'package:moishow/models.dart';

/// Test target only. Sessions come from the real loopback test host, never from
/// a production login bypass, URL parameter, log, or invented client identity.
class ScenarioMemory implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? text) async {
    value = text;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final path = const String.fromEnvironment(
    'SCENARIO_MANIFEST_PATH',
    defaultValue: '/__scenario/manifest',
  );
  final response = await Dio().get(Uri.base.resolve(path).toString());
  final manifest = objectValue(response.data);
  if (manifest['testOnly'] != true ||
      Uri.parse(manifest['apiBaseUrl']).host != '127.0.0.1') {
    throw const FormatException('Loopback test manifest required');
  }
  runApp(ScenarioApp(manifest: manifest));
}

class ScenarioApp extends StatefulWidget {
  final Json manifest;
  const ScenarioApp({super.key, required this.manifest});
  @override
  State<ScenarioApp> createState() => _ScenarioAppState();
}

class _ScenarioAppState extends State<ScenarioApp> {
  late Api api;
  String? role;
  int epoch = 0;
  @override
  void initState() {
    super.initState();
    api = Api(
      dio: Dio(BaseOptions(baseUrl: widget.manifest['apiBaseUrl'])),
      store: ScenarioMemory(),
      intents: ScenarioMemory(),
    );
  }

  Future<void> select(String selected) async {
    await api.saveSession(objectValue(widget.manifest['roles'][selected]));
    setState(() {
      role = selected;
      epoch++;
    });
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [apiProvider.overrideWithValue(api)],
    child: MaterialApp(
      theme: Tokens.theme,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: Tokens.blueSoft,
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Text(
                      'TEST 전용 · 실제 PG/REST\n외부 공급자·실송금 아님',
                      style: TextStyle(fontSize: 11),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: role,
                        hint: const Text('검증할 역할 선택'),
                        items: objectValue(widget.manifest['roles']).keys
                            .map(
                              (key) => DropdownMenuItem(
                                value: key,
                                child: Text(key),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) select(v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: role == null
                    ? const Center(child: Text('실제 서버가 발급한 테스트 역할을 선택해주세요.'))
                    : MoishowApp(key: ValueKey(epoch)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
