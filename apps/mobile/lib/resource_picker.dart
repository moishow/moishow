import 'widgets.dart' show formatTimestamp;
import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'dart:convert';

class NamedChoice {
  final String id, label;
  const NamedChoice(this.id, this.label);
}

Future<List<NamedChoice>> allowedChoices(
  Api api,
  String path,
  String field,
) async {
  final event = RegExp(r'/events/([^/]+)').firstMatch(path)?.group(1);
  final club = RegExp(r'/clubs/([^/]+)').firstMatch(path)?.group(1);
  if (field == 'candidateId' && event != null) {
    final candidates = objectList(
      await api.get('/events/$event/handover-candidates'),
    );
    return candidates.map((v) {
      final p = Person(v);
      return NamedChoice(p.id, p.displayName);
    }).toList();
  }
  if (field == 'revisionId' && event != null) {
    final dispute = RegExp(r'/disputes/([^/]+)').firstMatch(path)?.group(1);
    if (dispute == null) throw const ContractError('정확한 이의 정정');
    final detail = objectValue(
      await api.get('/events/$event/finance/disputes/$dispute'),
    );
    return objectList(detail['relatedRevisions'])
        .map(
          (v) => NamedChoice(
            stringValue(v['id'], 'revision.id'),
            '${formatTimestamp(v['createdAt'])} · ${integerValue(v['correctionAmount'], 'revision.amount', signed: true)}원',
          ),
        )
        .toList();
  }
  if (field == 'roundId' && event != null) {
    final rounds = objectList(
      objectValue(await api.get('/events/$event'))['rounds'],
    );
    return [
      for (var i = 0; i < rounds.length; i++)
        NamedChoice(
          stringValue(rounds[i]['id'], 'round.id'),
          '${i + 1}차 · 정원 ${rounds[i]['capacity']}명',
        ),
    ];
  }
  if (field == 'eventId') {
    final entries = club != null
        ? objectList(await api.get('/clubs/$club/events'))
        : objectList(await api.get('/me/history'));
    return entries
        .map(
          (e) => NamedChoice(
            stringValue(e['id'] ?? e['eventId'], 'event.id'),
            stringValue(e['title'], 'event.title'),
          ),
        )
        .toList();
  }
  final choices = <String, NamedChoice>{};
  String? clubId = club;
  if (event != null) {
    final detail = objectValue(await api.get('/events/$event'));
    clubId = detail['clubId'];
    try {
      final finance = objectValue(await api.get('/events/$event/finance'));
      final names = objectValue(finance['names']);
      for (final entry in names.entries) {
        final person = Person({
          'userId': entry.key,
          ...objectValue(entry.value),
        });
        choices[person.id] = NamedChoice(person.id, person.displayName);
      }
    } on ApiFailure catch (e) {
      if (e.status != 404 && e.status != 403) rethrow;
    }
  }
  final values = clubId != null
      ? objectList(await api.get('/clubs/$clubId/members'))
      : await api.listAll('/me/contacts');
  for (final item in values) {
    if (field == 'candidateId' &&
        (item['userId'] == api.session?.userId ||
            (path.contains('/reserve/custodian-handovers') &&
                !['OWNER', 'ADMIN'].contains(item['role'])))) {
      continue;
    }
    final person = Person(item);
    choices[person.id] = NamedChoice(person.id, person.displayName);
  }
  return choices.values.toList();
}

class PeoplePicker extends StatefulWidget {
  final Api api;
  final TextEditingController controller;
  final bool enabled;
  const PeoplePicker({
    super.key,
    required this.api,
    required this.controller,
    this.enabled = true,
  });
  @override
  State<PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<PeoplePicker> {
  late Future<List<Json>> future;
  final selected = <String>{};
  @override
  void initState() {
    super.initState();
    future = widget.api.listAll('/me/contacts');
    if (widget.controller.text.isNotEmpty) {
      selected.addAll(List<String>.from(jsonDecode(widget.controller.text)));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Json>>(
    future: future,
    builder: (context, s) {
      if (s.hasError) return Text(s.error.toString());
      if (!s.hasData) return const Text('초대할 사람을 불러오는 중입니다.');
      return FormField<List<String>>(
        validator: (_) => selected.isEmpty ? '초대할 사람을 선택해주세요.' : null,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('초대할 사람'),
            if (s.data!.isEmpty) const Text('공유 모임·이벤트·팔로우 관계에서 선택할 사람이 없어요.'),
            for (final person in s.data!)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(Person(person).displayName),
                value: selected.contains(person['id'] ?? person['userId']),
                onChanged: widget.enabled
                    ? (enabled) => setState(() {
                        final id = '${person['id'] ?? person['userId']}';
                        if (enabled == true) {
                          selected.add(id);
                        } else {
                          selected.remove(id);
                        }
                        widget.controller.text = jsonEncode(selected.toList());
                        state.didChange(selected.toList());
                      })
                    : null,
              ),
            if (state.errorText != null) Text(state.errorText!),
          ],
        ),
      );
    },
  );
}

class ResourcePicker extends StatefulWidget {
  final Api api;
  final String path, field, label;
  final TextEditingController controller;
  final bool enabled;
  const ResourcePicker({
    super.key,
    required this.api,
    required this.path,
    required this.field,
    required this.label,
    required this.controller,
    this.enabled = true,
  });
  @override
  State<ResourcePicker> createState() => _ResourcePickerState();
}

class _ResourcePickerState extends State<ResourcePicker> {
  late Future<List<NamedChoice>> future;
  @override
  void initState() {
    super.initState();
    future = allowedChoices(widget.api, widget.path, widget.field);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<NamedChoice>>(
    future: future,
    builder: (context, s) {
      if (s.hasError) {
        return Column(
          children: [
            Text(s.error.toString()),
            TextButton(
              onPressed: () => setState(
                () => future = allowedChoices(
                  widget.api,
                  widget.path,
                  widget.field,
                ),
              ),
              child: const Text('선택 목록 다시 불러오기'),
            ),
          ],
        );
      }
      final choices = s.data ?? const <NamedChoice>[];
      return DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: choices.any((v) => v.id == widget.controller.text)
            ? widget.controller.text
            : null,
        decoration: InputDecoration(
          labelText: widget.label.replaceAll(' ID', '').replaceAll('UUID', ''),
          helperText: s.connectionState != ConnectionState.done
              ? '선택 목록을 불러오는 중입니다.'
              : choices.isEmpty
              ? '선택할 수 있는 대상이 없습니다.'
              : null,
        ),
        items: choices
            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.label)))
            .toList(),
        onChanged: widget.enabled
            ? (v) => widget.controller.text = v ?? ''
            : null,
        validator: (_) => widget.controller.text.isEmpty ? '대상을 선택해주세요.' : null,
      );
    },
  );
}
