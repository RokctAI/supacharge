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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/navigation/embedded_widgets.dart';

import 'package:auth_sdk/src/common/presentation/pages/auth/login/login_embedded_slots.dart';
import 'package:auth_sdk/src/common/presentation/pages/auth/login/login_terms_notice.dart';

/// A host registry with nothing injected — byte-for-byte the shape the
/// composer generates into main.dart (`_HostEmbeddedWidgets`) for an app
/// whose installed SDKs declare no "embedded_widgets" at all. This is what a
/// launcher composing only base + users + auth + launch gets, and its
/// noSuchMethod is the StateError the login screen used to die on.
class _NothingComposed implements EmbeddedWidgets {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'EmbeddedWidgets.I.${invocation.memberName} has not been implemented — '
      'no installed SDK declares it in "embedded_widgets", and it was not '
      'added by hand in main.dart.');
}

/// A host registry with comms_sdk and corporate_sdk composed: the three
/// methods the login screen borrows from them all resolve.
class _CommsAndCorporateComposed implements EmbeddedWidgets {
  VoidCallback? capturedOnSave;

  @override
  Widget languageScreen({required VoidCallback onSave}) {
    capturedOnSave = onSave;
    return const Text('language-screen', textDirection: TextDirection.ltr);
  }

  @override
  Widget termPage() =>
      const Text('term-page', textDirection: TextDirection.ltr);

  @override
  Widget policyPage() =>
      const Text('policy-page', textDirection: TextDirection.ltr);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'EmbeddedWidgets.I.${invocation.memberName} has not been implemented.');
}

/// corporate_sdk composed but comms_sdk not — the legal line is real, the
/// language picker is not.
class _CorporateOnlyComposed implements EmbeddedWidgets {
  @override
  Widget termPage() =>
      const Text('term-page', textDirection: TextDirection.ltr);

  @override
  Widget policyPage() =>
      const Text('policy-page', textDirection: TextDirection.ltr);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'EmbeddedWidgets.I.${invocation.memberName} has not been implemented.');
}

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  final EmbeddedWidgets original = EmbeddedWidgets.I;
  tearDown(() => EmbeddedWidgets.I = original);

  group('LoginEmbeddedSlots.resolve — SDKs composed', () {
    test('every borrowed widget resolves', () {
      EmbeddedWidgets.I = _CommsAndCorporateComposed();

      final slots = LoginEmbeddedSlots.resolve(onLanguageSaved: () {});

      expect(slots.languageScreen, isNotNull);
      expect(slots.termPage, isNotNull);
      expect(slots.policyPage, isNotNull);
      expect(slots.hasLegalPages, isTrue);
    });

    test('the language picker is handed the caller\'s onSave', () {
      final registry = _CommsAndCorporateComposed();
      EmbeddedWidgets.I = registry;
      var saved = 0;

      LoginEmbeddedSlots.resolve(onLanguageSaved: () => saved++);
      registry.capturedOnSave!();

      expect(saved, 1);
    });

    test('the registry is asked exactly once per slot', () {
      final registry = _CountingRegistry();
      EmbeddedWidgets.I = registry;

      final slots = LoginEmbeddedSlots.resolve(onLanguageSaved: () {});
      // Reading the slots repeatedly must not go back to the registry.
      expect(slots.languageScreen, isNotNull);
      expect(slots.termPage, isNotNull);
      expect(slots.policyPage, isNotNull);
      expect(slots.hasLegalPages, isTrue);

      expect(registry.languageScreenCalls, 1);
      expect(registry.termPageCalls, 1);
      expect(registry.policyPageCalls, 1);
    });
  });

  group('LoginEmbeddedSlots.resolve — SDKs absent (the bug)', () {
    test('resolving against a bare host registry does not throw', () {
      EmbeddedWidgets.I = _NothingComposed();

      expect(
        () => LoginEmbeddedSlots.resolve(onLanguageSaved: () {}),
        returnsNormally,
      );
    });

    test('every absent slot is null and the legal line is off', () {
      EmbeddedWidgets.I = _NothingComposed();

      final slots = LoginEmbeddedSlots.resolve(onLanguageSaved: () {});

      expect(slots.introPage, isNull);
      expect(slots.languageScreen, isNull);
      expect(slots.termPage, isNull);
      expect(slots.policyPage, isNull);
      expect(slots.hasLegalPages, isFalse);
    });

    test('slots are independent: corporate composed, comms not', () {
      EmbeddedWidgets.I = _CorporateOnlyComposed();

      final slots = LoginEmbeddedSlots.resolve(onLanguageSaved: () {});

      expect(slots.languageScreen, isNull);
      expect(slots.hasLegalPages, isTrue);
    });

    test('a non-StateError failure inside a composed SDK still surfaces', () {
      EmbeddedWidgets.I = _ThrowingCorporate();

      expect(
        () => LoginEmbeddedSlots.resolve(onLanguageSaved: () {}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('LoginTermsNotice', () {
    testWidgets('renders both links when corporate_sdk is composed',
        (tester) async {
      EmbeddedWidgets.I = _CommsAndCorporateComposed();
      final slots = LoginEmbeddedSlots.resolve(onLanguageSaved: () {});

      await tester.pumpWidget(_host(LoginTermsNotice(slots: slots)));

      expect(find.byType(InkWell), findsNWidgets(2));
      expect(find.text(' & '), findsOneWidget);
    });

    testWidgets('the terms link opens corporate_sdk\'s terms page',
        (tester) async {
      EmbeddedWidgets.I = _CommsAndCorporateComposed();
      final slots = LoginEmbeddedSlots.resolve(onLanguageSaved: () {});

      await tester.pumpWidget(_host(LoginTermsNotice(slots: slots)));
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text('term-page'), findsOneWidget);
    });

    testWidgets('the policy link opens corporate_sdk\'s policy page',
        (tester) async {
      EmbeddedWidgets.I = _CommsAndCorporateComposed();
      final slots = LoginEmbeddedSlots.resolve(onLanguageSaved: () {});

      await tester.pumpWidget(_host(LoginTermsNotice(slots: slots)));
      await tester.tap(find.byType(InkWell).last);
      await tester.pumpAndSettle();

      expect(find.text('policy-page'), findsOneWidget);
    });

    testWidgets('renders nothing at all when corporate_sdk is absent',
        (tester) async {
      EmbeddedWidgets.I = _NothingComposed();
      final slots = LoginEmbeddedSlots.resolve(onLanguageSaved: () {});

      await tester.pumpWidget(_host(LoginTermsNotice(slots: slots)));

      expect(tester.takeException(), isNull);
      // No link to tap, and no half-sentence left behind.
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(
        tester.getSize(find.byType(LoginTermsNotice)),
        Size.zero,
      );
    });
  });
}

/// Counts registry lookups so "resolved once" is an assertion, not a hope.
class _CountingRegistry implements EmbeddedWidgets {
  int languageScreenCalls = 0;
  int termPageCalls = 0;
  int policyPageCalls = 0;

  @override
  Widget languageScreen({required VoidCallback onSave}) {
    languageScreenCalls++;
    return const SizedBox.shrink();
  }

  @override
  Widget termPage() {
    termPageCalls++;
    return const SizedBox.shrink();
  }

  @override
  Widget policyPage() {
    policyPageCalls++;
    return const SizedBox.shrink();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('not composed');
}

/// A composed SDK whose widget genuinely fails: the guard must not swallow
/// it, because it is not the registry's "not composed" signal.
class _ThrowingCorporate implements EmbeddedWidgets {
  @override
  Widget termPage() => throw const FormatException('broken terms page');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('not composed');
}
