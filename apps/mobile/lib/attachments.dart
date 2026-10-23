import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'api.dart';
import 'models.dart';

class EvidencePicker extends StatefulWidget {
  final Api api;
  final String path;
  final TextEditingController controller;
  final String scope;
  final String? clubId, eventId;
  final bool enabled;
  final ValueChanged<String>? onUploaded;
  final VoidCallback? onRemoved;
  const EvidencePicker({
    super.key,
    required this.api,
    required this.path,
    required this.controller,
    this.scope = 'EXPENSE',
    this.clubId,
    this.eventId,
    this.enabled = true,
    this.onUploaded,
    this.onRemoved,
  });
  @override
  State<EvidencePicker> createState() => _EvidencePickerState();
}

class _EvidencePickerState extends State<EvidencePicker> {
  bool busy = false;
  String? error;
  Future<void> pick() async {
    final api = widget.api;
    final owner = api.session;
    if (owner == null) return;
    bool current() =>
        mounted &&
        identical(widget.api, api) &&
        api.session?.token == owner.token &&
        api.session?.userId == owner.userId;
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (!current() || photo == null) return;
      setState(() {
        busy = true;
        error = null;
      });
      final bytes = await photo.readAsBytes();
      if (!current()) return;
      if (bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('사진은 10MiB 이하로 선택해주세요.');
      }
      final name = photo.name.toLowerCase();
      final mime = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
      final event =
          widget.eventId ??
          RegExp(r'/events/([^/]+)').firstMatch(widget.path)?.group(1);
      final result = objectValue(
        await api.send(
          Command('/files', {
            'scope': widget.scope,
            if (widget.clubId != null) 'clubId': widget.clubId,
            'eventId': ?event,
            'contentType': mime,
            'fileBase64': base64Encode(bytes),
          }),
        ),
      );
      if (!current()) return;
      widget.controller.text = stringValue(
        result['reference'],
        'file.reference',
      );
      widget.onUploaded?.call(widget.controller.text);
    } catch (e) {
      if (current()) setState(() => error = e.toString());
    } finally {
      if (current()) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: busy || !widget.enabled ? null : pick,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(busy ? '사진 업로드 중' : '사진 선택'),
      ),
      if (widget.controller.text.isNotEmpty)
        Row(
          children: [
            const Expanded(child: Text('보호 사진 첨부됨')),
            TextButton(
              onPressed: () =>
                  showEvidence(context, widget.api, widget.controller.text),
              child: const Text('보기'),
            ),
            TextButton(
              onPressed: widget.enabled
                  ? () {
                      setState(() => widget.controller.clear());
                      widget.onRemoved?.call();
                    }
                  : null,
              child: const Text('첨부 해제'),
            ),
          ],
        ),
      if (error != null) Semantics(liveRegion: true, child: Text(error!)),
    ],
  );
}

Future<void> showEvidence(
  BuildContext context,
  Api api,
  String reference,
) async {
  if (!reference.startsWith('file:')) {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          AlertDialog(title: const Text('증빙 메모'), content: Text(reference)),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => ProtectedImage(api: api, id: reference.substring(5)),
  );
}

class ProtectedImage extends StatefulWidget {
  final Api api;
  final String id;
  const ProtectedImage({super.key, required this.api, required this.id});
  @override
  State<ProtectedImage> createState() => _ProtectedImageState();
}

class _ProtectedImageState extends State<ProtectedImage> {
  late Future<Uint8List> future;
  late String? token;
  @override
  void initState() {
    super.initState();
    token = widget.api.session?.token;
    future = widget.api.readFile(widget.id);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('보호 증빙'),
    content: SizedBox(
      width: 380,
      height: 480,
      child: FutureBuilder<Uint8List>(
        future: future,
        builder: (context, s) {
          if (s.hasError) return Text(s.error.toString());
          if (widget.api.session?.token != token) {
            return const Text('세션이 변경되어 증빙을 닫았습니다.');
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.data!.length >= 5 &&
              ascii.decode(s.data!.take(5).toList(), allowInvalid: true) ==
                  '%PDF-') {
            return ProtectedPdf(bytes: s.data!);
          }
          return InteractiveViewer(
            child: Image.memory(
              s.data!,
              gaplessPlayback: false,
              errorBuilder: (_, e, st) =>
                  const Text('이 증빙은 사진 형식으로 표시할 수 없습니다.'),
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
    ],
  );
}

class ProtectedPdf extends StatefulWidget {
  final Uint8List bytes;
  const ProtectedPdf({super.key, required this.bytes});
  @override
  State<ProtectedPdf> createState() => _ProtectedPdfState();
}

class _ProtectedPdfState extends State<ProtectedPdf> {
  late final PdfControllerPinch controller;
  @override
  void initState() {
    super.initState();
    controller = PdfControllerPinch(
      document: PdfDocument.openData(widget.bytes),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PdfViewPinch(controller: controller);
}
