# LMS SDK

Dart/Flutter LMS domain SDK — lesson-player experience, tutor presence,
MCQ checkpoints, break-bridge/office-hours orchestration.

## Running the tests standalone

This package's UI strings go through `TrKeys` (base_sdk), and this SDK's own
keys live in `manifest.json` `tr_keys` — at compose time the installer injects
them into the host's `TrKeys` between its `@sdk-tr-keys-start`/`-end` markers.
A standalone checkout resolves base_sdk from the workspace (see
`dependency_overrides`), where that marker region is empty, so the package
only compiles after the same injection is applied locally:

```sh
cd lms/dart
flutter pub get
dart run tool/inject_tr_keys.dart   # injects manifest tr_keys into the
                                    # resolved base_sdk checkout (idempotent)
flutter test
```

The injector reads the same `manifest.json` map the compose step consumes, so
the standalone harness cannot drift from compose: add a key to the manifest
and re-run the tool. See `tool/inject_tr_keys.dart` for details.

## Tooling

### `tool/sync_team_assets.dart` — team asset sync

Consumable team assets — tutor/assistant appearance renders, onboarding
slide renders, and (future) persona audio — ship as package assets under
`assets/team/` (declared in `pubspec.yaml`), so host apps resolve them as
`packages/lms_sdk/assets/team/...` keys on any machine, CI runner or
device. The files are vendored from the team folder (`lms/team/`), which
stays the source of truth. The rule: everything under any `renders/`
directory ships except `.json`/`.md` pipeline metadata, plus audio files
(`.mp3`/`.wav`/`.m4a`/`.ogg`) anywhere under `lms/team`; scripts, prompts,
briefs and source portraits outside `renders/` never ship. The tool prunes
stale copies and regenerates the `flutter: assets:` directory list between
the `# BEGIN team-assets` / `# END team-assets` markers, so a new persona
or slide deck needs no manual pubspec edit.

CI runs the sync automatically on pushes touching `lms/team/**`
(`.github/workflows/sync_team_assets.yml`). To run it by hand:

```sh
cd lms/dart
dart run tool/sync_team_assets.dart
```

### `tool/validate_animations.dart` — primitive-type content gate

The whiteboard painter implements a subset of the replaysdk-spec primitive
vocabulary (`dot`, `circle`, `rect`, `line`, `text`, plus the
`clear`/`fade_out` removal and `camera_move`/`band_start` camera events).
Spec types the painter does not implement yet (`mathtex`, `shape`, `graph`,
`hand_overlay`, `transform`) render as marker dots at runtime. This
validator turns that silent degradation into a hard failure for
factory-exported `animations.json` files:

```sh
cd lms/dart
dart run tool/validate_animations.dart path/to/animations.json [more.json ...]
```

Exit 0 = every primitive type is supported; exit 1 = unsupported types
found (each listed with index and timestamp); exit 2 = usage/parse error.

The supported set has ONE source of truth —
`lib/src/common/controllers/whiteboard_primitive_types.dart` — which the
player itself uses for its removal/camera classification. When the painter
learns a new primitive type, extend that file and the painter switch in the
same change; the validator picks it up automatically.

**CI wiring:** the repo's current workflows run the shared universal
linter only (no Dart toolchain job) and no `animations.json` files live
in this repo, so the gate is not wired into `.github/workflows/` yet. Run
it wherever content lands, e.g. in the factory/content pipeline:

```yaml
- uses: dart-lang/setup-dart@v1
- run: dart run tool/validate_animations.dart $(git ls-files '*animations*.json')
  working-directory: lms/dart
```
