import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

String normalizePhone(String input) {
  final value = input.replaceAll(RegExp(r'[\s()-]'), '');
  if (RegExp(r'^010\d{8}$').hasMatch(value)) return '+82${value.substring(1)}';
  if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value)) {
    throw const FormatException('휴대전화 번호 또는 국가번호가 포함된 번호를 확인해주세요.');
  }
  return value;
}

const providerHelp = {
  'Google': 'https://support.google.com/accounts/answer/7682439?hl=ko',
  'Apple': 'https://iforgot.apple.com/',
  '카카오': 'https://cs.kakao.com/helps?service=52',
};

class KnownProviderHelp extends StatelessWidget {
  const KnownProviderHelp({super.key});
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('기존 로그인 계정 찾기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '가입 때 사용한 소셜 계정을 해당 공급자에서 복구한 뒤 다시 로그인해주세요. 전화번호만으로 다른 소셜 계정과 합치지 않습니다.',
            ),
            for (final link in providerHelp.entries)
              TextButton(
                onPressed: () async {
                  try {
                    final opened = await launchUrl(
                      Uri.parse(link.value),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened) throw StateError('open failed');
                  } catch (_) {
                    if (dialog.mounted) {
                      ScaffoldMessenger.of(dialog).showSnackBar(
                        const SnackBar(
                          content: Text('도움말을 열지 못했습니다. 연결을 확인해주세요.'),
                        ),
                      );
                    }
                  }
                },
                child: Text('${link.key} 계정 도움말'),
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
    ),
    child: const Text('기존 로그인 계정을 찾고 싶어요'),
  );
}
