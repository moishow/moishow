# File Picker Session Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Prevent a photo selected by one account from being uploaded or journaled under another account after an asynchronous picker/read.

**Architecture:** EvidencePicker owns its starting session for the entire selection/read/upload lifecycle. Check both mounted state and the same token before every post-await continuation that can send data or change a controller. Existing Api.send keeps its own synchronous owner capture and post-journal guard; server file ownership and all resource permissions remain unchanged.

**Tech Stack:** Flutter3.47.7, Dart3.13.5, existing image_picker and Api immutable command journal.

**Spec:** POLICY P09/P10, `docs/implementation/FILES-API.md`, issue16, the demonstrated RED recorded in REQUIREMENTS-AUDIT. This is a requirement correction, not a new policy.

## Global Constraints

- Never access `review/`; no real private photo, provider request, or production upload in tests.
- Preserve all existing file scopes, size/MIME checks, staged-owner restrictions and server ACLs.
- Capture the starting API/session before the first picker await. No session means no picker request.
- After picker return, byte read and API response, a disposed widget or changed token cannot send data or update a controller/callback.
- Do not modify generic ProfileFields/CommandForm without a demonstrated real-router failure. Real routing already disposes ordinary stale forms.
- Any test platform-interface dependency must use the existing locked version and remain dev-only.
- Android builds use JDK21 (`C:/Program Files/Eclipse Adoptium/jdk-21.0.12.101-hotspot`); server Java25 is unchanged. Set JAVA_HOME/PATH in the build process only, never change global Flutter/user configuration.

## Review Focus

1. A selects a file, byte read waits, A signs out and B signs in through the real router: zero B HTTP requests and no B journal payload.
2. Picker returns after its widget was disposed: no setState-after-dispose, controller update or upload.
3. A valid selection under the unchanged owner still uploads once and returns its exact private reference.
4. Session changes during Api.send's existing journal/network await: existing guards remain effective and late callbacks do not mutate the new account.
5. Private profile and expense/dispute/payment callers keep the same server scopes and access rules.

### Task 1: Pin and fix the lifecycle

**Files:** modify `apps/mobile/lib/attachments.dart`; create `apps/mobile/test/stale_actor_forms_test.dart`; if analyzer requires it, add only existing-lock `image_picker_platform_interface` to dev_dependencies and update lock directness in `apps/mobile/pubspec.yaml`/`pubspec.lock`.

**Interfaces:** retain EvidencePicker public API and Api.send. The picker captures `widget.api` and its current session token before `ImagePicker().pickImage`; a local predicate checks mounted and exact token at each continuation. Preserve cancellation without changing the controller.

- [x] Add real MoishowApp/router + real Api/journal regression for deferred XFile.readAsBytes and A→login→B. Observe actual assertion RED: `/files` used B bearer and stored A bytes in B journal after ProfileFields disposal.
- [x] Add picker-return-after-dispose assertion RED and unchanged-owner upload/callback assertion. Use synthetic fixture bytes and a wire adapter only.
- [x] Apply the smallest lifecycle checks in attachments.dart. No broad form rewrite.
- [x] Focused tests GREEN, analyzer and full Flutter suite. Verify existing caller/ACL contract remains intact by diff and independent review.

### Task 2: Verification and promotion

**Files:** update REQUIREMENTS-AUDIT, MOBILE-APP, issue16 and Obsidian current facts. Existing Java source remains unchanged.

- [x] Review the exact async boundaries independently, including late controller/callback access.
- [x] Build TEST web193.5s, production web142.8s and JDK21 debugAPK224.3s for the frozen source. Prior Java196 evidence remains valid for unchanged server sources; remote CI still verifies the full repository.
- [x] Commit explicit source files after105/analyze/independent closure and preserve the exact platform/GUI evidence.

Create+attach the develop PR and merge only after exact-head CI. When main is an ancestor and the merge tree equals the tested source, promote by nonforce fast-forward; use a normal main PR if protection requires it. Keep real provider/device/iOS acceptance separate.

Remote promotion outcome is tracked in GitHub PR checks/merge commits and the vault, rather than inferred from local test checkboxes.

Use `flutter build web --target test_support/main.dart --output build/test_web` for the retained TEST preview, `flutter build web` for production, and `flutter build apk --debug` with the explicit JDK21 process environment. These outputs must remain distinct. An APK built under the inherited user JAVA_HOME25 is diagnostic only, not final Android acceptance.
