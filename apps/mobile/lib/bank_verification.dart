import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'widgets.dart'
    show formatTimestamp, obj, rows, actionForm, FormFieldSpec;

/// The final persistent command belongs to the session that verified the bank.
Api verifiedBankCommandApi(Api api, String? owner) => _BankActorApi(api, owner);

class _BankActorApi extends Api {
  final Api original;
  final String? owner;
  _BankActorApi(this.original, this.owner)
    : super(
        dio: original.dio,
        store: original.store,
        intents: original.intents,
      );

  @override
  Future<dynamic> send(Command command) async {
    if (owner == null ||
        owner != original.session?.token ||
        original.session?.active != true) {
      throw const ApiFailure(401, 'SESSION_CHANGED');
    }
    // No await before delegation: Api.send captures this same owner/token
    // synchronously, then rechecks it after asynchronous journal persistence.
    return original.send(command);
  }
}

Future<void> verifiedBankAction(
  BuildContext context,
  Api api, {
  required String purpose,
  String? contextId,
  required String title,
  required String path,
  required Json base,
  required VoidCallback reload,
  List<FormFieldSpec> fields = const [],
  String? notice,
}) async {
  final owner = api.session?.token;
  final verified = await verifyBankAccount(
    context,
    api,
    purpose: purpose,
    contextId: contextId,
  );
  if (verified == null || !context.mounted || owner != api.session?.token) {
    return;
  }
  await actionForm(
    context,
    verifiedBankCommandApi(api, owner),
    title: title,
    path: path,
    fields: fields,
    base: {...base, ...verified},
    reload: reload,
    notice:
        '${notice ?? ''}\n인증된 계좌를 최종 등록합니다. 성공 전까지 기존 계좌는 유지됩니다. 다른 변경이 있으면 최신 자료를 조회한 뒤 이전 인증을 선택할 수 있습니다.',
  );
}

/// Only this ephemeral dialog handles DOB/code. They never enter Api.send's
/// persistent business-command journal. A transport retry reuses one frozen key.
Future<Map<String, dynamic>?> verifyBankAccount(
  BuildContext context,
  Api api, {
  required String purpose,
  String? contextId,
}) {
  if (!{'PERSONAL', 'RESERVE', 'RESERVE_HANDOVER'}.contains(purpose) ||
      (purpose == 'PERSONAL' ? contextId != null : contextId == null)) {
    throw ArgumentError('계좌 인증 목적과 문맥을 확인해주세요.');
  }
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) =>
        _BankVerification(api: api, purpose: purpose, contextId: contextId),
  );
}

class _BankVerification extends StatefulWidget {
  final Api api;
  final String purpose;
  final String? contextId;
  const _BankVerification({
    required this.api,
    required this.purpose,
    this.contextId,
  });
  @override
  State<_BankVerification> createState() => _BankVerificationState();
}

class _BankVerificationState extends State<_BankVerification> {
  final account = TextEditingController(),
      holder = TextEditingController(),
      identity = TextEditingController(),
      code = TextEditingController();
  final form = GlobalKey<FormState>();
  late final String? ownerToken;
  bool busy = true, available = false, resumed = false, sessionChanged = false;
  bool statusNeedsRefresh = false;
  List<Json> banks = [], previous = [];
  String? bankId, error;
  Json? proof;
  Command? pending;
  String? pendingKind;
  static const states = {
    'PENDING',
    'HOLDER_CHECK',
    'TRANSFER_DISPATCHED',
    'AWAITING_CODE',
    'VERIFIED',
    'CONSUMED',
    'FAILED',
    'UNKNOWN',
    'EXPIRED',
    'LOCKED',
  };
  String get status {
    if (proof == null) return '';
    if (DateTime.parse(proof!['expiresAt']).isBefore(DateTime.now()) &&
        !{'CONSUMED', 'EXPIRED'}.contains(proof!['status'])) {
      return 'EXPIRED';
    }
    return proof!['status'];
  }

