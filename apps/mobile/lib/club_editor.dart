import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'widgets.dart';
import 'attachments.dart';

class ClubEditor extends StatefulWidget {
  final Api api;
  final Json? club;
  final ValueChanged<String> onDone;
  const ClubEditor({
    super.key,
    required this.api,
    required this.onDone,
    this.club,
  });
  @override
  State<ClubEditor> createState() => _ClubEditorState();
}

class _ClubEditorState extends State<ClubEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      description = TextEditingController(),
      region = TextEditingController(),
      category = TextEditingController(),
      image = TextEditingController();
  String? mode, error;
  bool busy = false,
      uncertain = false,
      conflict = false,
      changedImage = false,
      clearImage = false;
  Command? pending;
  @override
  void initState() {
    super.initState();
    final d = widget.club;
    if (d != null) {
      name.text = d['name'];
      description.text = d['description'] ?? '';
      region.text = d['region'] ?? '';
      category.text = d['category'] ?? '';
      mode = d['joinMode'];
      if (d['imageFileId'] != null) image.text = 'file:${d['imageFileId']}';
    }
  }

  @override
  void dispose() {
    for (final c in [name, description, region, category, image]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final d = widget.club;
    final body = <String, dynamic>{
      'description': description.text.trim(),
      'region': region.text.trim(),
      'category': category.text.trim(),
      if (d == null) ...{'name': name.text.trim(), 'joinMode': mode},
      if (d != null) 'version': integerValue(d['version'], 'club.version'),
      if (clearImage && d != null) 'clearImage': true,
      if (changedImage && !clearImage) 'imageFileId': image.text.substring(5),
    };
    pending = uncertain
        ? pending
        : Command(d == null ? '/clubs' : '/clubs/${d['id']}/metadata', body);
    setState(() => busy = true);
    try {
      final result = objectValue(await widget.api.send(pending!));
      if (mounted) {
        Navigator.pop(context);
        widget.onDone(stringValue(result['id'], 'club.id'));
      }
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
  Widget build(BuildContext context) {
    final enabled = !busy && !uncertain && !conflict;
    return Padding(
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
              heading(widget.club == null ? '모임 만들기' : '모임 소개 수정'),
              if (widget.club == null) ...[
                TextFormField(
                  controller: name,
                  enabled: enabled,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: '모임 이름'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? '모임 이름을 입력해주세요.' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: '가입 방식'),
                  items: const [
                    DropdownMenuItem(value: 'IMMEDIATE', child: Text('즉시 가입')),
                    DropdownMenuItem(value: 'APPROVAL', child: Text('승인제')),
                  ],
                  onChanged: enabled ? (v) => setState(() => mode = v) : null,
                  validator: (v) => v == null ? '가입 방식을 직접 선택해주세요.' : null,
                ),
              ],
              TextFormField(
                controller: description,
                enabled: enabled,
                maxLength: 1000,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '모임 소개 (선택)'),
              ),
              TextFormField(
                controller: region,
                enabled: enabled,
                maxLength: 100,
                decoration: const InputDecoration(labelText: '지역 (선택)'),
              ),
              TextFormField(
                controller: category,
                enabled: enabled,
                maxLength: 100,
                decoration: const InputDecoration(labelText: '분류 (선택)'),
              ),
              const Note(
                '대표 사진은 모임 소개에 연결됩니다. 선택한 사진만 공개되며 다른 본인 전용 사진은 공개되지 않습니다.',
              ),
              EvidencePicker(
                api: widget.api,
                path: '/clubs',
                scope: 'POST',
                controller: image,
                enabled: enabled,
                onUploaded: (_) => setState(() {
                  changedImage = true;
                  clearImage = false;
                }),
                onRemoved: () => setState(() {
                  changedImage = false;
                  clearImage = true;
                }),
              ),
              if (error != null)
                Semantics(liveRegion: true, child: Note(error!)),
              if (conflict) const Note('최신 모임 소개를 다시 불러온 뒤 수정해주세요.'),
              FilledButton(
                onPressed: busy || conflict ? null : submit,
                child: Text(
                  uncertain
                      ? '같은 모임 요청 재시도'
                      : widget.club == null
                      ? '모임 만들기'
                      : '모임 소개 저장',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
