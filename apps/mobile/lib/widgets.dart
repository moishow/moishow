import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'main.dart';
import 'theme.dart';
import 'models.dart';
import 'resource_picker.dart';
import 'attachments.dart';
import 'dart:convert';
import 'date_controls.dart';

class PageFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  const PageFrame({
    super.key,
    required this.title,
    required this.children,
    this.actions,
  });
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverAppBar(floating: true, title: Text(title), actions: actions),
      SliverPadding(
        padding: const EdgeInsets.all(Tokens.screen),
        sliver: SliverList.list(children: children),
      ),
    ],
  );
}

class Note extends StatelessWidget {
  final String text;
  const Note(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Tokens.blueSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text),
  );
}

class Remote extends ConsumerStatefulWidget {
  final String path;
  final bool allPages;
  final Widget Function(dynamic, VoidCallback) builder;
  final Widget? absent;
  const Remote({
    super.key,
    required this.path,
    required this.builder,
    this.absent,
    this.allPages = false,
  });
  @override
  ConsumerState<Remote> createState() => _RemoteState();
}

class _RemoteState extends ConsumerState<Remote> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(Remote old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) reload();
  }

  void reload() {
    future = widget.allPages
        ? ref.read(apiProvider).listAll(widget.path)
        : ref.read(apiProvider).get(widget.path);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        if (widget.absent != null &&
            snapshot.error is ApiFailure &&
            (snapshot.error as ApiFailure).status == 404) {
          return widget.absent!;
        }
        return Column(
          children: [
            Note(snapshot.error.toString()),
            OutlinedButton.icon(
              onPressed: reload,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 불러오기'),
            ),
          ],
        );
      }
      try {
        return widget.builder(snapshot.data, reload);
      } on FormatException catch (e) {
        return Note(e.message);
      }
    },
  );
}

List<Json> rows(dynamic value) => objectList(value);
Json obj(dynamic value) => objectValue(value);
String label(Json row) =>
    '${row['title'] ?? row['name'] ?? row['nickname'] ?? row['body'] ?? row['purpose'] ?? row['reason'] ?? '기록'}';
String formatTimestamp(dynamic value) {
  if (value == null) return '시각 미확인';
  final date = (value is DateTime ? value : DateTime.parse(value as String))
      .toLocal();
  return '${date.year}년 ${date.month}월 ${date.day}일 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String won(dynamic value) {
  final amount = integerValue(value, 'amount', signed: true);
  return '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';
}

Widget empty(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 24),
  child: Center(
    child: Text(text, style: const TextStyle(color: Tokens.muted)),
  ),
);
Widget heading(String text) => Padding(
  padding: const EdgeInsets.only(top: 20, bottom: 12),
  child: Text(
    text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  ),
);
Widget entry(
  String title, {
  String? subtitle,
  VoidCallback? onTap,
  Widget? trailing,
}) => Card(
  child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    onTap: onTap,
    trailing:
        trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
  ),
);

enum FieldKind { text, amount, signedAmount, integer, time, choice, boolean }