  bool get owns =>
      !sessionChanged &&
      ownerToken != null &&
      widget.api.session?.active == true &&
      ownerToken == widget.api.session?.token;
  void guard() {
    if (!owns) throw const ApiFailure(401, 'SESSION_CHANGED');
  }

  void failure(Object e) {
    if (!mounted) return;
    setState(() {
      sessionChanged = !owns;
      error = sessionChanged
          ? '로그인 계정이 변경되었습니다. 이 인증창을 닫고 다시 시작해주세요.'
          : e.toString();
      if (sessionChanged) {
        pending = null;
        identity.clear();
        code.clear();
        account.clear();
        holder.clear();
      }
    });
  }

  Json view(dynamic value) {
    final v = obj(value);
    stringValue(v['id'], 'verification.id');
    if (!states.contains(v['status'])) {
      throw const ContractError('verification.status');
    }
    DateTime.parse(stringValue(v['expiresAt'], 'verification.expiry'));
    stringValue(v['bankName'], 'verification.bank');
    stringValue(v['accountMasked'], 'verification.account');
    final remaining = integerValue(
      v['attemptsRemaining'],
      'verification.attempts',
    );
    if (remaining < 0 || remaining > 5) {
      throw const ContractError('verification.attempts');
    }
    return v;
  }

  @override
  void initState() {
    super.initState();
    ownerToken = widget.api.session?.token;
    load();
  }

