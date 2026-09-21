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


// UpcomingSession wire-model parsing, focused on decision #45's
// airing_context: the server is authoritative, so the model tolerates a
// missing/empty value by reading it as a normal live airing.
import 'package:flutter_test/flutter_test.dart';
// The model file directly rather than the replay_sdk barrel: standalone (no
// host app) the barrel drags in controllers whose AppDatabase tables only
// exist once the manifest injects them into a composed app.
import 'package:replay_sdk/src/common/infrastructure/models/response/upcoming_session.dart';

Map<String, dynamic> baseJson() => {
      'session_id': 'sess-1',
      'subject': 'maths',
      'scheduled_at': '2026-08-14T10:00:00',
      'manifest_url': 'https://cdn.example/m.json',
      'audio_url': 'https://cdn.example/a.opus',
      'animation_url': 'https://cdn.example/v.json',
    };

void main() {
  test('airing_context is carried through when present', () {
    final session =
        UpcomingSession.fromJson({...baseJson(), 'airing_context': 'holiday'});
    expect(session.airingContext, 'holiday');
    expect(session.toJson()['airing_context'], 'holiday');
  });

  test('missing or empty airing_context defaults to live', () {
    expect(UpcomingSession.fromJson(baseJson()).airingContext, 'live');
    expect(
      UpcomingSession.fromJson({...baseJson(), 'airing_context': ''})
          .airingContext,
      'live',
    );
    expect(
      UpcomingSession.fromJson({...baseJson(), 'airing_context': null})
          .airingContext,
      'live',
    );
  });
}
