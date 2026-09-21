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

// THE PUBLIC SURFACE MUST COMPILE ON ITS OWN TERMS.
//
// This package ships as SOURCE and is compiled by its host: the composer
// copies lib/ into the app's `.rokct/cache/productivity` and the app's own
// front-end run is the first thing that ever compiles it. A library here
// that names a type it never imported is therefore not local untidiness, it
// is a broken host build - and it stays invisible for exactly as long as
// nothing reachable from `lib/productivity_sdk.dart` imports that library.
//
// That is how 1.6.1-1.6.3 broke every app composing this SDK.
// `application/tasks/{tasks_provider,tasks_notifier,tasks_state}.dart` had
// named `TaskModel` and `ProcessingState` without importing either since the
// src/ reshuffle, and nobody noticed, because nothing on the public surface
// reached them: they were an island the front end never walked into. The
// needs-attention glance then imported the island (it watches
// `tasksStateProvider`), the barrel exports the glance, and the next host
// build stopped with three "Type not found." errors in files nobody had
// touched in months.
//
// This test walks the SAME graph the front end walks - every library
// transitively reachable from the barrel through `import` and `export` - and
// asserts each one can actually see every type it names. It works on SOURCE
// rather than by importing the barrel: a test that imported
// `productivity_sdk.dart` could only ever run inside a host that had already
// generated this package's drift code, i.e. never in this repo's own suite
// (that is what the composed-only load failures in this suite are), which is
// the other half of why the defect shipped.
//
// What it pins, precisely:
//   * an island stops being invisible - the moment anything on the public
//     surface imports a library, that library's names are audited;
//   * a type this package declares must be imported by every library of this
//     package that names it, never borrowed from whoever imported it;
//   * a type base_sdk declares (`ProcessingState`, `ApiResult`, `PlaneSpan`
//     ...) must be reached by a `package:base_sdk/...` directive in the
//     library that names it - this package's barrel does not re-export
//     base_sdk, so reaching base_sdk through it never worked.
//
// It deliberately models Dart's own rule rather than an approximation of it:
// an `import` puts the target's own declarations and the target's `export`
// closure in scope, and NOTHING that the target merely imports.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String kPackage = 'productivity_sdk';
const String kBasePackage = 'base_sdk';

/// Key prefixes for the two packages this audit resolves. Everything else
/// (dart:, flutter, drift, riverpod ...) is out of the universe and out of
/// the walk.
const String kHerePrefix = 'lib/';
const String kBasePrefix = '$kBasePackage:';

void main() {
  group('the public surface compiles on its own terms', () {
    late final _Audit audit = _Audit.build();

    test('the barrel graph this audit walks is the real one', () {
      // Without these, a silently empty walk would make the real assertion
      // below pass for the wrong reason.
      expect(audit.reachable, contains('lib/$kPackage.dart'));
      expect(
        audit.reachable.length,
        greaterThan(40),
        reason: 'the barrel reached only ${audit.reachable.length} libraries; '
            'that is a broken walk, not a small public surface',
      );
      expect(
        audit.declaredHere.length,
        greaterThan(100),
        reason: 'only ${audit.declaredHere.length} type declarations found '
            'under lib/ - the declaration scan is broken',
      );
      expect(
        audit.declaredInBase.length,
        greaterThan(100),
        reason: 'only ${audit.declaredInBase.length} type declarations found '
            'in $kBasePackage - it was not resolved through '
            '.dart_tool/package_config.json',
      );
      // The island that broke the launcher is on the surface now. If it ever
      // leaves it again, this audit must say so rather than quietly stop
      // covering it.
      expect(
        audit.reachable,
        containsAll(<String>[
          'lib/src/common/application/tasks/tasks_state.dart',
          'lib/src/common/application/tasks/tasks_notifier.dart',
          'lib/src/common/application/tasks/tasks_provider.dart',
        ]),
      );
    });

    test('no library on the public surface names a type it cannot see', () {
      final List<String> problems = audit.unresolved();
      expect(
        problems,
        isEmpty,
        reason: 'These libraries are reachable from '
            'package:$kPackage/$kPackage.dart and name a type that no '
            'directive of theirs provides. A host build composing this SDK '
            'stops on each one with "Type \'<name>\' not found.":\n'
            '${problems.join('\n')}',
      );
    });
  });
}

class _Directive {
  const _Directive(this.uri, {required this.isExport});
  final String uri;
  final bool isExport;
}

/// One library: what it declares, what its directives reach, and every
/// identifier its code mentions.
class _Library {
  _Library(this.key);

  /// `lib/<path>` for this package, `base_sdk:<path>` for base_sdk.
  final String key;

