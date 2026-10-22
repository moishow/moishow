import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'models.dart';
import 'widgets.dart';

class ClubInvitation extends StatefulWidget {
  final Api api;
  final String clubId;
  final int version;
  final VoidCallback reload;
  const ClubInvitation({
    super.key,
    required this.api,
    required this.clubId,
    required this.version,
    required this.reload,
  });
  @override
  State<ClubInvitation> createState() => _ClubInvitationState();
}

class _ClubInvitationState extends State<ClubInvitation> {
  bool busy = false, conflict = false;
  String? error;
  Command? pending;
  Future<void> create() async {
    pending ??= Command('/clubs/${widget.clubId}/invites', {
      'version': widget.version,
    });
    setState(() => busy = true);
    try {
      final result = objectValue(await widget.api.send(pending!));
      final token = stringValue(result['inviteToken'], 'invitation.token');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('모임 초대'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('이 토큰을 받은 사람이 모임 가입에 사용할 수 있습니다.'),
              SelectableText(token),
              Text('만료 ${result['expiresAt']}'),
              TextButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: token)),
                child: const Text('초대 토큰 복사'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
      widget.reload();
      pending = null;
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          conflict = e is ApiFailure && e.status == 409;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error != null) Semantics(liveRegion: true, child: Note(error!)),
      if (conflict)
        OutlinedButton(
          onPressed: widget.reload,
          child: const Text('최신 모임 불러오기'),
        ),
      OutlinedButton(
        onPressed: busy || conflict ? null : create,
        child: Text(
          busy
              ? '초대 토큰 생성 중'
              : error == null
              ? '초대 토큰 생성'
              : '같은 초대 요청 재시도',
        ),
      ),
    ],
  );
}
