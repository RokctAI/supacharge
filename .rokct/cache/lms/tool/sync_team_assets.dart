// Copyright (c) 2026 ROKCT INTELLIGENCE (PTY) LTD
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.


// Vendors every consumable team asset out of the team folder
// (`lms/team/`) into this package's `templates/assets/team/` tree. The
// files do NOT ship inside the package: lms_sdk is the home SDK, so the
// SDK installer copies them into the APP SHELL (manifest `installs`:
// templates/assets/team -> assets/team) and injects the matching
// `assets/team/...` entries into the SHELL's pubspec from the manifest's
// `app_assets` list (which this tool regenerates — the same declare-and-
// inject model as tr_keys). The app then resolves plain
// `assets/team/...` keys on any machine, CI runner or device — the app
// used to read them off one developer's absolute factory-checkout path,
// and briefly as `packages/lms_sdk/...` package assets; both are dead.
//
// WHAT SHIPS (the inclusion/exclusion rule, in one place):
//
//   * Nothing under the roots in `_excludedRoots` (today: `marketing/`).
//     Marketing renders are print and expo collateral — 10039x23622
//     banner proofs, posters, flyers, screen loops — produced for the
//     print shop and the stand, never read by the app. The rule below
//     used to vendor them (144.5 MB into every shell's `assets/team/`,
//     which then failed supacharge's clean-head gate), so the exclusion
//     is checked before anything else.
//   * Everything under any `renders/` directory, at any depth, EXCEPT
//     `.json` and `.md` files. A `renders/` folder is by definition the
//     pipeline's finished output (tutor/assistant appearance renders,
//     founder portraits, onboarding slide renders, whatever is added next)
//     — every size and filename ships, nothing is hardcoded. The
//     `.json`/`.md` files that sit alongside them (`manifest.json`, notes)
//     are pipeline metadata, not app content.
//   * Audio files (`.mp3`, `.wav`, `.m4a`, `.ogg`) ANYWHERE under
//     `lms/team/`, when they appear (none exist yet — greetings/signoffs
//     are text today).
//   * Video files (`.mp4`, `.mov`, `.webm`) ANYWHERE under `lms/team/`,
//     when they appear — the first consumer is the founder card's
//     "Hear more" self-intro video
//     (`founders/<Name>/appearance/intro.mp4`).
//   * Nothing else. Scripts, prompts, briefs, `tutor.md` bios, JSON
//     manifests and source portraits (the raw generator output sitting
//     OUTSIDE `renders/`, e.g. `appearance/Gemini_Generated_Image_*.png`)
//     are working material for the rendering pipeline, not consumables.
//
// The sync PRUNES: any file under `templates/assets/team/` that the rule
// above no longer selects from the team folder is deleted, so a rename or
// reorg in `lms/team` cannot ship a stale copy. It also regenerates the
// `app_assets` list in manifest.json (Flutter needs each directory listed
// explicitly — globs and recursion are not supported), so a new persona
// or slide deck needs no manual manifest or pubspec edit anywhere.
//
// THE NEXT.JS HALF (Ray, 2026-09-08: "if in dart assets are in lms, they
// should also be in lms in nextjs"): the SAME consumable set is vendored a
// second time into `lms/nextjs/templates/public/team/` (manifest
// `installs`: templates/public/team -> public/team, so the composed shell
// serves them at `/team/...`), and a generated TypeScript manifest,
// `lms/nextjs/templates/components/custom/landing/team-assets.ts`, lists
// every shipped file per persona (`tutors/CAPS/tutor_001` -> its renders)
// so the landing's tutor cards resolve their portraits without a hardcoded
// path. Both trees are pruned the same way. No resizing: the web serves
// the renders tutor_images.py already produced (webp, a few hundred KB
// each) as-is. The Next.js target is skipped, with a note, when the
// checkout has no `lms/nextjs/` beside `lms/dart/`.
//
// The copies under templates/assets/ (and the Next.js public/team/ tree)
// are committed (the team folder stays the source of truth; git stores
// identical blobs once, so the duplication is free in history). CI runs
// this automatically on pushes touching `lms/team/**`
// (.github/workflows/sync_team_assets.yml); to run it by hand after
// regenerating assets:
//
//   cd lms/dart
//   dart run tool/sync_team_assets.dart
//
// Exit 0 = templates/assets/ + manifest (+ the Next.js copies and
// team-assets.ts) refreshed; exit 1 = a roster persona is missing a render
// demo mode depends on (fix the source rather than shipping a broken
// bundle).
import 'dart:convert';
import 'dart:io';

