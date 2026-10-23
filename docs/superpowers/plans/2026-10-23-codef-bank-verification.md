# CODEF Bank Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Implement the previously designed CODEF holder lookup and one-won challenge across all account registration paths.

**Architecture:** A fixed-host gateway handles provider protocol. Durable challenge phases prevent a repeated HTTP request from repeating a one-won transfer. A single-use proof is consumed atomically by existing account writes; Flutter shares a verification dialog across three contexts.

**Tech Stack:** Java25, Gradle9.8.2, Spring Boot4.1.1, PostgreSQL17/Flyway/JPA, Flutter3.47.7.

**Spec:** `docs/implementation/BANK-VERIFICATION.md`.

## Global Constraints

- Never read or edit `review/`; no real provider call, secret search, or real one-won transfer in tests.
- Signup remains social+SMS; bank identity input is separate and transient.
- CODEF_MODE defaults DISABLED. DEMO cannot verify a real account.
- All money, role, custody, immutable history, actual receipt, version and transaction namespace rules remain unchanged.
- 10-minute expiry; 5 code attempts; 120-second per-user request interval; 5 same-account requests/day.
- Bank institution codes come from server configuration, never guessed from example padding.

## Review Focus

1. HTTP request replay/timeout/crash after transfer dispatch must never send another one-won transfer.
2. A wrong code response must persist its attempt; retrying its same key must not consume another attempt.
3. A verified proof must not be reused across actor, bank, account, purpose or context, and stale account writes must not consume it.
4. Raw JSON plus signs, encoded Unicode names, HTTP200 provider errors and missing product fields must not produce false success.
5. Navigation/session change or final version conflict must preserve the original verified account and avoid silently repeating bank authentication.

### Task 1: Provider gateway (independent ownership)

**Files:** create `apps/api/src/main/java/com/moishow/identity/CodefGateway.java`, test `apps/api/src/test/java/com/moishow/identity/CodefGatewayTest.java`.

**Interfaces:** package-private component `CodefGateway(Environment env)`; package-private test constructor `(Environment env, Transport transport)`; `interface Transport { Reply send(java.net.http.HttpRequest request) throws Exception; }`, `record Reply(int status,String body)`, `record Bank(String id,String name,String holderOrganization,String transferOrganization)`, `record Transfer(String code,String reference)`; methods `boolean live()`, `List<Bank> banks()`, `Bank bank(String id)`, `String holder(Bank bank,String account,String identity)`, `Transfer transfer(Bank bank,String account)`. Use `ApiProblem` codes and no request/response log. Configuration malformed fails closed. Production HTTP client no automatic retries. Root/backend agent consumes these exact names.

- [x] Add protocol tests for encoded JSON, OAuth Basic/form/token reuse, organization selection, inPrintType=0, one decode, CF errors/missing fields, no retries, disabled/demo live=false.
- [x] Run focused Gradle test; capture genuine RED before production implementation.
- [x] Implement gateway contract; run tests GREEN and report evidence/files to root. No Git mutation. Revocation followup13/13 GREEN, actual RED preserved.

### Task 2: Durable challenge and atomic account proof

**Files:** create `BankVerificationModels.java`, `BankVerificationService.java`, `BankVerificationController.java`, `V12__bank_verification.sql`, `BankVerificationApiTest.java`; modify `BankData.java`, `BankOwnershipVerifier.java`, `PersonalBankController.java`, `PersonalBankService.java`, `ReserveController.java`, `ReserveService.java`.

**Interfaces:** spec HTTP shapes are exact. Extend verifier with default `String verify(UUID userId,String bank,String accountNumber,String holderName,UUID verificationId,String purpose,UUID contextId)` delegating old four-argument method for test-only lambdas; production old method fails PROOF_REQUIRED and new method consumes exact proof. New optional `UUID verificationId` is added to personal/reserve forms, with backward-compatible constructors for Java fixtures and null-excluding serialization to preserve old body fingerprints. Use `TransactionTemplate` to commit phase transitions outside Commands, never hold DB transaction across provider HTTP. Controller creation calls Commands to persist id then dispatches only if pending. Confirm persists invalid-attempt result before controller raises error. No identity in DB or receipt response.

- [x] Add actual PG/HTTP tests pinning owner-only status/list, expiry/attempt lock, wrong-key replay, concurrent starts/dispatch, ambiguous timeout, code secrecy, binding mismatch, stale version rollback, successful atomic proof consumption in personal and reserve paths.
- [x] Run focused test RED, implement minimal contract and all existing role/version/cash checks, run GREEN.
- [x] Run existing BankApiTest/ReserveApiTest/identity regressions and inspect migration constraints. Report evidence; root owns Git.

### Task 3: Shared Flutter flow

**Files:** create `apps/mobile/lib/bank_verification.dart`, `apps/mobile/test/bank_verification_test.dart`; modify `bank_account.dart`, `settlement_screens.dart`, `handover_review.dart`, precise errors in `api.dart`.

**Interfaces:** `Future<Map<String,dynamic>?> verifyBankAccount(BuildContext context, Api api,{required String purpose,String? contextId})`; returns only `{bankName,accountNumber,holderName,verificationId}` on VERIFIED and explicit final submit, null on close. Begin/confirm use only in-memory immutable command/key via api.request, never persistent intent journal; preserve session guards. Existing final account writes keep the current persistent immutable journal. Bank choices GET, begin POST, status/list GET and confirm POST exactly as spec; no client organization fields or supplied bank-code bypass. Code form only after AWAITING_CODE; explicit retry of status on timeouts, never a new begin as a fallback. Incoming pending/verified proof list supports route re-entry without new transfer.

- [x] Add widget/contract tests for two stages, disabled provider, code failure/lock, unknown status, context binding, stale final write retaining proof and old account, session cancellation.
- [x] Run tests RED, implement shared dialog and all three entry points, tests GREEN/analyze/full mobile suite.

### Task 4: Review, verification and integration

**Files:** update `docs/external/codef.md`, `docs/implementation/REQUIREMENTS-AUDIT.md`, API/env/runbook docs, issue3 and Obsidian current facts.

- [x] Compare every implementation with POLICY/spec/issue3 and record chosen defaults and known limitations centrally.
- [x] Independent review of transfer retry, concurrency, permissions, private inputs, app journals and provider failure boundaries; fix concrete findings with regression evidence.
- [x] Local Java25 Gradle test/build196, Flutter analyze/test101/web/APK, handoff checks; explicit source commits and independent review recorded.

Remote promotion status is recorded in the GitHub PR exact-head checks/merge commit and Obsidian current project note, rather than inferred from this local-verification checkbox. Create+attach the develop PR, merge only after its checks pass, then promote to main under the existing user authorization.
- [x] Keep live provider approval/keys/bank mapping/real transfer/iOS and source-account namespace limitations explicit. Update vault and audit links.
