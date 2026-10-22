import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets.dart';
import 'models.dart';

class TransferInstructions extends StatelessWidget {
  final String path, title;
  const TransferInstructions({
    super.key,
    required this.path,
    required this.title,
  });
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text(title),
    children: [
      Remote(
        key: UniqueKey(),
        path: path,
        builder: (v, r) {
          final bank = obj(v);
          final number = stringValue(bank['accountNumber'], '송금 계좌');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bank['pendingVerification'] == true)
                const Note(
                  '신고한 입금이 확인 대기 중입니다. 추가 미납으로 오해해 중복 송금하지 않도록 실제 내역을 확인해주세요.',
                ),
              Note(
                '${stringValue(bank['bankName'], '은행')} $number\n예금주 ${stringValue(bank['holderName'], '예금주')}\n이번 요청 안내 금액 ${won(bank['amount'])}\n계좌 확인 ${DateTime.parse(bank['verifiedAt']).toLocal()}',
              ),
              OutlinedButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: number)),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('계좌번호 복사'),
              ),
              const Text('앱은 송금하지 않습니다. 외부 계좌에서 실제 거래한 뒤 해당 기록을 남겨주세요.'),
            ],
          );
        },
      ),
    ],
  );
}