  final Set<String> declares = <String>{};
  final Set<String> imports = <String>{};
  final Set<String> exports = <String>{};
  final Set<String> parts = <String>{};
  final Set<String> mentions = <String>{};
}

class _Audit {
  _Audit({
    required this.libraries,
    required this.reachable,
    required this.declaredHere,
    required this.declaredInBase,
  });

  final Map<String, _Library> libraries;

  /// Libraries of THIS package reachable from its barrel. base_sdk is walked
  /// for visibility but never audited: its surface is not this package's to
  /// answer for.
  final Set<String> reachable;

  final Set<String> declaredHere;
  final Set<String> declaredInBase;

  static _Audit build() {
    final Directory libDir = Directory('lib');
    if (!libDir.existsSync()) {
      throw StateError('run this test from the package root; cwd is '
          '${Directory.current.path}');
    }

    final Map<String, _Library> libraries = <String, _Library>{};
    final Set<String> declaredHere =
        _scan(libDir, kHerePrefix, libraries);

    // base_sdk resolved the way the front end resolves it: through the
    // package config `pub get` wrote. That is the core checkout in this repo
    // and `.rokct/cache/base` in a composed host, with no branch for either.
    final Directory baseLib = _baseLibDir();
    final Set<String> declaredInBase =
        _scan(baseLib, kBasePrefix, libraries);

    // A part's declarations belong to its parent library.
    for (final _Library lib in libraries.values) {
      for (final String part in lib.parts) {
        lib.declares.addAll(libraries[part]?.declares ?? const <String>{});
      }
    }

    final Set<String> reachable = <String>{};
    final List<String> queue = <String>['lib/$kPackage.dart'];
    while (queue.isNotEmpty) {
      final String key = queue.removeLast();
      if (!key.startsWith(kHerePrefix)) continue;
      if (!reachable.add(key)) continue;
      final _Library? lib = libraries[key];
      if (lib == null) continue;
      queue
        ..addAll(lib.imports)
        ..addAll(lib.exports);
    }

    return _Audit(
      libraries: libraries,
      reachable: reachable,
      declaredHere: declaredHere,
      declaredInBase: declaredInBase,
    );
  }

  /// Every reachable library that names a type no directive of it provides,
  /// one line per library.
  List<String> unresolved() {
    final Set<String> universe = <String>{...declaredHere, ...declaredInBase};
    final List<String> problems = <String>[];
    for (final String key in reachable.toList()..sort()) {
      final _Library? lib = libraries[key];
      if (lib == null) continue;
      final Set<String> visible = _visible(lib);
      final List<String> missing = <String>[
        for (final String name in lib.mentions)
          if (universe.contains(name) && !visible.contains(name)) name,
      ]..sort();
      if (missing.isNotEmpty) problems.add('  $key: ${missing.join(', ')}');
    }
    return problems;
  }

  /// What is in scope inside [lib]: its own declarations plus, for each of
  /// its directives, that target's declarations and the transitive closure of
  /// the target's `export`s - and nothing the target merely imports, which is
  /// the rule this package broke.
  Set<String> _visible(_Library lib) {
    final Set<String> names = <String>{...lib.declares};
    final Set<String> seen = <String>{};
    final List<String> queue = <String>[...lib.imports, ...lib.exports];
    while (queue.isNotEmpty) {
      final String key = queue.removeLast();
      if (!seen.add(key)) continue;
      final _Library? target = libraries[key];
      if (target == null) continue;
      names.addAll(target.declares);
      queue.addAll(target.exports);
    }
    return names;
  }
}

/// Read every library under [dir] into [into] under [prefix], and answer the
/// type names they declare.
Set<String> _scan(
  Directory dir,
  String prefix,
  Map<String, _Library> into,
) {
  final String root = _trimSlash(_norm(dir.absolute.path));
  final Set<String> declared = <String>{};
  for (final File file in dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))) {
    final String key =
        '$prefix${_norm(file.absolute.path).substring(root.length + 1)}';
    final _Library lib = _Library(key);
    final String raw = file.readAsStringSync();
    final String code = _strip(raw);
    lib.declares.addAll(_declarations(code));
    lib.mentions.addAll(_identifiers(code));
    declared.addAll(lib.declares);
    for (final _Directive d in _directives(raw)) {
      final String? target = _resolve(d.uri, key);
      if (target == null) continue;
      (d.isExport ? lib.exports : lib.imports).add(target);
    }
    for (final RegExpMatch m in _partRe.allMatches(raw)) {
      final String? target = _resolve(m.group(1)!, key);
      if (target != null) lib.parts.add(target);
    }
    into[key] = lib;
  }
  return declared;
}