const choiceLabels = {
  'NONE': '가입 전',
  'EXPELLED': '강퇴됨',
  'HOST': '주최자',
  'OWNER': '모임장',
  'CREATED': '접수',
  'CLAIM': '담당 배정',
  'CLAIMED': '담당 배정',
  'ESCALATE': '상향 요청',
  'OPERATOR': '운영자',
  'SUBMITTED': '신청 접수',
  'APPROVED': '승인',
  'PREPAY': '사전 걷기',
  'POSTPAY': '사후 정산',
  'REFUND': '추가 환불',
  'RESERVE': '모임 적립',
  'IMMEDIATE': '즉시 가입',
  'APPROVAL': '승인제',
  'LIGHTNING': '번개',
  'REGULAR': '정모',
  'MEMBER': '부원',
  'ADMIN': '관리자',
  'USER': '사용자',
  'PERSONAL_CONTENT': '개인 글',
  'CLUB_CONTENT': '모임 글·댓글',
  'false': '아니요',
  'true': '예',
  'CONFIRMED': '참여 확정',
  'WAITLISTED': '참여 대기',
  'LATE_REQUESTED': '마감 후 합류 요청',
  'CANCELLED': '취소',
  'NO_SHOW': '노쇼',
  'PENDING': '확인 대기',
  'OPEN': '진행 중',
  'CLOSED': '계산 마감',
  'REGISTERED': '최초 정산 등록',
  'UNPAID': '미납',
  'PARTIAL': '부분 납부',
  'PAID': '완납',
  'SUPERSEDED': '최종 정산으로 대체',
  'VERIFIED': '실입금 확인',
  'REQUESTED': '요청됨',
  'SENT': '실제 송금 기록',
  'RECEIVED': '수령 확인',
  'ACCEPTED': '동의·인정',
  'REJECTED': '거절·반려',
  'WITHDRAWN': '철회',
  'REVIEWING': '검토 중',
  'ACTIVE': '활동 중',
  'INVITED': '초대 대기',
  'GROUP_DM': '그룹 대화',
  'DIRECT': '개인 대화',
  'CLUB': '모임방',
  'EVENT': '이벤트방',
  'PROPOSED': '제안',
  'FUNDS_PENDING': '수령 확인 대기',
  'COMPLETED': '완료',
  'PROGRESS': '진행 안내',
  'RESOLVED': '처리 결과 등록',
  'DECLINED': '거절',
  'LEFT': '나감',
  'PARTICIPANT': '참가자',
  'TRANSFER_PENDING': '실제 입금 확인 대기',
  'RECEIVED_STALE': '수령 기록됨 · 변경 명세 확인 필요',
  'ON_TIME': '기한 내 처리',
  'LATE': '지연 확인',
  'RECOVERED': '지연 후 완료·회복',
  'HOLD': '판정 보류',
  'ERROR_CORRECTED': '오류 정정',
  'RESOLVE': '처리 완료',
  'WARN': '경고',
  'RESTRICT': '필요한 이용 제한',
  'CORRECTION_REQUEST': '정정 요청',
  'HANDOVER_REQUEST': '인계 요청',
  'CONTENT_REMOVE': '신고 콘텐츠 조치',
};
String financialStateLabel(dynamic value) => switch (value) {
  'CONFIRMED' => '수령 확인 완료',
  'SENT' => '송금 기록 · 수령 확인 대기',
  _ => stateLabel(value),
};
String handoverStateLabel(dynamic value) =>
    value == 'ACCEPTED' ? '명세 인수 수락' : financialStateLabel(value);
String stateLabel(dynamic value) => choiceLabels[value] ?? '상태 확인 필요';

class FormFieldSpec {
  final String key, label, initial;
  final FieldKind kind;
  final List<String> choices;
  final bool optional;
  const FormFieldSpec(
    this.key,
    this.label, {
    this.initial = '',
    this.kind = FieldKind.text,
    this.choices = const [],
    this.optional = false,
  });
}

/// Domain forms keep a frozen command on network retry. No local success state
/// replaces the server response; after every successful write the owner reloads.
Future<void> actionForm(
  BuildContext context,
  Api api, {
  required String title,
  required String path,
  required List<FormFieldSpec> fields,
  Json base = const {},
  required VoidCallback reload,
  String? notice,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => CommandForm(
      api: api,
      title: title,
      path: path,
      fields: fields,
      base: base,
      onDone: reload,
      notice: notice,
    ),
  );
}

class CommandForm extends StatefulWidget {
  final Api api;
  final String title, path;
  final List<FormFieldSpec> fields;
  final Json base;
  final VoidCallback onDone;
  final String? notice;
  const CommandForm({
    super.key,
    required this.api,
    required this.title,
    required this.path,
    required this.fields,
    required this.base,
    required this.onDone,
    this.notice,
  });
  @override
  State<CommandForm> createState() => _CommandFormState();
}