/// Audio and video ship from anywhere under lms/team the moment they
/// appear (video: the founder card's self-intro).
const _audioExts = {'.mp3', '.wav', '.m4a', '.ogg'};
const _videoExts = {'.mp4', '.mov', '.webm'};

/// Under a renders/ directory everything ships EXCEPT these — manifests
/// and notes are pipeline metadata, not app content.
const _renderMetadataExts = {'.json', '.md'};

/// Top-level lms/team folders whose contents NEVER ship, whatever the
/// rules below would otherwise select. `marketing/` holds print and expo
/// collateral (banner proofs, posters, flyers, screen loops) plus social
/// briefs — collateral for humans, not assets the app resolves. Persona
/// folders (tutors, assistants, founders, onboarding) are not listed here
/// on purpose: their renders are app content.
const _excludedRoots = {'marketing'};

/// Demo mode hard-requires these two files per roster persona
/// (seeded_tutor_catalog.dart builds their asset keys directly), so their
/// absence is an error, not a skip.
const _requiredPersonaRenders = ['avatar_512.webp', 'card_1080x1440.webp'];

/// Deliberately EXCLUDES `founders` — founder renders are optional (the
/// card falls back to initials until a portrait is uploaded), so their
/// absence must not fail the sync. Their `renders/` and `.mp4` intro
/// still ship via the inclusion rule the moment they exist.
const _personaRosters = ['tutors/CAPS', 'assistants/CAPS'];

/// The inclusion rule. [relPath] is `/`-separated, relative to lms/team.
bool _isConsumable(String relPath) {
  final segments = relPath.split('/');
  if (_excludedRoots.contains(segments.first)) return false;
  final name = segments.last;
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot).toLowerCase();
  if (segments.sublist(0, segments.length - 1).contains('renders')) {
    return !_renderMetadataExts.contains(ext);
  }
  return _audioExts.contains(ext) || _videoExts.contains(ext);
}

void main() {
  // Anchor on the package dir so the tool works from any cwd.
  final packageRoot = File(Platform.script.toFilePath()).parent.parent.path;
  final teamRoot = Directory('$packageRoot/../team');
  if (!teamRoot.existsSync()) {
    stderr.writeln('Team folder not found at ${teamRoot.path} - '
        'run from a full agent-repo checkout.');
    exit(1);
  }
  final assetsRoot = Directory('$packageRoot/templates/assets/team');

  String relTo(String root, String path) =>
      path.substring(root.length + 1).replaceAll('\\', '/');

  // 1. Discover every consumable in the team folder.
  final consumables = teamRoot
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .map((f) => relTo(teamRoot.path, f.path))
      .where(_isConsumable)
      .toList()
    ..sort();

  // 2 + 3. Copy (skipping byte-identical files so a re-run is a no-op) and
  // prune anything in templates/assets/team the rule no longer selects.
  final dartSync = _syncTree(teamRoot, consumables, assetsRoot);

  // 4. Guard: demo mode's per-persona renders must all exist.
  var missing = 0;
  for (final roster in _personaRosters) {
    final rosterDir = Directory('${teamRoot.path}/$roster');
    if (!rosterDir.existsSync()) continue;
    final personas = rosterDir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final personaDir in personas) {
      final persona = relTo(rosterDir.path, personaDir.path);
      for (final file in _requiredPersonaRenders) {
        if (!consumables
            .contains('$roster/$persona/appearance/renders/$file')) {
          stderr.writeln(
              'Missing render: $roster/$persona appearance/renders/$file');
          missing++;
        }
      }
    }
  }

  // 5. Regenerate manifest.json's `app_assets` list — the SDK installer
  // injects these entries into the APP SHELL's pubspec. Flutter wants each
  // DIRECTORY listed (a directory entry covers its immediate files only),
  // so list the parent dir of every synced file.
  //
  // This tool owns ONLY the `assets/team/...` entries. Every other entry
  // (splash/login imagery, the demo lesson bundle, whatever a later
  // manifest declares) is hand-authored and must survive a re-sync — an
  // earlier version replaced the whole list and would silently delete
  // them on the next CI run.
  final assetDirs = consumables
      .map((rel) => rel.substring(0, rel.lastIndexOf('/')))
      .toSet()
      .toList()
    ..sort();
  final manifestFile = File('$packageRoot/manifest.json');
  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final existing = (manifest['app_assets'] as List?)?.cast<String>() ?? const [];
  final foreign =
      existing.where((e) => !e.startsWith('assets/team/')).toList();
  manifest['app_assets'] = [
    ...foreign,
    for (final d in assetDirs) 'assets/team/$d/',
  ];
  final newContent =
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';
  final manifestChanged = manifestFile.readAsStringSync() != newContent;
  if (manifestChanged) manifestFile.writeAsStringSync(newContent);

  stdout.writeln(
      'Synced ${consumables.length} asset(s) into templates/assets/team/: '
      '${dartSync.copied} copied, ${dartSync.unchanged} unchanged, '
      '${dartSync.pruned} pruned. '
      'manifest app_assets ${manifestChanged ? 'rewritten' : 'unchanged'} '
      '(${assetDirs.length} dirs).');

  // 6. The Next.js half: the same files under lms/nextjs/templates/public/
  // team/ plus the generated team-assets.ts manifest the landing's cards
  // read. Skipped (not failed) when this checkout carries no nextjs half.
  final nextjsRoot = Directory('$packageRoot/../nextjs');
  if (nextjsRoot.existsSync()) {
    final publicRoot = Directory('${nextjsRoot.path}/templates/public/team');
    final webSync = _syncTree(teamRoot, consumables, publicRoot);
    final tsFile = File('${nextjsRoot.path}/templates/components/custom/'
        'landing/team-assets.ts');
    final tsContent = _teamAssetsTs(consumables);
    final tsChanged =
        !tsFile.existsSync() || tsFile.readAsStringSync() != tsContent;
    if (tsChanged) {
      tsFile.parent.createSync(recursive: true);
      tsFile.writeAsStringSync(tsContent);
    }
    stdout.writeln(
        'Synced ${consumables.length} asset(s) into '
        '../nextjs/templates/public/team/: ${webSync.copied} copied, '
        '${webSync.unchanged} unchanged, ${webSync.pruned} pruned. '
        'team-assets.ts ${tsChanged ? 'rewritten' : 'unchanged'}.');
  } else {
    stdout.writeln('No lms/nextjs beside lms/dart - Next.js target skipped.');
  }
  if (missing > 0) {
    stderr.writeln('$missing required render(s) missing from the team '
        'folder.');
    exit(1);
  }
}

