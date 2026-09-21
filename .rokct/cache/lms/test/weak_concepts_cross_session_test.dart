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


import 'package:flutter_test/flutter_test.dart';
// src-path imports (not the lms_sdk barrel) — same pattern as
// office_hours_break_bridge_test: the barrel drags in presentation widgets
// whose composer-injected TrKeys members only exist in a composed host app.
import 'package:lms_sdk/src/common/controllers/weak_concepts.dart';

/// The office-hours weak-concepts upgrade (Users PR #17 endpoint via
/// users_sdk): server cross-session aggregates preferred, the PR #85
/// manifest derivation kept as the fallback, manifest titles winning for
/// display, and every failure silent to the student (diagnostics go to the
/// injected sink — in production the PR #99 telemetry pipe).
void main() {
  const sessionRefs = ['quadratic_formula', 'completing_the_square'];

  Future<Map<String, String>> titles(String sessionId) async => {
        'quadratic_formula': 'The Quadratic Formula',
        'trig_identities': 'Trig Identities',
      };

  CrossSessionWeakConcepts resolver({
    required WeakConceptsFetcher fetch,
    SubtopicTitlesLoader? loadTitles,
    List<List<Object?>>? diagnostics,
  }) =>
      CrossSessionWeakConcepts(
        fetchAggregates: fetch,
        loadSubtopicTitles: loadTitles ?? titles,
        logDiagnostic: (type, sessionId, context) =>
            diagnostics?.add([type, sessionId, context]),
      );

  group('server aggregates preferred', () {
    test(
        'server list drives the names, in server (weakest-first) order; '
        'manifest titles win over server labels; labels cover the rest',
        () async {
      final names = await resolver(
        fetch: () async => const WeakConceptsFetch.success(
          sourceAvailable: true,
          concepts: [
            // In the manifest: its title must win over the server label.
            ServerWeakConcept(ref: 'quadratic_formula', label: 'Quadratic'),
            // Not in the manifest: the server label is used.
            ServerWeakConcept(ref: 'log_laws', label: 'Laws of Logarithms'),
            // Neither title nor label: humanized slug.
            ServerWeakConcept(ref: 'euclidean_geometry_riders'),
          ],
        ),
      ).getWeakConcepts('sess-1', sessionRefs);

      expect(names, [
        'The Quadratic Formula',
        'Laws of Logarithms',
        'euclidean geometry riders',
      ]);
    });

    test('duplicate display names are collapsed', () async {
      final names = await resolver(
        fetch: () async => const WeakConceptsFetch.success(
          sourceAvailable: true,
          concepts: [
            ServerWeakConcept(ref: 'quadratic_formula', label: 'Quadratic'),
            // Different ref resolving to the same visible name.
            ServerWeakConcept(
                ref: 'quad_formula', label: 'The Quadratic Formula'),
          ],
        ),
      ).getWeakConcepts('sess-1', sessionRefs);

      expect(names, ['The Quadratic Formula']);
    });
  });

  group('fallback to this-session manifest derivation', () {
    test('fetch failure falls back and stays silent (diagnostics only)',
        () async {
      final log = <List<Object?>>[];
      final names = await resolver(
        fetch: () async => const WeakConceptsFetch.failure(
            diagnostic: 'HTTP 500 from paas', statusCode: 500),
        diagnostics: log,
      ).getWeakConcepts('sess-1', sessionRefs);

      // Exactly the previous ManifestWeakConcepts behaviour: title when the
      // manifest has one, humanized slug otherwise.
      expect(names, ['The Quadratic Formula', 'completing the square']);
      expect(log.single[0], 'weak_concepts_fetch_failed');
      expect(log.single[1], 'sess-1');
      expect((log.single[2] as Map)['status_code'], '500');
    });

    test('a throwing fetcher is contained, not propagated', () async {
      final log = <List<Object?>>[];
      final names = await resolver(
        fetch: () async => throw StateError('users_sdk not composed'),
        diagnostics: log,
      ).getWeakConcepts('sess-1', sessionRefs);

      expect(names, ['The Quadratic Formula', 'completing the square']);
      expect(log.single[0], 'weak_concepts_fetch_failed');
    });

    test(
        'source_available false is the valid not-composed state: fallback '
        'plus its own distinct diagnostic event', () async {
      final log = <List<Object?>>[];
      final names = await resolver(
        fetch: () async =>
            const WeakConceptsFetch.success(sourceAvailable: false),
        diagnostics: log,
      ).getWeakConcepts('sess-1', sessionRefs);

      expect(names, ['The Quadratic Formula', 'completing the square']);
      expect(log.single[0], 'weak_concepts_source_unavailable');
    });

    test(
        'a successful-but-empty server list still falls back, so upload lag '
        'never drops the misses from the session just played', () async {
      final log = <List<Object?>>[];
      final names = await resolver(
        fetch: () async =>
            const WeakConceptsFetch.success(sourceAvailable: true),
        diagnostics: log,
      ).getWeakConcepts('sess-1', sessionRefs);

      expect(names, ['The Quadratic Formula', 'completing the square']);
      // Not a failure and not source-unavailable: no diagnostic event.
      expect(log, isEmpty);
    });

    test(
        'no server data and no session refs yields the empty list (the '
        'controller then greets with the aced-it branch)', () async {
      final names = await resolver(
        fetch: () async => const WeakConceptsFetch.failure(),
      ).getWeakConcepts('sess-1', const []);
      expect(names, isEmpty);
    });

    test('a throwing titles loader degrades to humanized slugs', () async {
      final names = await resolver(
        fetch: () async => const WeakConceptsFetch.failure(),
        loadTitles: (_) async => throw StateError('no manifest on disk'),
      ).getWeakConcepts('sess-1', sessionRefs);
      expect(names, ['quadratic formula', 'completing the square']);
    });
  });
}
