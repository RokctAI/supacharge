# Changelog

## 1.0.4

- `assistant_history_table` is owner-scoped. It gains an `owner` column
  (NOT NULL, defaulting to the empty string) which joins the primary key
  alongside `id`, so two accounts on one device cannot read each other's
  assistant transcripts and an offline id minted from the clock can no
  longer have one account's message silently replace another's. Reads
  filter with base_sdk's `ownerVisible(owner, me)` - the current account's
  rows plus every unowned one - and writes stamp
  `OwnerScope.instance.current`.
- Scoping is a VISIBILITY rule, never a deletion: signing out writes
  nothing and removes nothing. The departing account's history stays on
  disk, invisible to the next account, and comes back in full when that
  account signs in again.
- Migration version 21 (shared fleetwide namespace, declared in
  `manifest.json`). The step rebuilds the table the long way round -
  rename aside, recreate, copy the shared columns, drop - because SQLite
  cannot alter a primary key in place. Rows already on the device take the
  `''` default and stay visible to everyone, so the upgrade is invisible
  to the account already using the app. `ensureAgentOwnerScopeColumns` is
  idempotent and self-checking, the same shape as base_sdk's
  `ensureOwnerScopeColumns`.
- `assistant_cache_table` is deliberately NOT scoped: a question and its
  answer are content, not a record of who asked.
- Requires base_sdk 1.67.0 (`OwnerScope`, `kUnownedOwner`, `ownerVisible`).

## 1.0.3

Fix-wave 2026-09-02 (Dart SDK audit, agent items).

- A2: `AgentRepository.submitHomework` no longer posts multipart to
  `/api/v1/method/agent.api.submit_homework` — an alias no manifest ever
  declared, so every submission 404'd. Photos now go up one by one through
  core's upload door (`/api/v1/method/rcore.api.upload.upload_file`,
  multipart, private), and only the returned `file_url`s ride the JSON
  gateway call to `api.lms.submit_homework_question` (lms's
  `rlms.api.homework.submit_homework_question`). The facade gains an
  optional `questionText`; a photos-only submission is labelled with the
  lesson id because the server refuses an empty question. The result is
  the new question's id. `AgentRepository.uploadAppPrefix` is the boot-time
  override point for the served shell app (mirrors lms_sdk).
- A3: deleted the commented-out `AiTranslationProvider` adapter example
  in `agent_di.dart` that targeted the Laravel-era
  `/api/v1/dashboard/seller/ai-translations` path (never served by the
  Frappe router). The `AiTranslationProvider` interface itself is
  unchanged.
- New `test/agent_repository_test.dart` pins the two-step submission
  (request paths, multipart field names, gateway `cmd` + payload keys,
  failure posture) with a scripted Dio adapter; `flutter_test` added to
  dev_dependencies.