/// What one target tree's sync did.
class _SyncResult {
  final int copied, unchanged, pruned;
  const _SyncResult(this.copied, this.unchanged, this.pruned);
}

/// Mirrors [consumables] (paths relative to [teamRoot]) into [destRoot]:
/// copies what changed, skips byte-identical files so a re-run is a no-op,
/// and deletes every file under [destRoot] the rule no longer selects (a
/// rename or reorg in lms/team cannot ship a stale copy). Shared by the
/// Dart templates/assets/team tree and the Next.js templates/public/team
/// tree so the two can never drift apart.
_SyncResult _syncTree(
    Directory teamRoot, List<String> consumables, Directory destRoot) {
  String relTo(String root, String path) =>
      path.substring(root.length + 1).replaceAll('\\', '/');
  var copied = 0, unchanged = 0, pruned = 0;
  for (final rel in consumables) {
    final src = File('${teamRoot.path}/$rel');
    final dest = File('${destRoot.path}/$rel');
    if (dest.existsSync() &&
        dest.lengthSync() == src.lengthSync() &&
        _sameBytes(src, dest)) {
      unchanged++;
      continue;
    }
    dest.parent.createSync(recursive: true);
    src.copySync(dest.path);
    copied++;
  }
  if (destRoot.existsSync()) {
    final wanted = consumables.toSet();
    final stale = destRoot
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => !wanted.contains(relTo(destRoot.path, f.path)))
        .toList();
    for (final f in stale) {
      f.deleteSync();
      pruned++;
    }
    _deleteEmptyDirs(destRoot);
  }
  return _SyncResult(copied, unchanged, pruned);
}

/// The persona a shipped file belongs to: its directory with the pipeline's
/// trailing `appearance/renders` (or `renders`, or `appearance`) segments
/// removed, so `tutors/CAPS/tutor_001/appearance/renders/avatar_512.webp`
/// files under `tutors/CAPS/tutor_001` and
/// `onboarding/students/renders/slide_01.webp` under `onboarding/students`.
String _personaKey(String rel) {
  final segments = rel.split('/')..removeLast();
  while (segments.isNotEmpty &&
      (segments.last == 'renders' || segments.last == 'appearance')) {
    segments.removeLast();
  }
  return segments.join('/');
}

