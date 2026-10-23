import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main.dart';
import 'models.dart';
import 'widgets.dart';
import 'bank_verification.dart';

class BankAccountPanel extends ConsumerWidget {
  const BankAccountPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Remote(
    path: '/me/bank-account',
    builder: (v, reload) {
      final bank = obj(v);
      if (bank['registered'] is! bool) {
        throw const ContractError('bank.registered');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading('개인 계좌 등록·확인'),
          if (bank['registered'] == true)
            Note(
              '${stringValue(bank['bankName'], 'bank.name')} ${stringValue(bank['accountMasked'], 'bank.mask')}\n예금주 ${stringValue(bank['holderMasked'], 'bank.holder')}\n확인 시각 ${DateTime.parse(bank['verifiedAt']).toLocal()}',
            )
          else
            const Text('확인된 개인 계좌가 없습니다.'),
          const Note(
            '계좌 확인은 가입·전화번호 인증과 별개입니다. 새 계좌의 최종 등록을 마치기 전까지 기존 등록 계좌는 유지됩니다.',
          ),
          OutlinedButton(
            onPressed: () => verifiedBankAction(
              context,
              ref.read(apiProvider),
              purpose: 'PERSONAL',
              title: '개인 계좌 등록·예금주 확인',
              path: '/me/bank-account',
              base: {'version': integerValue(bank['version'], 'bank.version')},
              reload: reload,
            ),
            child: Text(
              bank['registered'] == true ? '계좌 변경·다시 확인' : '계좌 등록·예금주 확인',
            ),
          ),
        ],
      );
    },
  );
}