class _CommandFormState extends State<CommandForm> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  bool busy = false, conflict = false, uncertain = false;
  String? error;
  Command? pending;
  String? signature;
  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      controllers[f.key] = TextEditingController(text: f.initial);
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  dynamic convert(FormFieldSpec field, String value) {
    if (value.isEmpty && field.optional) return null;
    if (field.key == 'userIds') return List<String>.from(jsonDecode(value));
    if (field.kind == FieldKind.time &&
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      throw const FormatException('시간대가 필요합니다.');
    }
    return switch (field.kind) {
      FieldKind.amount => parseKrw(value),
      FieldKind.signedAmount => parseKrw(value, signed: true),
      FieldKind.integer => int.parse(value),
      FieldKind.time => DateTime.parse(value).toUtc().toIso8601String(),
      FieldKind.boolean => value == 'true',
      _ => value,
    };
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final body = Map<String, dynamic>.from(widget.base);
    for (final f in widget.fields) {
      final value = convert(f, controllers[f.key]!.text.trim());
      if (value != null) body[f.key] = value;
    }
    final current = body.toString();
    if (pending == null || signature != current) {
      pending = Command(widget.path, body);
      signature = current;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.send(pending!);
      widget.onDone();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          conflict = e is ApiFailure && e.status == 409;
          uncertain = e is ApiFailure && (e.status == null || e.status! >= 500);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            if (widget.notice != null) Note(widget.notice!),
            for (final f in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: f.key == 'userIds'
                    ? PeoplePicker(
                        api: widget.api,
                        controller: controllers[f.key]!,
                        enabled: !busy && !uncertain && !conflict,
                      )
                    : f.key == 'evidence'
                    ? EvidencePicker(
                        api: widget.api,
                        path: widget.path,
                        controller: controllers[f.key]!,
                        scope: widget.path.contains('/reports')
                            ? 'PAYMENT'
                            : widget.path.contains('/disputes')
                            ? 'DISPUTE'
                            : 'EXPENSE',
                        enabled: !busy && !uncertain && !conflict,
                      )
                    : f.key.endsWith('Id')
                    ? ResourcePicker(
                        api: widget.api,
                        path: widget.path,
                        field: f.key,
                        label: f.label,
                        controller: controllers[f.key]!,
                        enabled: !busy && !uncertain && !conflict,
                      )
                    : f.kind == FieldKind.choice || f.kind == FieldKind.boolean
                    ? DropdownButtonFormField<String>(
                        initialValue: controllers[f.key]!.text.isEmpty
                            ? null
                            : controllers[f.key]!.text,
                        validator: (v) =>
                            v == null && !f.optional ? '직접 선택해주세요.' : null,
                        decoration: InputDecoration(labelText: f.label),
                        items: f.choices
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Text(choiceLabels[v] ?? v),
                              ),
                            )
                            .toList(),
                        onChanged: busy || uncertain || conflict
                            ? null
                            : (v) => controllers[f.key]!.text = v!,
                      )
                    : TextFormField(
                        controller: controllers[f.key],
                        enabled: !busy && !conflict && !uncertain,
                        readOnly: f.kind == FieldKind.time,
                        onTap: f.kind == FieldKind.time
                            ? () => chooseTime(context, controllers[f.key]!)
                            : null,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLines:
                            [
                              'body',
                              'reason',
                              'inventoryNote',
                              'purpose',
                              'publicResult',
                            ].contains(f.key)
                            ? 4
                            : 1,
                        decoration: InputDecoration(
                          labelText: f.label,
                          hintText: f.kind == FieldKind.time
                              ? '날짜·시간 선택'
                              : null,
                        ),
                        keyboardType:
                            [
                              FieldKind.amount,
                              FieldKind.integer,
                              FieldKind.signedAmount,
                            ].contains(f.kind)
                            ? const TextInputType.numberWithOptions(
                                signed: true,
                              )
                            : TextInputType.text,
                        validator: (v) {
                          try {
                            if ((v ?? '').trim().isEmpty && !f.optional) {
                              return '필수 입력입니다.';
                            }
                            convert(f, (v ?? '').trim());
                            return null;
                          } catch (_) {
                            return f.kind == FieldKind.time
                                ? '시간대가 포함된 날짜를 입력해주세요.'
                                : '유효한 값과 원 단위 범위를 확인해주세요.';
                          }
                        },
                      ),
              ),
            if (error != null) Note(error!),
            if (conflict)
              OutlinedButton(
                onPressed: () {
                  widget.onDone();
                  Navigator.pop(context);
                },
                child: const Text('최신 자료 다시 불러오기'),
              ),
            FilledButton(
              onPressed: busy || conflict ? null : submit,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(),
                    )
                  : Text(error == null ? '확인하고 요청' : '같은 요청 다시 시도'),
            ),
          ],
        ),
      ),
    ),
  );
}
