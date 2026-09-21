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

// NOTIFICATIONS in the standard list language (approved frame 38b, Ray
// 2026-08-30 12:23Z — "the All/Unread tabs are IN"):
//
//   * 707 — the read-state filter is exactly the shipped dot's condition
//     (readAt == null), so Unread shows the dotted rows and nothing else,
//     and each tab reports its own count for its pill;
//   * 704/705 — the row renders the client as "First L.", the body, and
//     the unread dot; a read row loses the dot and dims;
//   * a blog/system item with no client photo gets the tinted glyph
//     instead of an empty avatar.

import 'package:base_sdk/src/models/data/blog_data.dart';
import 'package:base_sdk/src/models/response/notification_response.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:comms_sdk/src/common/presentation/notifications/notification_list_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NotificationModel _notification({
  required String id,
  bool read = false,
  Client? client,
  BlogData? blog,
  String body = 'A new order came in',
}) => NotificationModel(
  id: id,
  body: body,
  client: client,
  blogData: blog,
  createdAt: DateTime(2026, 8, 30, 10),
  readAt: read ? DateTime(2026, 8, 30, 11) : null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  final rows = <NotificationModel>[
    _notification(id: '1', client: Client(firstname: 'Naledi', lastname: 'Mokoena')),
    _notification(id: '2', read: true),
    _notification(id: '3'),
  ];

  group('707 — the All/Unread read-state filter', () {
    test('Unread is exactly the shipped dot condition', () {
      expect(NotificationReadFilter.all.apply(rows).length, 3);
      final unread = NotificationReadFilter.unread.apply(rows);
      expect(unread.map((n) => n.id), ['1', '3']);
      expect(unread.every((n) => n.readAt == null), isTrue);
    });

    test('each tab carries its own count for its pill', () {
      expect(NotificationReadFilter.all.countIn(rows), 3);
      expect(NotificationReadFilter.unread.countIn(rows), 2);
    });

    test('the tabs are ordered All then Unread, as the frame draws them', () {
      expect(NotificationReadFilter.values, [
        NotificationReadFilter.all,
        NotificationReadFilter.unread,
      ]);
      expect(NotificationReadFilter.all.wire, 'all');
      expect(NotificationReadFilter.unread.wire, 'unread');
    });
  });

  group('704/705 — the shipped row', () {
    Future<void> pumpRow(
      WidgetTester tester,
      NotificationModel notification,
    ) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: NotificationRow(
                notification: notification,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('names the client "First L." and keeps the body',
        (tester) async {
      await pumpRow(
        tester,
        _notification(
          id: '1',
          client: Client(firstname: 'Naledi', lastname: 'Mokoena'),
        ),
      );
      expect(find.text('Naledi M.'), findsOneWidget);
      expect(find.text('A new order came in'), findsOneWidget);
    });

    Color dotColour(WidgetTester tester) {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(NotificationRow),
              matching: find.byType(Container),
            )
            .last,
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    testWidgets('an unread row carries the primary dot; a read row does not',
        (tester) async {
      await pumpRow(tester, _notification(id: '1'));
      expect(dotColour(tester), AppStyle.primary);

      await pumpRow(tester, _notification(id: '2', read: true));
      expect(dotColour(tester), AppStyle.transparent);
    });

    testWidgets('a blog item with no photo gets the tinted glyph',
        (tester) async {
      await pumpRow(
        tester,
        _notification(id: '4', blog: BlogData(uuid: 'abc')),
      );
      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
