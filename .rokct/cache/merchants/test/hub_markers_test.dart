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

// The manager hub's composer seams (merchants_sdk 1.26.0): three marker
// pairs in templates/pages/manager/restaurant/restaurant_page.dart that
// SDKs this package never imports claim through their own manifest
// `integrations` entries. The installer
// (core/utils/flutter/sdk_installer_base.py, update_layout_integrations)
// is a substring insert: for every entry it skips when the replacement is
// already in the file, warns when the placeholder is not, and otherwise
// replaces EVERY occurrence of the placeholder with placeholder + "\n" +
// replacement, keeping the marker. This suite pins what that mechanic
// needs from the template (each marker once, at its contracted indent, in
// its section; no seeded demo glance left behind) and simulates the insert
// with the byte-for-byte replacement strings the owning SDKs declare, so a
// drift on either side fails here before a compose warns "marker not
// found". The composed page cannot COMPILE in this package (no
// productivity_sdk / revenue_sdk here, and the page carries a ${package}
// import), so the inserted widgets' compile is the host compose's to prove.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/services/local_storage.dart';

import '../templates/pages/manager/restaurant/widgets/sections_item.dart';

const String _template =
    'templates/pages/manager/restaurant/restaurant_page.dart';

/// One manifest `integrations` entry as the installer reads it.
class Seam {
  const Seam({required this.owner, required this.placeholder, this.replacement});

  final String owner;
  final String placeholder;

  /// Null while no SDK has claimed the marker yet.
  final String? replacement;
}

// productivity_sdk 1.2.0 — RokctAI/productivity PR #33 (head 7a89469),
// productivity/dart/manifest.json, verbatim (frame 46i, chip 859).
const Seam productivityImports = Seam(
  owner: 'productivity_sdk',
  placeholder: '// @productivity-tasks-row-imports',
  replacement: "import 'package:productivity_sdk/productivity_sdk.dart';",
);
const Seam productivityRow = Seam(
  owner: 'productivity_sdk',
  placeholder: '        // @productivity-tasks-row',
  replacement: '        PausedRunLine(\n'
      "          onOpen: (taskId) => context.router.pushNamed('/tasks/run?task=\$taskId'),\n"
      '        ),',
);

// revenue_sdk 1.11.1 — corporate/revenue/dart/manifest.json, verbatim
// (frame 49l, chip 989); its test/manager_wallet_integration_test.dart
// pins the same strings from that side.
const Seam revenueImports = Seam(
  owner: 'revenue_sdk',
  placeholder: '// @revenue-manager-wallet-imports',
  replacement: "import 'package:revenue_sdk/revenue_sdk.dart';",
);
const Seam revenueWallet = Seam(
  owner: 'revenue_sdk',
  placeholder: '      // @revenue-manager-wallet',
  replacement: '      ManagerWalletPane(\n'
      '        scope: ManagerWalletScope(\n'
      '          shopId: merchantWalletScope(ref).shopId,\n'
      '          shopName: merchantWalletScope(ref).shopName,\n'
      '        ),\n'
      '      ),',
);

// calc_sdk — reserved (frame 45b, chip 842); no manifest entry claims it
// yet, so only the markers are pinned.
const Seam calcImports = Seam(
  owner: 'calc_sdk',
  placeholder: '// @calc-memory-row-imports',
);
const Seam calcRow = Seam(
  owner: 'calc_sdk',
  placeholder: '        // @calc-memory-row',
);

const List<Seam> importsSeams = [productivityImports, calcImports, revenueImports];
const List<Seam> widgetSeams = [productivityRow, calcRow, revenueWallet];

/// update_layout_integrations for one entry, as the installer does it.
String compose(String content, Seam seam) {
  final replacement = seam.replacement;
  if (replacement == null) return content;
  if (content.contains(replacement)) return content;
  if (!content.contains(seam.placeholder)) {
    fail('marker ${seam.placeholder} not found for ${seam.owner}');
  }
  return content.replaceAll(seam.placeholder, '${seam.placeholder}\n$replacement');
}

int _count(String haystack, String needle) =>
    needle.allMatches(haystack).length;