/// The key a URI names, or null for a `dart:` URI or a package this audit
/// does not resolve.
String? _resolve(String uri, String fromKey) {
  const String self = 'package:$kPackage/';
  const String base = 'package:$kBasePackage/';
  if (uri.startsWith(self)) return '$kHerePrefix${uri.substring(self.length)}';
  if (uri.startsWith(base)) return '$kBasePrefix${uri.substring(base.length)}';
  if (uri.startsWith('dart:') || uri.startsWith('package:')) return null;
  // Relative, so it stays inside whichever package fromKey belongs to.
  final int split = fromKey.startsWith(kBasePrefix) ? kBasePrefix.length : 0;
  final String prefix = fromKey.substring(0, split);
  final List<String> parts = fromKey.substring(split).split('/')..removeLast();
  for (final String segment in uri.split('/')) {
    if (segment == '.' || segment.isEmpty) continue;
    if (segment == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(segment);
  }
  return '$prefix${parts.join('/')}';
}

/// base_sdk's `lib/`, read out of the package config `pub get` wrote - the
/// same file the front end resolves `package:base_sdk/...` through.
Directory _baseLibDir() {
  final File config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) {
    throw StateError('.dart_tool/package_config.json is missing - run '
        '`flutter pub get` before this suite');
  }
  final Map<String, dynamic> decoded =
      jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  for (final dynamic entry in decoded['packages'] as List<dynamic>) {
    final Map<String, dynamic> package = entry as Map<String, dynamic>;
    if (package['name'] != kBasePackage) continue;
    // A rootUri with no trailing slash resolves as a FILE, which would send
    // packageUri one directory too high; both are normalised to directories.
    final Uri root = config.absolute.parent.uri
        .resolve(_asDir(package['rootUri'] as String));
    final Directory dir =
        Directory.fromUri(root.resolve(_asDir(package['packageUri'] as String)));
    if (dir.existsSync()) return dir;
    throw StateError('$kBasePackage resolves to ${dir.path}, which does not '
        'exist - run `flutter pub get`');
  }
  throw StateError('$kBasePackage is not in .dart_tool/package_config.json');
}

String _asDir(String value) => value.endsWith('/') ? value : '$value/';

String _norm(String path) => path.replaceAll(r'\', '/');

String _trimSlash(String path) {
  String out = path;
  while (out.length > 1 && out.endsWith('/')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

/// Comments and string literals removed, so a type named in prose or inside
/// an error message is never mistaken for a type the code names. Line
/// structure is not preserved and does not need to be.
String _strip(String source) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  while (i < source.length) {
    final String c = source[i];
    final String next = i + 1 < source.length ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      int depth = 1;
      i += 2;
      while (i < source.length && depth > 0) {
        if (source.startsWith('/*', i)) {
          depth++;
          i += 2;
        } else if (source.startsWith('*/', i)) {
          depth--;
          i += 2;
        } else {
          i++;
        }
      }
      continue;
    }
    if (c == "'" || c == '"') {
      final String close = source.startsWith(c * 3, i) ? c * 3 : c;
      i += close.length;
      while (i < source.length) {
        if (source[i] == r'\') {
          i += 2;
          continue;
        }
        if (source.startsWith(close, i)) {
          i += close.length;
          break;
        }
        i++;
      }
      out.write(' ');
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

final RegExp _declRe = RegExp(
  r'(?:^|[\n;}])\s*(?:(?:abstract|base|final|sealed|interface|mixin)\s+)*'
  r'(?:class|enum|mixin|extension\s+type|extension|typedef)\s+'
  r'([A-Z_$][A-Za-z0-9_$]*)',
);

Set<String> _declarations(String code) => <String>{
      for (final RegExpMatch m in _declRe.allMatches(code)) m.group(1)!,
    };

final RegExp _identifierRe = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');

Set<String> _identifiers(String code) => <String>{
      for (final RegExpMatch m in _identifierRe.allMatches(code)) m.group(0)!,
    };

/// Directives are read off the RAW source: a directive's URI is a string
/// literal, and [_strip] eats those by design.
final RegExp _directiveRe =
    RegExp('''^\\s*(import|export)\\s+['"]([^'"]+)['"]''', multiLine: true);

final RegExp _partRe =
    RegExp('''^\\s*part\\s+['"]([^'"]+)['"]''', multiLine: true);

List<_Directive> _directives(String raw) => <_Directive>[
      for (final RegExpMatch m in _directiveRe.allMatches(raw))
        _Directive(m.group(2)!, isExport: m.group(1) == 'export'),
    ];
