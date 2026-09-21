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


// Decision #45: an airing carries its context — normal live session,
// holiday programme, or revision airing. The flag lives on the airing
// (the schedule entry), never the lesson, and anything unknown reads as a
// normal live airing.
import 'package:flutter_test/flutter_test.dart';
// The models file directly rather than the lms_sdk barrel: standalone (no
// host app) the barrel drags in presentation pages whose TrKeys members only
// resolve inside a composed app, and this suite must run standalone.
import 'package:lms_sdk/src/common/domain/models/session_schedule_models.dart';

void main() {
  group('AiringContext.parse', () {
    test('parses the three wire values', () {
      expect(AiringContext.parse('live'), AiringContext.live);
      expect(AiringContext.parse('holiday'), AiringContext.holiday);
      expect(AiringContext.parse('revision'), AiringContext.revision);
    });

    test('null, empty and unknown values fall back to live', () {
      expect(AiringContext.parse(null), AiringContext.live);
      expect(AiringContext.parse(''), AiringContext.live);
      expect(AiringContext.parse('HOLIDAY'), AiringContext.live);
      expect(AiringContext.parse('exam-prep'), AiringContext.live);
    });
  });

  group('ScheduledSession.airingContext', () {
    ScheduledSession session({AiringContext? context}) => ScheduledSession(
          sessionId: 's1',
          subject: 'Maths',
          topic: 'Quadratic equations',
          tutorName: 'Grandmaster',
          startTime: DateTime(2026, 7, 20, 15, 0),
          airingContext: context ?? AiringContext.live,
        );

    test('defaults to live when not provided', () {
      final s = ScheduledSession(
        sessionId: 's1',
        subject: 'Maths',
        topic: 'Quadratic equations',
        tutorName: 'Grandmaster',
        startTime: DateTime(2026, 7, 20, 15, 0),
      );
      expect(s.airingContext, AiringContext.live);
    });

    test('carries a non-default context', () {
      expect(session(context: AiringContext.holiday).airingContext,
          AiringContext.holiday);
    });

    test('copyWith preserves the airing context', () {
      final s = session(context: AiringContext.revision)
          .copyWith(crossTutorNote: 'note');
      expect(s.airingContext, AiringContext.revision);
    });
  });
}