  Future<void> load() async {
    try {
      guard();
      final catalog = obj(await widget.api.get('/bank-verifications/banks'));
      guard();
      if (catalog['available'] is! bool) {
        throw const ContractError('banks.available');
      }
      final loaded = rows(catalog['banks']);
      for (final b in loaded) {
        stringValue(b['id'], 'bank.id');
        stringValue(b['name'], 'bank.name');
      }
      final list = rows(
        await widget.api.get(
          Uri(
            path: '/bank-verifications',
            queryParameters: {
              'purpose': widget.purpose,
              if (widget.contextId != null) 'contextId': widget.contextId!,
            },
          ).toString(),
        ),
      );
      guard();
      if (mounted) {
        setState(() {
          available = catalog['available'];
          banks = loaded;
          previous = list.map(view).toList();
        });
      }
    } catch (e) {
      failure(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
      statusNeedsRefresh = true;
    });
    try {
      guard();
      final current = view(
        await widget.api.get('/bank-verifications/${proof!['id']}'),
      );
      guard();
      if (mounted) {
        setState(() {
          proof = current;
          statusNeedsRefresh = false;
          if (pendingKind == 'confirm' &&
              current['status'] != 'AWAITING_CODE') {
            pending = null;
            pendingKind = null;
            code.clear();
          }
        });
      }
    } catch (e) {
      failure(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> dispatch(Command command, String kind) async {
    setState(() {
      busy = true;
      error = null;
      pending = command;
      pendingKind = kind;
    });
    try {
      guard();
      final current = view(
        await widget.api.request(
          'POST',
          command.path,
          body: command.body,
          key: command.key,
        ),
      );
      guard();
      if (mounted) {
        setState(() {
          proof = current;
          statusNeedsRefresh = false;
          pending = null;
          pendingKind = null;
          identity.clear();
          if (kind == 'confirm') code.clear();
        });
      }
    } catch (e) {
      failure(e);
      if (kind == 'confirm' && mounted) {
        setState(() => statusNeedsRefresh = true);
      }
      if (e is ApiFailure &&
          e.status != null &&
          e.status! >= 400 &&
          e.status! < 500 &&
          owns) {
        pending = null;
        pendingKind = null;
        if (kind == 'confirm' && proof != null) {
          try {
            final current = view(
              await widget.api.get('/bank-verifications/${proof!['id']}'),
            );
            guard();
            if (mounted) {
              setState(() {
                proof = current;
                statusNeedsRefresh = false;
              });
            }
          } catch (statusError) {
            failure(statusError);
          }
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> begin() async {
    if (!form.currentState!.validate()) return;
    final selected = banks.singleWhere((b) => b['id'] == bankId);
    await dispatch(
      Command('/bank-verifications', {
        'purpose': widget.purpose,
        if (widget.contextId != null) 'contextId': widget.contextId,
        'bankId': selected['id'],
        'accountNumber': account.text.trim(),
        'holderName': holder.text.trim(),
        'identity': identity.text.trim(),
      }),
      'begin',
    );
  }

  Future<void> confirm() async {
    if (statusNeedsRefresh) return;
    if (!RegExp(r'^\d{4}$').hasMatch(code.text.trim())) {
      setState(() => error = '인증번호 4자리를 입력해주세요.');
      return;
    }
    await dispatch(
      Command('/bank-verifications/${proof!['id']}/confirm', {
        'code': code.text.trim(),
      }),
      'confirm',
    );
  }

  void finish() {
    try {
      guard();
      if (status != 'VERIFIED' || statusNeedsRefresh) return;
      if (resumed && !form.currentState!.validate()) return;
      Navigator.pop(
        context,
        Map<String, dynamic>.unmodifiable({
          'bankName': proof!['bankName'],
          'accountNumber': account.text.trim(),
          'holderName': holder.text.trim(),
          'verificationId': proof!['id'],
        }),
      );
    } catch (e) {
      failure(e);
    }
  }

  void select(Json p) {
    setState(() {
      proof = p;
      resumed = true;
      pending = null;
      pendingKind = null;
      error = null;
      account.clear();
      holder.clear();
      identity.clear();
      code.clear();
    });
    refresh();
  }

  @override
  void dispose() {
    account.dispose();
    holder.dispose();
    identity.dispose();
    code.dispose();
    pending = null;
    super.dispose();
  }

  Widget field(
    TextEditingController c,
    String label, {
    bool digits = false,
    int? length,
  }) => TextFormField(
    controller: c,
    decoration: InputDecoration(labelText: label),
    enabled: !busy && pending == null && owns,
    keyboardType: digits ? TextInputType.number : TextInputType.text,
    obscureText: c == identity,
    enableSuggestions: !digits,
    autocorrect: !digits,
    validator: (v) {
      final value = (v ?? '').trim();
      if (value.isEmpty) return '입력해주세요.';
      if (digits && !RegExp(r'^\d+$').hasMatch(value)) return '숫자만 입력해주세요.';
      if (length != null && value.length != length) return '$length자리를 입력해주세요.';
      return null;
    },
  );
  String statusLabel(dynamic value) => switch (value) {
    'PENDING' => '요청 접수',
    'HOLDER_CHECK' => '예금주 확인 중',
    'TRANSFER_DISPATCHED' => '인증 전송 확인 중',
    'AWAITING_CODE' => '인증번호 입력 대기',
    'VERIFIED' => '계좌 확인 완료',
    'CONSUMED' => '등록에 사용됨',
    'FAILED' => '요청 실패',
    'UNKNOWN' => '결과 미확인',
    'EXPIRED' => '유효 시간 만료',
    'LOCKED' => '시도 횟수 초과',
    _ => '상태 확인 필요',
  };
  String get description => switch (status) {
    'AWAITING_CODE' => '통장에 표시된 인증번호 4자리를 입력해주세요.',
    'VERIFIED' => '계좌 확인이 완료되었습니다. 계좌 등록은 다음 화면에서 최종 제출해야 합니다.',
    'UNKNOWN' => '결과 미확인입니다. 1원 인증을 다시 요청하지 말고 상태를 조회해주세요.',
    'FAILED' => '은행 인증 요청을 완료하지 못했습니다. 기존 등록 계좌는 유지됩니다.',
    'LOCKED' => '인증번호 시도 횟수를 모두 사용했습니다.',
    'EXPIRED' => '인증 유효 시간이 지났습니다. 이 인증으로 등록할 수 없습니다.',
    'CONSUMED' => '이미 계좌 등록에 사용한 인증입니다.',
    _ => '은행 인증 처리 중입니다. 재요청하지 말고 상태를 조회해주세요.',
  };
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('계좌 소유 확인'),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '가입·전화번호 인증과 별개입니다. 1원 인증은 회비·환불 송금 완료를 뜻하지 않습니다. 생년월일과 인증번호는 이 인증창에서만 사용합니다.',
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (!busy && !available)
                const Text('지금은 계좌 인증을 이용할 수 없습니다. 기존 등록 계좌는 유지됩니다.'),
              if (owns && proof == null && !busy) ...[
                for (final p in previous)
                  TextButton(
                    onPressed: () => select(p),
                    child: Text(
                      '이전 인증 선택 · ${p['bankName']} ${p['accountMasked']} · ${statusLabel(p['status'])}',
                    ),
                  ),
              ],
              if (owns && proof == null && available) ...[
                DropdownButtonFormField<String>(
                  initialValue: bankId,
                  decoration: const InputDecoration(labelText: '은행 선택'),
                  items: [
                    for (final b in banks)
                      DropdownMenuItem(
                        value: b['id'] as String,
                        child: Text(b['name']),
                      ),
                  ],
                  onChanged: busy || pending != null
                      ? null
                      : (v) => setState(() => bankId = v),
                  validator: (v) => v == null ? '은행을 선택해주세요.' : null,
                ),
                field(account, '계좌번호', digits: true),
                field(holder, '예금주명'),
                field(identity, '생년월일 6자리 (YYMMDD)', digits: true, length: 6),
                if (pending == null)
                  FilledButton(
                    onPressed: busy ? null : begin,
                    child: const Text('1원 인증 요청'),
                  ),
              ],
              if (owns && proof != null) ...[
                Text('${proof!['bankName']} ${proof!['accountMasked']}'),
                Text('인증 만료 ${formatTimestamp(proof!['expiresAt'])}'),
                Text(description),
                if (status == 'AWAITING_CODE') ...[
                  Text(
                    statusNeedsRefresh
                        ? '남은 시도 횟수 확인 필요 · 인증 상태를 다시 조회해주세요.'
                        : '남은 시도 횟수 ${proof!['attemptsRemaining']}회',
                  ),
                  field(code, '인증번호 4자리', digits: true, length: 4),
                  if (pending == null)
                    FilledButton(
                      onPressed: busy || statusNeedsRefresh ? null : confirm,
                      child: const Text('인증번호 확인'),
                    ),
                ],
                if (status == 'VERIFIED') ...[
                  if (resumed) ...[
                    const Text('인증한 계좌번호와 예금주를 다시 입력해주세요. 이전 인증 정보와 일치해야 합니다.'),
                    field(account, '계좌번호', digits: true),
                    field(holder, '예금주명'),
                  ],
                  FilledButton(
                    onPressed: busy || statusNeedsRefresh ? null : finish,
                    child: const Text('이 계좌로 등록 계속'),
                  ),
                ],
                OutlinedButton(
                  onPressed: busy ? null : refresh,
                  child: const Text('인증 상태 다시 조회'),
                ),
              ],
              if (owns && pending != null && !busy) ...[
                const Text(
                  '처리 결과를 확인하지 못했습니다. 상태를 조회하거나 같은 요청을 다시 확인해주세요. 새 1원 인증을 자동 요청하지 않습니다.',
                ),
                FilledButton(
                  onPressed: () => dispatch(pending!, pendingKind!),
                  child: const Text('같은 요청 다시 확인'),
                ),
                if (pendingKind == 'begin')
                  TextButton(
                    onPressed: () {
                      setState(() => busy = true);
                      load();
                    },
                    child: const Text('이전 인증에서 상태 확인'),
                  ),
              ],
              if (!busy &&
                  error != null &&
                  proof == null &&
                  pending == null &&
                  owns)
                TextButton(
                  onPressed: () {
                    setState(() => busy = true);
                    load();
                  },
                  child: const Text('은행 목록·이전 인증 다시 조회'),
                ),
            ],
          ),
        ),
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
