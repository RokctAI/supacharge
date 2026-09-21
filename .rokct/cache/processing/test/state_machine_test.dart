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
import 'package:processing_sdk/processing_sdk.dart';

void main() {
  group('ProcessingStateMachine', () {
    test('allows documented transitions', () {
      expect(
        ProcessingStateMachine.canTransition(
          ProcessingState.draft,
          ProcessingState.submitted,
        ),
        isTrue,
      );
      expect(
        ProcessingStateMachine.canTransition(
          ProcessingState.submitted,
          ProcessingState.accepted,
        ),
        isTrue,
      );
    });

    test('rejects undeclared transitions', () {
      expect(
        ProcessingStateMachine.canTransition(
          ProcessingState.draft,
          ProcessingState.completed,
        ),
        isFalse,
      );
      expect(
        ProcessingStateMachine.canTransition(
          ProcessingState.completed,
          ProcessingState.draft,
        ),
        isFalse,
      );
    });

    test('terminal states have no exits', () {
      expect(ProcessingStateMachine.isTerminal(ProcessingState.completed),
          isTrue);
      expect(ProcessingStateMachine.isTerminal(ProcessingState.cancelled),
          isTrue);
      expect(
          ProcessingStateMachine.isTerminal(ProcessingState.failed), isFalse);
    });
  });
}
