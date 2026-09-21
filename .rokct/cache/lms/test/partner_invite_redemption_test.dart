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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

/// P3.2 partner-side invite redemption + P3.1 partner-first signup, client
/// side: the typed-outcome mapping of the backend's thrown error strings,
/// the two account-entry notifiers, and the page behaviour around the
/// new-vs-existing partner toggle. The backend returns `{email}` only (no
/// session), so success is proven here by the onAccountReady hook firing
/// with the just-proven credentials — the host chains the real login.
void main() {
  group('accept_invite error-string mapping', () {
    // Verbatim strings thrown by rlms/api/partner.py — the mapping matches
    // distinctive fragments, so each full sentence must resolve.
    const cases = {
      'This pairing code is invalid, expired, or already used.':
          AcceptInviteOutcome.invalidOrExpiredCode,
      "This account is registered as a student and can't also be an "
              'accountability partner. Partners need their own separate '
              'account.':
          AcceptInviteOutcome.emailBelongsToStudent,
      'Wrong password for the existing partner account.':
          AcceptInviteOutcome.wrongPassword,
      'This partner is already linked to this student.':
          AcceptInviteOutcome.alreadyLinked,
      'First name is required to create a new partner account.':
          AcceptInviteOutcome.needsFirstName,
      'An account with this email already exists.':
          AcceptInviteOutcome.emailTaken,
    };

    test('every server rejection resolves to its own outcome', () {
      cases.forEach((text, outcome) {
        // Wrapped the way the adapter sees it: inside an exception string.
        expect(mapAcceptInviteError('DioException [bad response]: $text'),
            outcome,
            reason: text);
      });
    });

    test('anything unrecognised is a generic failure', () {
      expect(mapAcceptInviteError('Connection reset by peer'),
          AcceptInviteOutcome.failed);
      expect(mapAcceptInviteError(''), AcceptInviteOutcome.failed);
    });
  });

  group('signup error-string mapping', () {
    test('already-exists maps to emailTaken, the rest to failed', () {
      expect(
          mapPartnerSignupError(
              'DioException: An account with this email already exists.'),
          PartnerSignupOutcome.emailTaken);
      expect(mapPartnerSignupError('Internal Server Error'),
          PartnerSignupOutcome.failed);
    });
  });

  group('PartnerAcceptInviteNotifier', () {
    test('success marks accepted and fires onAccountReady with the '
        'just-proven credentials', () async {
      final accepter = _FakeAccepter(AcceptInviteOutcome.success);
      String? readyEmail, readyPassword;
      final n = PartnerAcceptInviteNotifier(
        accepter: accepter,
        onAccountReady: (email, password) async {
          readyEmail = email;
          readyPassword = password;
        },
      );
      n.setCode('123456');
      n.setEmail(' mom@example.com ');
      n.setPassword('secret1');
      n.setFirstName('Naledi');
      n.setLastName('M');
      await n.submit();

      expect(n.state.accepted, isTrue);
      expect(n.state.error, isNull);
      // Email is trimmed before it goes to the backend AND to the login
      // chain; the password is passed through untouched.
      expect(readyEmail, 'mom@example.com');
      expect(readyPassword, 'secret1');
      expect(accepter.calls.single.email, 'mom@example.com');
      expect(accepter.calls.single.firstName, 'Naledi');
      n.dispose();
    });

    test('new-account path gates on first name; existing-account path '
        'does not and sends no name', () async {
      final accepter = _FakeAccepter(AcceptInviteOutcome.success);
      final n = PartnerAcceptInviteNotifier(accepter: accepter);
      n.setCode('123456');
      n.setEmail('mom@example.com');
      n.setPassword('secret1');
      expect(n.state.canSubmit, isFalse); // new account, no first name yet

      n.setHasAccount(true); // P3.1 multi-student attach
      expect(n.state.canSubmit, isTrue);
      n.setFirstName('Stale'); // typed earlier, then toggled — must not leak
      n.setHasAccount(true);
      await n.submit();
      expect(accepter.calls.single.firstName, isEmpty);
      expect(accepter.calls.single.lastName, isEmpty);
      n.dispose();
    });

    test('every rejection surfaces as itself and nothing succeeds',
        () async {
      for (final outcome in AcceptInviteOutcome.values) {
        if (outcome == AcceptInviteOutcome.success) continue;
        final n =
            PartnerAcceptInviteNotifier(accepter: _FakeAccepter(outcome));
        n.setCode('999999');
        n.setEmail('a@b.c');
        n.setPassword('pw');
        n.setHasAccount(true);
        await n.submit();
        expect(n.state.accepted, isFalse, reason: '$outcome');
        expect(n.state.error, outcome);
        // Correcting any field clears the error, same as every other
        // partner form.
        n.setCode('123456');
        expect(n.state.error, isNull);
        n.dispose();
      }
    });

    test('a failing onAccountReady hook never un-succeeds the acceptance '
        '(the account/link already exists server-side)', () async {
      final n = PartnerAcceptInviteNotifier(
        accepter: _FakeAccepter(AcceptInviteOutcome.success),
        onAccountReady: (_, __) async => throw StateError('login down'),
      );
      n.setCode('123456');
      n.setEmail('a@b.c');
      n.setPassword('pw');
      n.setHasAccount(true);
      await n.submit();
      expect(n.state.accepted, isTrue);
      expect(n.state.error, isNull);
      n.dispose();
    });

    test('no accepter wired (pure demo) fails soft', () async {
      final n = PartnerAcceptInviteNotifier();
      n.setCode('123456');
      n.setEmail('a@b.c');
      n.setPassword('pw');
      n.setHasAccount(true);
      await n.submit();
      expect(n.state.error, AcceptInviteOutcome.failed);
      n.dispose();
    });
  });

  group('PartnerSignupNotifier', () {
    test('success marks done and fires onAccountReady', () async {
      final service = _FakeSignup(PartnerSignupOutcome.success);
      String? readyEmail;
      final n = PartnerSignupNotifier(
        service: service,
        onAccountReady: (email, _) async => readyEmail = email,
      );
      n.setEmail('pa@example.com');
      n.setPassword('secret1');
      n.setFirstName('Thabo');
      await n.submit();
      expect(n.state.done, isTrue);
      expect(readyEmail, 'pa@example.com');
      expect(service.calls.single.firstName, 'Thabo');
      n.dispose();
    });

    test('first name is required locally (server backstop stays)', () {
      final n = PartnerSignupNotifier(
          service: _FakeSignup(PartnerSignupOutcome.success));
      n.setEmail('pa@example.com');
      n.setPassword('secret1');
      expect(n.state.canSubmit, isFalse);
      n.setFirstName('T');
      expect(n.state.canSubmit, isTrue);
      n.dispose();
    });

    test('emailTaken surfaces as itself; a throwing service fails soft',
        () async {
      final taken =
          PartnerSignupNotifier(service: _FakeSignup(PartnerSignupOutcome.emailTaken));
      taken.setEmail('pa@example.com');
      taken.setPassword('pw');
      taken.setFirstName('T');
      await taken.submit();
      expect(taken.state.done, isFalse);
      expect(taken.state.error, PartnerSignupOutcome.emailTaken);
      taken.dispose();

      final thrower = PartnerSignupNotifier(service: _ThrowingSignup());
      thrower.setEmail('pa@example.com');
      thrower.setPassword('pw');
      thrower.setFirstName('T');
      await thrower.submit();
      expect(thrower.state.error, PartnerSignupOutcome.failed);
      thrower.dispose();
    });
  });

  group('PartnerAcceptInvitePage', () {
    testWidgets('new-partner mode shows name fields; the existing-account '
        'toggle hides them', (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_host(const PartnerAcceptInvitePage()));
      await tester.pumpAndSettle();

      // Fallback humanization of the tr keys (no translations in tests).
      expect(find.text('Firstname'), findsWidgets);
      await tester.tap(find.text('I already have a partner account'));
      await tester.pumpAndSettle();
      expect(find.text('Firstname'), findsNothing);
    });

    testWidgets('a bad code surfaces under the code field; a good one '
        'lands on the linked screen', (tester) async {
      _tallViewport(tester);
      final accepter =
          _FakeAccepter(AcceptInviteOutcome.invalidOrExpiredCode);
      await tester.pumpWidget(_host(PartnerAcceptInvitePage(
          deps: PartnerAcceptInviteDeps(accepter: accepter))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I already have a partner account'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(3));
      await tester.enterText(find.byType(TextField).at(0), '000000');
      await tester.enterText(find.byType(TextField).at(1), 'a@b.c');
      await tester.enterText(find.byType(TextField).at(2), 'pw');
      await tester.pump();
      final btn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Accept invite'));
      expect(btn.onPressed, isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Accept invite'));
      await tester.pumpAndSettle();
      expect(accepter.calls, hasLength(1));
      expect(find.text('That code is invalid or has already been used'),
          findsOneWidget);

      accepter.outcome = AcceptInviteOutcome.success;
      await tester.enterText(find.byType(TextField).at(0), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Accept invite'));
      await tester.pumpAndSettle();
      expect(find.text('Youre linked'), findsOneWidget);
    });
  });

  group('PartnerSignupPage', () {
    testWidgets('emailTaken points at the email; success lands on the '
        'account-created screen', (tester) async {
      _tallViewport(tester);
      final service = _FakeSignup(PartnerSignupOutcome.emailTaken);
      await tester.pumpWidget(_host(PartnerSignupPage(
          deps: PartnerSignupDeps(service: service))));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'pa@b.c');
      await tester.enterText(find.byType(TextField).at(1), 'pw');
      await tester.enterText(find.byType(TextField).at(2), 'Thabo');
      // The submit button only rebuilds enabled on the next frame.
      await tester.pump();
      await tester
          .tap(find.widgetWithText(FilledButton, 'Create a partner account'));
      await tester.pumpAndSettle();
      // Base-sdk key (email_already_exists) — lms deliberately reuses it
      // instead of declaring a colliding manifest tr_key.
      expect(find.text('Email already exists'), findsOneWidget);

      service.outcome = PartnerSignupOutcome.success;
      await tester.enterText(find.byType(TextField).at(0), 'pa2@b.c');
      await tester
          .tap(find.widgetWithText(FilledButton, 'Create a partner account'));
      await tester.pumpAndSettle();
      expect(find.text('Account created'), findsOneWidget);
    });

    testWidgets('the two pages cross-link through injected navigation',
        (tester) async {
      _tallViewport(tester);
      var toSignup = false;
      await tester.pumpWidget(_host(PartnerAcceptInvitePage(
          deps: PartnerAcceptInviteDeps(onGoToSignup: () => toSignup = true))));
      await tester.pumpAndSettle();
      await tester.tap(
          find.text('No code yet create a partner account first'),
          warnIfMissed: false);
      expect(toSignup, isTrue);

      var toAccept = false;
      await tester.pumpWidget(_host(PartnerSignupPage(
          deps: PartnerSignupDeps(onGoToAcceptInvite: () => toAccept = true))));
      await tester.pumpAndSettle();
      await tester.tap(
          find.text('Have a code from your student accept the invite'),
          warnIfMissed: false);
      expect(toAccept, isTrue);
    });
  });
}

Widget _host(Widget child) =>
    ProviderScope(child: MaterialApp(home: child));

/// Both forms are longer than the default 800x600 test surface; a taller
/// viewport keeps every field and the footer links tappable without
/// scroll choreography.
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _AcceptCall {
  final String code, email, password, firstName, lastName;
  _AcceptCall(this.code, this.email, this.password, this.firstName,
      this.lastName);
}

class _FakeAccepter implements PartnerInviteAccepter {
  AcceptInviteOutcome outcome;
  final calls = <_AcceptCall>[];
  _FakeAccepter(this.outcome);

  @override
  Future<AcceptInviteOutcome> acceptInvite({
    required String code,
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
  }) async {
    calls.add(_AcceptCall(code, email, password, firstName, lastName));
    return outcome;
  }
}

class _SignupCall {
  final String email, password, firstName, lastName;
  _SignupCall(this.email, this.password, this.firstName, this.lastName);
}

class _FakeSignup implements PartnerSignupService {
  PartnerSignupOutcome outcome;
  final calls = <_SignupCall>[];
  _FakeSignup(this.outcome);

  @override
  Future<PartnerSignupOutcome> signup({
    required String email,
    required String password,
    required String firstName,
    String lastName = '',
  }) async {
    calls.add(_SignupCall(email, password, firstName, lastName));
    return outcome;
  }
}

class _ThrowingSignup implements PartnerSignupService {
  @override
  Future<PartnerSignupOutcome> signup({
    required String email,
    required String password,
    required String firstName,
    String lastName = '',
  }) async =>
      throw StateError('boom');
}
