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

import 'dart:convert';

import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/storage_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboarding_sdk/onboarding_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Design 46d/46h — what the guided run adds to the shipped flow: Back,
/// the required/optional fork, a drawn position, and survival across a
/// cold relaunch. Notifier-level; the page is covered in
/// intro_page_run_test.dart.
void main() {
  const baseKey = 'hostRecord.onboardingRun';
  Widget slide(String label) => Text(label);

  OnboardingSlide s(String id, {bool required = false, String? title}) =>
      OnboardingSlide(
        content: slide(id),
        data: {'id': id},
        required: required,
        title: title,
      );

  group('back (46d/46h chip 855)', () {
    test('the first host slide has no back; back never traps', () {
      final n = IntroNotifier(slides: [s('one'), s('two')]);
      n.chooseRole(OnboardingRole.student);
      expect(n.canGoBack, isFalse);
      n.previousHostSlide();
      expect(n.state.hostSlideIndex, 0);

      n.nextHostSlide();
      expect(n.canGoBack, isTrue);
      n.previousHostSlide();
      expect(n.state.hostSlideIndex, 0);
      expect(n.currentSlide?.data['id'], 'one');
      n.dispose();
    });

    test('back does not re-enter a finished run', () {
      final n = IntroNotifier(slides: [s('one')]);
      n.chooseRole(OnboardingRole.student);
      n.nextHostSlide();
      expect(n.hostSlidesComplete, isTrue);
      n.previousHostSlide();
      expect(n.hostSlidesComplete, isTrue);
      n.dispose();
    });

    test('a step passed by Back keeps its tick', () {
      final n = IntroNotifier(slides: [s('one'), s('two')]);
      n.chooseRole(OnboardingRole.student);
      n.nextHostSlide();
      n.previousHostSlide();
      expect(n.isCurrentSlideDone, isTrue);
      n.dispose();
    });
  });

  group('required blocks, optional skips (chip 862)', () {
    test('an optional slide can advance and skip at any time', () {
      final n = IntroNotifier(slides: [s('one'), s('two')]);
      n.chooseRole(OnboardingRole.student);
      expect(n.canAdvance, isTrue);
      n.skipHostSlide();
      expect(n.state.hostSlideIndex, 1);
      // Skipped, not ticked.
      expect(n.state.doneSlideKeys, isEmpty);
      n.dispose();
    });

    test('a required slide blocks until it reports done, and never skips',
        () {
      final n = IntroNotifier(slides: [s('one', required: true), s('two')]);
      n.chooseRole(OnboardingRole.student);
      expect(n.canAdvance, isFalse);
      n.skipHostSlide();
      expect(n.state.hostSlideIndex, 0);

      n.setCurrentSlideDone(true);
      expect(n.canAdvance, isTrue);
      n.setCurrentSlideDone(false);
      expect(n.canAdvance, isFalse);
      n.setCurrentSlideDone(true);
      n.nextHostSlide();
      expect(n.state.hostSlideIndex, 1);
      expect(n.state.doneSlideKeys, {'one'});
      n.dispose();
    });

    test('next() is itself the completion report', () {
      final n = IntroNotifier(slides: [s('one')]);
      n.chooseRole(OnboardingRole.student);
      n.nextHostSlide();
      expect(n.state.doneSlideKeys, {'one'});
      n.dispose();
    });
  });

  group('the position rail (chips 852/865)', () {
    test('counts welcome, role, visible host slides and the closing step',
        () {
      final n = IntroNotifier(slides: [
        s('school', title: 'Your school', ),
        s('grade', title: 'Your grade'),
      ]);
      expect(n.runSteps.map((e) => e.title), [
        'Welcome',
        'Who is setting this up?',
        'Your school',
        'Your grade',
        "You're all set",
      ]);
      expect(n.currentRunStep, 0);
      n.showRoleStep();
      expect(n.currentRunStep, 1);
      expect(n.runSteps[0].outcome, 'seen');
      n.chooseRole(OnboardingRole.student);
      expect(n.currentRunStep, 2);
      expect(n.runSteps[1].outcome, 'Student');
      n.nextHostSlide();
      expect(n.runSteps[2].state, OnboardingRunStepState.done);
      expect(n.runSteps[2].outcome, 'done');
      n.skipHostSlide();
      expect(n.runSteps[3].outcome, 'skipped');
      expect(n.currentRunStep, 4);
      n.dispose();
    });

    test("a parent's run is three steps, not five (chip 864)", () {
      final n = IntroNotifier(slides: [
        OnboardingSlide(
            content: slide('school'),
            roles: const {OnboardingRole.student}),
        OnboardingSlide(
            content: slide('grade'),
            roles: const {OnboardingRole.student}),
      ]);
      n.showRoleStep();
      n.chooseRole(OnboardingRole.parent);
      expect(n.runSteps, hasLength(3));
      expect(n.currentRunStep, 2);
      n.dispose();
    });

    test('untitled slides are named by position', () {
      final n = IntroNotifier(slides: [
        OnboardingSlide(content: slide('a')),
        OnboardingSlide(content: slide('b'), data: const {'title': 'Named'}),
      ]);
      expect(n.runSteps[2].title, 'Step 3');
      expect(n.runSteps[3].title, 'Named');
      n.dispose();
    });
  });

  group('survival across a cold relaunch (46h, ruling three)', () {
    test('an in-memory store round-trips position, ticks, role and values',
        () async {
      final store = InMemoryOnboardingProgressStore();
      final first = IntroNotifier(
          slides: [s('one'), s('two'), s('three')], store: store);
      await first.restore();
      expect(first.state.hydrated, isTrue);
      first.showRoleStep();
      first.chooseRole(OnboardingRole.student);
      first.nextHostSlide();
      first.nextHostSlide();
      first.setValue('three.name', 'Ridge');
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      final second = IntroNotifier(
          slides: [s('one'), s('two'), s('three')], store: store);
      expect(second.state.hydrated, isFalse);
      await second.restore();
      expect(second.state.hydrated, isTrue);
      expect(second.state.roleStepVisible, isTrue);
      expect(second.state.role, OnboardingRole.student);
      expect(second.state.hostSlideIndex, 2);
      expect(second.currentSlide?.data['id'], 'three');
      expect(second.state.doneSlideKeys, {'one', 'two'});
      expect(second.state.values['three.name'], 'Ridge');
      expect(second.currentRunStep, 4);
      second.dispose();
    });

    test('the default store writes the base_sdk onboarding-run record',
        () async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      const store = LocalStorageOnboardingProgressStore();
      final n = IntroNotifier(slides: [s('one'), s('two')], store: store);
      await n.restore();
      n.showRoleStep();
      n.chooseRole(OnboardingRole.parent);
      n.nextHostSlide();
      await Future<void>.delayed(Duration.zero);
      n.dispose();

      // The base key, not a key of this SDK's own (design 46e).
      expect(StorageKeys.keyHostRecordPrefix + StorageKeys.keyOnboardingRun,
          baseKey);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocalStorageOnboardingProgressStore.legacyKey),
          isNull);
      final raw = prefs.getString(baseKey);
      expect(raw, isNotNull);
      final json = jsonDecode(raw!) as Map;
      expect(json['stepIndex'], 1);
      expect(json['done'], ['one']);
      expect(json['role'], 'parent');
      expect(json['roleStepVisible'], isTrue);
      expect(DateTime.tryParse(json['lastTouched'] as String), isNotNull);
      expect(LocalStorage.getOnboardingRun(), json);

      final again = IntroNotifier(slides: [s('one'), s('two')], store: store);
      await again.restore();
      expect(again.state.hostSlideIndex, 1);
      expect(again.state.role, OnboardingRole.parent);
      again.dispose();
    });

    test('finishing the run clears the record', () async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      const store = LocalStorageOnboardingProgressStore();
      final n = IntroNotifier(slides: [s('one')], store: store);
      await n.restore();
      n.showRoleStep();
      await Future<void>.delayed(Duration.zero);
      expect(LocalStorage.getOnboardingRun(), isNotNull);
      await n.finish();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(baseKey), isNull);
      expect(LocalStorage.getOnboardingRun(), isNull);
      n.dispose();
    });

    test('a corrupt or foreign record starts fresh instead of throwing',
        () async {
      SharedPreferences.setMockInitialValues({baseKey: '{not json'});
      await LocalStorage.init();
      const store = LocalStorageOnboardingProgressStore();
      final n = IntroNotifier(slides: [s('one')], store: store);
      await n.restore();
      expect(n.state.hydrated, isTrue);
      expect(n.state.roleStepVisible, isFalse);
      n.dispose();

      expect(OnboardingRunRecord.fromJson({'stepIndex': 'x'}), isNull);
      expect(OnboardingRunRecord.fromJson('nope'), isNull);
    });

    test('a 1.1.0 record under the old key moves to the base key intact',
        () async {
      final legacy = {
        'version': 1,
        'stepIndex': 2,
        'done': ['one', 'two'],
        'lastTouched': '2026-09-01T10:00:00.000Z',
        'values': {'three.name': 'Ridge'},
        'role': 'parent',
        'roleStepVisible': true,
      };
      SharedPreferences.setMockInitialValues({
        LocalStorageOnboardingProgressStore.legacyKey: jsonEncode(legacy),
      });
      await LocalStorage.init();
      const store = LocalStorageOnboardingProgressStore();
      final n = IntroNotifier(
          slides: [s('one'), s('two'), s('three')], store: store);
      await n.restore();
      expect(n.state.hostSlideIndex, 2);
      expect(n.state.doneSlideKeys, {'one', 'two'});
      expect(n.state.values['three.name'], 'Ridge');
      expect(n.state.role, OnboardingRole.parent);
      expect(n.state.roleStepVisible, isTrue);
      n.dispose();

      // Read old, write new, delete old: the same JSON, now under base_sdk.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocalStorageOnboardingProgressStore.legacyKey),
          isNull);
      expect(LocalStorage.getOnboardingRun(), legacy);

      // A second launch reads the moved record without a legacy key around.
      final again = IntroNotifier(
          slides: [s('one'), s('two'), s('three')], store: store);
      await again.restore();
      expect(again.state.hostSlideIndex, 2);
      again.dispose();
    });

    test('a record under the base key wins over a stale legacy one',
        () async {
      SharedPreferences.setMockInitialValues({
        baseKey: jsonEncode({'stepIndex': 1, 'roleStepVisible': true}),
        LocalStorageOnboardingProgressStore.legacyKey:
            jsonEncode({'stepIndex': 0}),
      });
      await LocalStorage.init();
      const store = LocalStorageOnboardingProgressStore();
      final record = await store.read();
      expect(record?.stepIndex, 1);
      expect(record?.roleStepVisible, isTrue);
      // Not the move's turn: the legacy key is left alone.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocalStorageOnboardingProgressStore.legacyKey),
          isNotNull);
    });

    test('a corrupt legacy record starts fresh and is dropped', () async {
      SharedPreferences.setMockInitialValues({
        LocalStorageOnboardingProgressStore.legacyKey: '{not json',
      });
      await LocalStorage.init();
      const store = LocalStorageOnboardingProgressStore();
      expect(await store.read(), isNull);
      expect(LocalStorage.getOnboardingRun(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocalStorageOnboardingProgressStore.legacyKey),
          isNull);
    });

    test('a restored position is clamped to what this role can see',
        () async {
      final store = InMemoryOnboardingProgressStore(OnboardingRunRecord(
        stepIndex: 9,
        done: const {},
        lastTouched: DateTime.utc(2026, 9, 2),
        role: OnboardingRole.student,
        roleStepVisible: true,
      ));
      final n = IntroNotifier(slides: [s('one')], store: store);
      await n.restore();
      expect(n.state.hostSlideIndex, 1);
      expect(n.hostSlidesComplete, isTrue);
      n.dispose();
    });

    test('nothing is written before the record has been read back',
        () async {
      final store = InMemoryOnboardingProgressStore(OnboardingRunRecord(
        stepIndex: 1,
        done: const {'one'},
        lastTouched: DateTime.utc(2026, 9, 2),
        role: OnboardingRole.student,
        roleStepVisible: true,
      ));
      final n = IntroNotifier(slides: [s('one'), s('two')], store: store);
      // A write racing the read would clobber the saved run with index 0.
      n.showRoleStep();
      await Future<void>.delayed(Duration.zero);
      expect(store.record?.stepIndex, 1);
      await n.restore();
      expect(n.state.hostSlideIndex, 1);
      n.dispose();
    });
  });
}
