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

// Gates factory-exported animations.json files against the primitive-type
// vocabulary the whiteboard painter actually implements
// (lib/src/common/controllers/whiteboard_primitive_types.dart — the single
// source of truth the player itself uses). Unknown types render as marker
// dots at runtime; this validator turns them into a build failure instead.
// Pure-Dart import graph, so it runs under `dart run` without Flutter —
// same posture as replay/dart/tool/validate_manifest.dart.
//
//   dart run tool/validate_animations.dart <animations.json> [more.json ...]
//
// Exits 0 and prints a per-file summary on success; exits 1 when any file
// contains a primitive type outside the supported set; exits 2 on usage or
// unreadable/unparseable input.
import 'dart:convert';
import 'dart:io';

import '../lib/src/common/controllers/whiteboard_primitive_types.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
        'usage: validate_animations.dart <animations.json> [more.json ...]');
    exit(2);
  }

  var failed = false;
  for (final path in args) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('no such file: $path');
      exit(2);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      stderr.writeln('$path: not valid JSON: ${e.message}');
      exit(2);
    }
    final primitives = decoded is Map<String, dynamic>
        ? (decoded['primitives'] as List? ?? const [])
        : const [];
    if (primitives.isEmpty) {
      stderr.writeln('$path: no primitives array — nothing to validate');
      exit(2);
    }

    final problems = <String>[];
    for (var i = 0; i < primitives.length; i++) {
      final entry = primitives[i];
      if (entry is! Map) {
        problems.add('index $i: not an object');
        continue;
      }
      final type = entry['primitive'];
      if (type is! String || type.isEmpty) {
        problems.add('index $i: missing/empty "primitive" field');
      } else if (!kSupportedPrimitiveTypes.contains(type)) {
        final time = entry['time'] ?? '?';
        problems.add('index $i (t=$time): unsupported primitive type '
            '"$type" — the painter renders it as a marker dot');
      }
    }

    if (problems.isEmpty) {
      print('OK $path: ${primitives.length} primitives, all types supported '
          '(${kSupportedPrimitiveTypes.toList()..sort()})');
    } else {
      failed = true;
      stderr.writeln('UNSUPPORTED PRIMITIVES in $path:');
      for (final p in problems) {
        stderr.writeln('  - $p');
      }
    }
  }

  if (failed) {
    stderr.writeln('\nSupported set (single source of truth: '
        'lib/src/common/controllers/whiteboard_primitive_types.dart): '
        '${kSupportedPrimitiveTypes.toList()..sort()}');
    exit(1);
  }
}
