import 'date_controls.dart';
export 'date_controls.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'api.dart';
import 'main.dart';
import 'models.dart';
import 'widgets.dart';

class RoundDraft {
  final capacity = TextEditingController(),
      closesAt = TextEditingController(),
      fee = TextEditingController(text: '0'),
      amount = TextEditingController(),
      deadline = TextEditingController();
  void dispose() {
    for (final c in [capacity, closesAt, fee, amount, deadline]) {
      c.dispose();
    }
  }
}

class EventComposer extends ConsumerStatefulWidget {
  final String? clubId;
  const EventComposer({super.key, this.clubId});
  @override
  ConsumerState<EventComposer> createState() => _EventComposerState();
}

class _EventComposerState extends ConsumerState<EventComposer> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      starts = TextEditingController(),
      ends = TextEditingController();
  final rounds = [RoundDraft()];
  String? clubId, kind, mode, error;
  bool public = false, busy = false;
  late Future<List<Json>> clubs;
  Json? recovery;
  final storage = const FlutterSecureStorage();
  @override
  void initState() {
    super.initState();
    clubId = widget.clubId;
    clubs = ref.read(apiProvider).get('/clubs').then(objectList);
    restoreWorkflow();
  }

  Future<void> restoreWorkflow() async {
    try {
      final raw = await storage.read(key: draftKey);
      if (raw == null || !mounted) return;
      final saved = objectValue(jsonDecode(raw));
      final create = objectValue(objectValue(saved['commands'])['create']);
      final body = objectValue(create['body']);
      setState(() {
        recovery = saved;
        clubId = saved['clubId'];
        mode = saved['mode'];
        kind = body['kind'];
        public = body['publicEvent'] == true;
        title.text = body['title'];
        starts.text = body['startsAt'];
        ends.text = body['endsAt'];
        for (final r in rounds) {
          r.dispose();
        }
        rounds.clear();
        for (final r in objectList(saved['rounds'])) {
          rounds.add(
            RoundDraft()
              ..capacity.text = '${r['capacity']}'
              ..closesAt.text = r['closesAt']
              ..fee.text = '${r['cancellationFee']}'
              ..amount.text = '${r['amount'] ?? ''}'
              ..deadline.text = r['deadline'] ?? '',
          );
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = '이전 개설 요청 복구를 확인하지 못했습니다. $e');
    }
  }

  @override
  void dispose() {
    title.dispose();
    starts.dispose();
    ends.dispose();
    for (final r in rounds) {
      r.dispose();
    }
    super.dispose();
  }

  String get draftKey =>
      'moishow.event.workflow.${ref.read(apiProvider).session?.userId}';
  Future<void> save(Json value) =>
      storage.write(key: draftKey, value: jsonEncode(value));
  Future<dynamic> step(
    Api api,
    Json workflow,
    String name,
    String path,
    Json body,
  ) async {
    final saved = objectValue(workflow['commands']);
    final existing = saved[name];
    final command = existing == null
        ? Command(path, body)
        : Command(
            existing['path'],
            objectValue(existing['body']),
            key: existing['key'],
          );
    saved[name] = {
      'path': command.path,
      'body': command.body,
      'key': command.key,
    };
    workflow['commands'] = saved;
    await save(workflow);
    return api.send(command);
  }

  Future<void> submit() async {
    if (recovery == null && !form.currentState!.validate()) return;
    final api = ref.read(apiProvider);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      Json workflow =
          recovery ??
          {'commands': <String, dynamic>{}, 'doneRounds': <dynamic>[]};
      if (workflow['event'] == null) {
        final club = objectValue(await api.get('/clubs/$clubId'));
        final input = {
          'title': title.text.trim(),
          'kind': kind,
          'publicEvent': kind == 'LIGHTNING' && public,
          'startsAt': starts.text,
          'endsAt': ends.text,
          'version': integerValue(club['version'], 'club.version'),
          'settlementMode': mode,
        };
        final start = DateTime.parse(starts.text),
            end = DateTime.parse(ends.text);
        if (!end.isAfter(start)) {
          throw const FormatException('종료는 시작보다 뒤여야 합니다.');
        }
        for (final r in rounds) {
          final capacity = int.tryParse(r.capacity.text);
          final close = DateTime.parse(r.closesAt.text);
          if (capacity == null ||
              capacity < 1 ||
              capacity > 10000 ||
              close.isAfter(end)) {
            throw const FormatException(
              '정원은 1~10,000명이며 신청 마감은 이벤트 종료보다 늦을 수 없습니다.',
            );
          }
          if (mode == 'PREPAY') {
            final deadline = DateTime.parse(r.deadline.text);
            if (!deadline.isAfter(close) ||
                !deadline.isAfter(DateTime.now()) ||
                parseKrw(r.amount.text) <= 0) {
              throw const FormatException(
                '차수 회비는 양수이며 납부 기한은 신청 마감과 현재 시각보다 뒤여야 합니다.',
              );
            }
          }
        }
        workflow['clubId'] = clubId;
        workflow['mode'] = mode;
        workflow['rounds'] = [
          for (final r in rounds)
            {
              'capacity': int.parse(r.capacity.text),
              'closesAt': r.closesAt.text,
              'cancellationFee': parseKrw(r.fee.text),
              if (mode == 'PREPAY') 'amount': parseKrw(r.amount.text),
              if (mode == 'PREPAY') 'deadline': r.deadline.text,
            },
        ];
        workflow['event'] = objectValue(
          await step(api, workflow, 'create', '/clubs/$clubId/events', input),
        );
        await save(workflow);
      }
      final event = objectValue(workflow['event']);
      final id = stringValue(event['id'], 'event.id');
      int version = integerValue(
        workflow['eventVersion'] ?? event['version'],
        'event.version',
      );
      final configured = objectList(workflow['rounds']);
      final done = List<dynamic>.from(workflow['doneRounds']);
      for (int i = done.length; i < configured.length; i++) {
        final r = configured[i];
        final result = objectValue(
          await step(api, workflow, 'round$i', '/events/$id/rounds', {
            'version': version,
            'capacity': r['capacity'],
            'closesAt': r['closesAt'],
            'cancellationFee': r['cancellationFee'],
          }),
        );
        done.add(result);
        version = integerValue(result['eventVersion'], 'event.version');
        workflow['doneRounds'] = done;
        workflow['eventVersion'] = version;
        await save(workflow);
      }
      if (workflow['book'] == null) {
        workflow['book'] = objectValue(
          await step(api, workflow, 'open', '/events/$id/finance/open', {
            'version': 0,
            'mode': workflow['mode'],
          }),
        );
        await save(workflow);
      }
      if (workflow['mode'] == 'PREPAY') {
        int bookVersion = integerValue(
          workflow['bookVersion'] ?? workflow['book']['version'],
          'book.version',
        );
        int billed = (workflow['billed'] as int?) ?? 0;
        for (int i = billed; i < configured.length; i++) {
          final r = configured[i];
          final result = objectValue(
            await step(
              api,
              workflow,
              'billing$i',
              '/rounds/${done[i]['id']}/payment-requests',
              {
                'version': bookVersion,
                'amount': r['amount'],
                'deadline': r['deadline'],
              },
            ),
          );
          bookVersion = integerValue(result['version'], 'book.version');
          workflow['bookVersion'] = bookVersion;
          workflow['billed'] = i + 1;
          await save(workflow);
        }
      }
      await storage.delete(key: draftKey);
      if (mounted) context.go('/events/$id');
    } catch (e) {
      final raw = await storage.read(key: draftKey);
      if (mounted) {
        setState(() {
          error = e.toString();
          if (raw != null) recovery = objectValue(jsonDecode(raw));
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    TextEditingController c,
    String name, {
    bool date = false,
    bool money = false,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      enabled: !busy && recovery == null,
      readOnly: date,
      onTap: date ? () => chooseTime(context, c) : null,
      decoration: InputDecoration(
        labelText: name,
        suffixIcon: date ? const Icon(Icons.calendar_month_outlined) : null,
      ),
      keyboardType: money ? TextInputType.number : TextInputType.text,
      validator: (v) {
        try {
          if ((v ?? '').isEmpty) return optional ? null : '입력해주세요.';
          if (money) parseKrw(v!);
          if (date) DateTime.parse(v!);
          return null;
        } catch (_) {
          return '입력을 확인해주세요.';
        }
      },
    ),
  );
  @override
  Widget build(BuildContext context) => PageFrame(
    title: '정모·번개 만들기',
    children: [
      FutureBuilder<List<Json>>(
        future: clubs,
        builder: (context, s) {
          if (s.hasError) return Note(s.error.toString());
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final selected = s.data!.where((v) => v['id'] == clubId).firstOrNull;
          final admin =
              selected != null && ['OWNER', 'ADMIN'].contains(selected['role']);
          return Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: clubId,
                  decoration: const InputDecoration(labelText: '모임'),
                  items: s.data!
                      .map(
                        (v) => DropdownMenuItem(
                          value: '${v['id']}',
                          child: Text('${v['name']}'),
                        ),
                      )
                      .toList(),
                  validator: (v) => v == null ? '모임을 선택해주세요.' : null,
                  onChanged: busy || recovery != null
                      ? null
                      : (v) => setState(() {
                          clubId = v;
                          kind = null;
                        }),
                ),
                const SizedBox(height: 12),
                field(title, '이벤트 이름'),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: '이벤트 종류'),
                  items: [
                    const DropdownMenuItem(
                      value: 'LIGHTNING',
                      child: Text('번개'),
                    ),
                    if (admin)
                      const DropdownMenuItem(
                        value: 'REGULAR',
                        child: Text('정모'),
                      ),
                  ],
                  onChanged: busy || recovery != null
                      ? null
                      : (v) => setState(() => kind = v),
                  validator: (v) => v == null ? '종류를 선택해주세요.' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: '정산 방식'),
                  items: const [
                    DropdownMenuItem(value: 'PREPAY', child: Text('사전 걷기')),
                    DropdownMenuItem(value: 'POSTPAY', child: Text('사후 정산')),
                  ],
                  onChanged: busy || recovery != null
                      ? null
                      : (v) => setState(() => mode = v),
                  validator: (v) => v == null ? '정산 방식을 직접 선택해주세요.' : null,
                ),
                SwitchListTile(
                  title: const Text('공개 번개'),
                  value: public && kind == 'LIGHTNING',
                  onChanged: kind == 'LIGHTNING' && !busy && recovery == null
                      ? (v) => setState(() => public = v)
                      : null,
                ),
                field(starts, '이벤트 시작', date: true),
                field(ends, '이벤트 종료', date: true),
                for (var i = 0; i < rounds.length; i++)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          heading('${i + 1}차'),
                          field(rounds[i].capacity, '정원', money: true),
                          field(rounds[i].closesAt, '신청 마감', date: true),
                          field(rounds[i].fee, '고지할 취소·노쇼 비용', money: true),
                          if (mode == 'PREPAY') ...[
                            field(rounds[i].amount, '요청할 차수 회비', money: true),
                            field(rounds[i].deadline, '차수 납부 기한', date: true),
                          ],
                        ],
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: busy || recovery != null
                      ? null
                      : () => setState(() => rounds.add(RoundDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('차수 추가'),
                ),
                const Note(
                  '신청 마감과 납부 기한은 별개입니다. 정산 방식과 차수별 취소 비용을 확인하고 개설해주세요.',
                ),
                if (error != null)
                  Semantics(liveRegion: true, child: Note(error!)),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? '서버에 기록 중'
                        : recovery == null
                        ? '이벤트 만들기'
                        : '같은 개설 요청 이어서 처리',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}
