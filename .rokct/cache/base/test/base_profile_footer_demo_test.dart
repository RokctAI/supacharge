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

// The profile footer's Online/Offline dot is backed by a real api_status
// probe of the tenant backend. Wherever DemoSession.demoActive is true the
// app is served from the in-app fixtures and there is no backend to probe
// - the guided-tour build has none at all, and a demo session is answered
// from the same fixtures - so the probe could only ever fail and the dot
// drew a red Offline, captured verbatim by the guided tour's profile. The
// dot must read as connected there without probing; a real session must
// still ask the backend, and with no backend answering (this test has no
// connectivity plugin and no server) still report Offline. The row follows
// the switch while it is on screen - sign-out happens from the profile, so
// the dot must fall back to the real probe on the flip.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/application/profile/profile_host_capabilities.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_host_scope.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/base_profile_footer.dart';
import 'package:base_sdk/src/services/demo_session.dart';
import 'package:base_sdk/src/services/local_storage.dart';

/// Pumps the meta row under the anonymous host scope (no account facade),
/// so the usage badge - which needs a signed-in user and an HttpService -
/// stays out of the row and only the dot is under test.
Widget _host(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(800, 600),
    builder: (context, _) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: ProfileHostScope(
            capabilities: const ProfileHostCapabilities(
              hasAccount: false,
              hasShops: false,
              hasGallery: false,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  tearDown(() async {
    // The session is app-global; never let one test leak into the next.
    await DemoSession.instance.clear();
  });

  group('ProfileMetaRow Online/Offline dot', () {
    testWidgets('a demo session reads as Online without a backend',
        (tester) async {
      // The only demo switch there is: no build flag stands in for it.
      await DemoSession.instance.activate();

      await tester.pumpWidget(_host(const ProfileMetaRow()));
      await tester.pumpAndSettle();

      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
    });

    testWidgets('a real build with no backend answering still reads Offline',
        (tester) async {
      // Session off, and this is no tour build: the dot must probe.
      expect(DemoSession.demoActive, isFalse);

      await tester.pumpWidget(_host(const ProfileMetaRow()));
      await tester.pumpAndSettle();

      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Online'), findsNothing);
    });

    testWidgets('the row follows the session while it is on screen',
        (tester) async {
      await tester.pumpWidget(_host(const ProfileMetaRow()));
      await tester.pump();
      // Session off, no backend answering: never a session-granted Online.
      expect(find.text('Online'), findsNothing);

      await DemoSession.instance.activate();
      await tester.pump();
      await tester.pump();
      expect(find.text('Online'), findsOneWidget);

      // Sign-out ends the session with the profile still up: the dot
      // drops the session's answer and goes back to the real probe.
      await DemoSession.instance.clear();
      await tester.pump();
      await tester.pump();
      expect(find.text('Online'), findsNothing);
    });
  });
}