int _balance(String s, String open, String close) =>
    _count(s, open) - _count(s, close);

/// The text of one section class, from its `class` line to the next
/// top-level `class`/function.
String _slice(String src, String from, String to) {
  final start = src.indexOf(from);
  if (start == -1) throw StateError('$from not in $_template');
  final end = src.indexOf(to, start + from.length);
  if (end == -1) throw StateError('$to not after $from in $_template');
  return src.substring(start, end);
}

Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final String src = File(_template).readAsStringSync();
  final String productivitySection = _slice(
      src, 'class MerchantProductivitySection', 'class MerchantSectionsList');
  final String walletSection = _slice(
      src, 'class MerchantWalletSection', 'class MerchantProductivitySection');

  group('markers', () {
    test('each of the six markers appears exactly once, on its own line', () {
      for (final seam in [...importsSeams, ...widgetSeams]) {
        expect(_count(src, seam.placeholder), 1,
            reason: '${seam.placeholder} must appear once (${seam.owner})');
        // On its own line: nothing before it but its indent, nothing after.
        expect(src.contains('\n${seam.placeholder}\n'), isTrue,
            reason: '${seam.placeholder} must be a whole line');
      }
    });

    test('a widget marker is never a substring of an imports marker', () {
      // The bare text IS a prefix of the -imports marker; the indent is
      // what keeps replaceAll from landing a widget in the import section.
      for (final w in widgetSeams) {
        for (final i in importsSeams) {
          expect(i.placeholder.contains(w.placeholder), isFalse,
              reason: '${w.placeholder} inside ${i.placeholder}');
          expect(w.placeholder.contains(i.placeholder), isFalse,
              reason: '${i.placeholder} inside ${w.placeholder}');
        }
      }
    });

    test('the imports markers sit at column 0 inside the import section', () {
      final lastImport = src.lastIndexOf("\nimport '");
      final firstDecl = src.indexOf('\nvoid registerMerchantProfileSections');
      for (final seam in importsSeams) {
        final at = src.indexOf(seam.placeholder);
        expect(at, greaterThan(lastImport), reason: seam.placeholder);
        expect(at, lessThan(firstDecl), reason: seam.placeholder);
        expect(seam.placeholder.startsWith('//'), isTrue);
      }
    });

    test('the Tasks and Calculator markers follow their rows, in the group', () {
      final tasks = productivitySection.indexOf('TrKeys.tasks');
      final calculator = productivitySection.indexOf('TrKeys.calculator');
      final tasksMarker = productivitySection.indexOf(productivityRow.placeholder);
      final calcMarker = productivitySection.indexOf(calcRow.placeholder);
      expect(tasks, isNot(-1));
      expect(calculator, isNot(-1));
      expect(tasksMarker, greaterThan(tasks));
      expect(tasksMarker, lessThan(calculator));
      expect(calcMarker, greaterThan(calculator));
      expect(calcMarker, lessThan(productivitySection.lastIndexOf('],')));
    });

    test('the wallet marker heads the candidate list and the section renders .first',
        () {
      final marker = walletSection.indexOf(revenueWallet.placeholder);
      final card = walletSection.indexOf('const BaseWalletCard(');
      final list = walletSection.indexOf('final List<Widget> wallet = <Widget>[');
      expect(list, isNot(-1));
      expect(marker, greaterThan(list));
      expect(card, greaterThan(marker));
      expect(walletSection, contains('wallet.first'));
      // `ref` is in scope for the replacement that names merchantWalletScope(ref).
      expect(walletSection, contains('class MerchantWalletSection extends ConsumerWidget'));
      expect(walletSection, contains('Widget build(BuildContext context, WidgetRef ref)'));
      expect(src, contains('merchantWalletScope(WidgetRef ref)'));
    });
  });

  group('no seeded demo glance', () {
    test('the productivity rows carry no subtitle and no isDemo gate', () {
      expect(productivitySection, isNot(contains('subtitle:')));
      expect(productivitySection, isNot(contains('isDemo')));
      expect(src, isNot(contains("'3 open")));
      expect(src, isNot(contains("'Memory holds")));
      expect(src, isNot(contains('1 240.50')));
    });

    test('the delete-account demo gate is kept', () {
      expect(src, contains('if (!DemoSession.demoActive)'));
    });

    testWidgets('without the owning SDKs the two rows are single-line',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      await tester.pumpWidget(_host(Column(children: [
        SectionsItem(
          title: 'Tasks',
          icon: Remix.task_line,
          onTap: () {},
        ),
        SectionsItem(
          title: 'Calculator',
          icon: Remix.calculator_line,
          onTap: () {},
        ),
      ])));
      expect(find.byType(SectionsItem), findsNWidgets(2));
      // One Text per row: the title, and nothing under it.
      expect(find.byType(Text), findsNWidgets(2));
      expect(find.textContaining('open'), findsNothing);
      expect(find.textContaining('Memory'), findsNothing);
    });
  });

  group('simulated compose', () {
    for (final pair in [
      (name: 'productivity_sdk 1.2.0', seams: [productivityImports, productivityRow]),
      (name: 'revenue_sdk 1.11.1', seams: [revenueImports, revenueWallet]),
    ]) {
      test('${pair.name}: lands once, keeps the markers, balanced, idempotent',
          () {
        var out = src;
        for (final seam in pair.seams) {
          out = compose(out, seam);
        }
        for (final seam in pair.seams) {
          final replacement = seam.replacement!;
          expect(_count(out, replacement), 1, reason: seam.placeholder);
          expect(_count(out, seam.placeholder), 1, reason: seam.placeholder);
          // Directly under its marker.
          expect(out, contains('${seam.placeholder}\n$replacement'));
          // The replacement is a closed expression on its own.
          expect(_balance(replacement, '(', ')'), 0);
          expect(_balance(replacement, '[', ']'), 0);
        }
        // Every other marker is untouched.
        for (final seam in [...importsSeams, ...widgetSeams]) {
          expect(_count(out, seam.placeholder), 1, reason: seam.placeholder);
        }
        expect(_balance(out, '(', ')'), _balance(src, '(', ')'));
        expect(_balance(out, '[', ']'), _balance(src, '[', ']'));
        // A second compose is a no-op (the installer's double-injection guard).
        var again = out;
        for (final seam in pair.seams) {
          again = compose(again, seam);
        }
        expect(again, out);
      });
    }

    test('productivity_sdk: PausedRunLine lands under the Tasks row, before Calculator',
        () {
      final out = compose(compose(src, productivityImports), productivityRow);
      final section = _slice(
          out, 'class MerchantProductivitySection', 'class MerchantSectionsList');
      final line = section.indexOf('PausedRunLine(');
      expect(line, greaterThan(section.indexOf('TrKeys.tasks')));
      expect(line, lessThan(section.indexOf('TrKeys.calculator')));
      expect(out.indexOf("import 'package:productivity_sdk/"),
          lessThan(out.indexOf('\nvoid registerMerchantProfileSections')));
    });

    test('revenue_sdk: ManagerWalletPane is first in the list, ahead of the bare card',
        () {
      final out = compose(compose(src, revenueImports), revenueWallet);
      final section = _slice(
          out, 'class MerchantWalletSection', 'class MerchantProductivitySection');
      final pane = section.indexOf('ManagerWalletPane(');
      final card = section.indexOf('const BaseWalletCard(');
      expect(pane, greaterThan(section.indexOf('<Widget>[')));
      expect(pane, lessThan(card));
      expect(out.indexOf("import 'package:revenue_sdk/"),
          lessThan(out.indexOf('\nvoid registerMerchantProfileSections')));
    });

    test('both SDKs together: the two inserts do not disturb each other', () {
      var out = src;
      for (final seam in [productivityImports, productivityRow, revenueImports, revenueWallet]) {
        out = compose(out, seam);
      }
      expect(_count(out, productivityRow.replacement!), 1);
      expect(_count(out, revenueWallet.replacement!), 1);
      expect(_count(out, "import 'package:productivity_sdk/"), 1);
      expect(_count(out, "import 'package:revenue_sdk/"), 1);
      expect(_balance(out, '(', ')'), _balance(src, '(', ')'));
    });
  });
}