/// The generated `team-assets.ts`: every shipped file, grouped by persona,
/// as the `/team/...` URL the composed shell serves it at. Deterministic
/// (sorted input, fixed formatting) so a re-run on an unchanged team folder
/// writes byte-identical output and the clean-head gate sees no drift.
String _teamAssetsTs(List<String> consumables) {
  final byPersona = <String, List<String>>{};
  for (final rel in consumables) {
    byPersona.putIfAbsent(_personaKey(rel), () => []).add('/team/$rel');
  }
  final keys = byPersona.keys.toList()..sort();
  final b = StringBuffer()
    ..writeln('/*')
    ..writeln(' * Copyright (c) 2026 ROKCT INTELLIGENCE (PTY) LTD')
    ..writeln(' *')
    ..writeln(' * This program is free software: you can redistribute it and/or modify')
    ..writeln(' * it under the terms of the GNU Affero General Public License as published')
    ..writeln(' * by the Free Software Foundation, version 3.')
    ..writeln(' *')
    ..writeln(' * This program is distributed in the hope that it will be useful,')
    ..writeln(' * but WITHOUT ANY WARRANTY; without even the implied warranty of')
    ..writeln(' * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the')
    ..writeln(' * GNU Affero General Public License for more details.')
    ..writeln(' *')
    ..writeln(' * You should have received a copy of the GNU Affero General Public License')
    ..writeln(' * along with this program. If not, see <https://www.gnu.org/licenses/>.')
    ..writeln(' */')
    ..writeln()
    ..writeln('// GENERATED by lms/dart/tool/sync_team_assets.dart - do not edit.')
    ..writeln('// The team assets the SDK ships into the shell\'s public/team/ (the')
    ..writeln('// same consumable set the Dart half vendors into assets/team/: tutor,')
    ..writeln('// assistant, founder and onboarding renders plus any audio/video; never')
    ..writeln('// marketing collateral), grouped by persona and listed as the URL the')
    ..writeln('// composed shell serves each file at. Regenerated on every lms/team/**')
    ..writeln('// push by .github/workflows/sync_team_assets.yml.')
    ..writeln()
    ..writeln('/** Persona folder (relative to lms/team, e.g. `tutors/CAPS/tutor_001`) -> the files it ships. */')
    ..writeln('export const TEAM_ASSETS: Readonly<Record<string, readonly string[]>> = {');
  for (final key in keys) {
    b.writeln('  "$key": [');
    for (final url in byPersona[key]!) {
      b.writeln('    "$url",');
    }
    b.writeln('  ],');
  }
  b
    ..writeln('};')
    ..writeln()
    ..writeln('/** Every file a persona ships, by its folder key or by its last path segment (`tutor_001`). */')
    ..writeln('export function teamAssetsFor(slug: string): readonly string[] {')
    ..writeln('  const direct = TEAM_ASSETS[slug];')
    ..writeln('  if (direct) return direct;')
    ..writeln('  const key = Object.keys(TEAM_ASSETS).find((k) => k.endsWith(`/\${slug}`));')
    ..writeln('  return key ? TEAM_ASSETS[key] : [];')
    ..writeln('}')
    ..writeln()
    ..writeln('/**')
    ..writeln(' * The image a card should show for a persona: the named rendition when it')
    ..writeln(' * ships (`card_1080x1440.webp` is the 3:4 portrait TutorCard draws full-bleed),')
    ..writeln(' * else the first image the persona has, else undefined (the card falls')
    ..writeln(' * back to initials, as the Flutter card does).')
    ..writeln(' */')
    ..writeln('export function teamImageFor(')
    ..writeln('  slug: string,')
    ..writeln('  preferred = "card_1080x1440.webp",')
    ..writeln('): string | undefined {')
    ..writeln('  const files = teamAssetsFor(slug);')
    ..writeln('  return (')
    ..writeln('    files.find((f) => f.endsWith(`/\${preferred}`)) ??')
    ..writeln('    files.find((f) => /\\.(webp|png|jpe?g|avif|gif)\$/i.test(f))')
    ..writeln('  );')
    ..writeln('}');
  return b.toString();
}

bool _sameBytes(File a, File b) {
  final ab = a.readAsBytesSync(), bb = b.readAsBytesSync();
  if (ab.length != bb.length) return false;
  for (var i = 0; i < ab.length; i++) {
    if (ab[i] != bb[i]) return false;
  }
  return true;
}

void _deleteEmptyDirs(Directory root) {
  final dirs = root
      .listSync(recursive: true, followLinks: false)
      .whereType<Directory>()
      .toList()
    ..sort((a, b) => b.path.length.compareTo(a.path.length));
  for (final d in dirs) {
    if (d.listSync().isEmpty) d.deleteSync();
  }
}
