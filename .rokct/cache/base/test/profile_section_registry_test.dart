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


import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/presentation/pages/profile/profile_action_item.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';

/// Contract under test — the installer marker-block semantics ported to a
/// runtime registry:
///
///   * duplicate section id: first registration wins, the duplicate is
///     dropped;
///   * sections sort by order, ties broken by id, deterministically;
///   * identity-header slots (badge/stats/plan/planBack/corner): one
///     contributor per slot, first registration wins, gates follow the
///     section-gate contract;
///   * top-row actions: order-sorted with id tie-break, duplicate id
///     first-wins;
///   * grouped layout-agnostic actions: per-group first-wins on id,
///     order-sorted with id tie-break, groups isolated from each other;
///   * the top-row page title: host default until an SDK overrides it.
void main() {
  ProfileSection section(String id, int order) =>
      ProfileSection(id: id, order: order, builder: (_) => const SizedBox());

  ProfileActionItem action(String id, int order) => ProfileActionItem(
        id: id,
        order: order,
        icon: const IconData(0xe000),
        label: () => id,
        onTap: (_) {},
      );

  setUp(() => ProfileSectionRegistry.I.reset());

  test('duplicate id keeps the first registration', () {
    final first = section('wallet', 10);
    ProfileSectionRegistry.I.register(first);
    ProfileSectionRegistry.I.register(section('wallet', 99));

    expect(ProfileSectionRegistry.I.sections, hasLength(1));
    expect(ProfileSectionRegistry.I.sections.single, same(first));
  });

  test('sections sort by order with id tie-break', () {
    ProfileSectionRegistry.I.register(section('zeta', 10));
    ProfileSectionRegistry.I.register(section('alpha', 10));
    ProfileSectionRegistry.I.register(section('omega', 5));

    expect(
      ProfileSectionRegistry.I.sections.map((s) => s.id).toList(),
      ['omega', 'alpha', 'zeta'],
    );
  });

  test('host actions default to unset (affordances hidden)', () {
    expect(ProfileSectionRegistry.I.onEditProfile, isNull);
    expect(ProfileSectionRegistry.I.onLogout, isNull);
  });

  group('top-row page title', () {
    test('defaults to unset — the host renders its own title', () {
      expect(ProfileSectionRegistry.I.pageTitle, isNull);
    });

    test('is overridable and cleared by reset', () {
      ProfileSectionRegistry.I.pageTitle = 'Account';
      expect(ProfileSectionRegistry.I.pageTitle, 'Account');

      ProfileSectionRegistry.I.reset();
      expect(ProfileSectionRegistry.I.pageTitle, isNull);
    });
  });

  group('top-row actions', () {
    test('start empty', () {
      expect(ProfileSectionRegistry.I.topRowActions, isEmpty);
    });

    test('a registered action is retrievable with its id and order', () {
      ProfileSectionRegistry.I.registerTopRowAction(
        id: 'marketplace.likes',
        order: 10,
        builder: (_) => const SizedBox(),
      );

      expect(
        ProfileSectionRegistry.I.containsTopRowAction('marketplace.likes'),
        isTrue,
      );
      final action = ProfileSectionRegistry.I.topRowActions.single;
      expect(action.id, 'marketplace.likes');
      expect(action.order, 10);
    });

    test('actions sort by order with id tie-break', () {
      ProfileSectionRegistry.I.registerTopRowAction(
        id: 'zeta',
        order: 10,
        builder: (_) => const SizedBox(),
      );
      ProfileSectionRegistry.I.registerTopRowAction(
        id: 'alpha',
        order: 10,
        builder: (_) => const SizedBox(),
      );
      ProfileSectionRegistry.I.registerTopRowAction(
        id: 'omega',
        order: 5,
        builder: (_) => const SizedBox(),
      );

      expect(
        ProfileSectionRegistry.I.topRowActions.map((a) => a.id).toList(),
        ['omega', 'alpha', 'zeta'],
      );
    });

    test('duplicate id keeps the first registration', () {
      ProfileSectionRegistry.I.registerTopRowAction(
        id: 'marketplace.likes',
        order: 10,
        builder: (_) => const SizedBox(),
      );
      ProfileSectionRegistry.I.registerTopRowAction(
        id: 'marketplace.likes',
        order: 99,
        builder: (_) => const SizedBox(),
      );

      expect(ProfileSectionRegistry.I.topRowActions, hasLength(1));
      expect(ProfileSectionRegistry.I.topRowActions.single.order, 10);
    });

    test('reset clears registered actions', () {
      ProfileSectionRegistry.I.registerTopRowAction(
        id: 'marketplace.likes',
        builder: (_) => const SizedBox(),
      );

      ProfileSectionRegistry.I.reset();

      expect(ProfileSectionRegistry.I.topRowActions, isEmpty);
      expect(
        ProfileSectionRegistry.I.containsTopRowAction('marketplace.likes'),
        isFalse,
      );
    });
  });

  group('grouped actions', () {
    test('a group starts empty', () {
      expect(ProfileSectionRegistry.I.actions('marketplace.customer'),
          isEmpty);
      expect(
        ProfileSectionRegistry.I
            .containsAction('marketplace.customer', 'orders'),
        isFalse,
      );
    });

    test('a registered action is retrievable with its id and order', () {
      ProfileSectionRegistry.I.registerAction(
        group: 'marketplace.customer',
        item: action('marketplace.orders', 10),
      );

      expect(
        ProfileSectionRegistry.I
            .containsAction('marketplace.customer', 'marketplace.orders'),
        isTrue,
      );
      final item =
          ProfileSectionRegistry.I.actions('marketplace.customer').single;
      expect(item.id, 'marketplace.orders');
      expect(item.order, 10);
    });

    test('actions sort by order with id tie-break', () {
      ProfileSectionRegistry.I.registerAction(
        group: 'lms.student',
        item: action('zeta', 10),
      );
      ProfileSectionRegistry.I.registerAction(
        group: 'lms.student',
        item: action('alpha', 10),
      );
      ProfileSectionRegistry.I.registerAction(
        group: 'lms.student',
        item: action('omega', 5),
      );

      expect(
        ProfileSectionRegistry.I
            .actions('lms.student')
            .map((a) => a.id)
            .toList(),
        ['omega', 'alpha', 'zeta'],
      );
    });

    test('duplicate id within a group keeps the first registration', () {
      final first = action('marketplace.orders', 10);
      ProfileSectionRegistry.I.registerAction(
        group: 'marketplace.customer',
        item: first,
      );
      ProfileSectionRegistry.I.registerAction(
        group: 'marketplace.customer',
        item: action('marketplace.orders', 99),
      );

      expect(ProfileSectionRegistry.I.actions('marketplace.customer'),
          hasLength(1));
      expect(
        ProfileSectionRegistry.I.actions('marketplace.customer').single,
        same(first),
      );
    });

    test('groups are isolated — the same id may live in different groups',
        () {
      ProfileSectionRegistry.I.registerAction(
        group: 'marketplace.customer',
        item: action('help', 10),
      );
      ProfileSectionRegistry.I.registerAction(
        group: 'lms.student',
        item: action('help', 99),
      );

      expect(ProfileSectionRegistry.I.actions('marketplace.customer'),
          hasLength(1));
      expect(ProfileSectionRegistry.I.actions('lms.student'), hasLength(1));
      expect(
        ProfileSectionRegistry.I.actions('marketplace.customer').single.order,
        10,
      );
      expect(ProfileSectionRegistry.I.actions('lms.student').single.order,
          99);
      // A registration never leaks into a group it was not declared for.
      expect(
        ProfileSectionRegistry.I.containsAction('marketplace.customer', 'help'),
        isTrue,
      );
      expect(
        ProfileSectionRegistry.I.actions('marketplace.seller'),
        isEmpty,
      );
    });

    test('reset clears registered actions', () {
      ProfileSectionRegistry.I.registerAction(
        group: 'marketplace.customer',
        item: action('marketplace.orders', 10),
      );

      ProfileSectionRegistry.I.reset();

      expect(ProfileSectionRegistry.I.actions('marketplace.customer'),
          isEmpty);
      expect(
        ProfileSectionRegistry.I
            .containsAction('marketplace.customer', 'marketplace.orders'),
        isFalse,
      );
    });
  });

  group('ensureDefaultSections', () {
    test('adds the base.footer default when no SDK claimed the slot', () {
      ProfileSectionRegistry.I.ensureDefaultSections();

      expect(ProfileSectionRegistry.I.contains('base.footer'), isTrue);
      expect(ProfileSectionRegistry.I.sections.single.id, 'base.footer');
      expect(ProfileSectionRegistry.I.sections.single.order, 1000);
    });

    test('is idempotent', () {
      ProfileSectionRegistry.I.ensureDefaultSections();
      ProfileSectionRegistry.I.ensureDefaultSections();

      expect(ProfileSectionRegistry.I.sections, hasLength(1));
    });

    test('skips the default while a legacy marketplace.footer is present',
        () {
      // marketplace_sdk < 1.6.0 ships its own full footer (meta row
      // included) under this legacy id; the transitional guard keeps the
      // row from rendering twice during the staggered rollout.
      ProfileSectionRegistry.I.register(section('marketplace.footer', 140));

      ProfileSectionRegistry.I.ensureDefaultSections();

      expect(ProfileSectionRegistry.I.contains('base.footer'), isFalse);
      expect(ProfileSectionRegistry.I.sections, hasLength(1));
    });

    test('keeps an SDK-registered base.footer override (first wins)', () {
      final override = section('base.footer', 140);
      ProfileSectionRegistry.I.register(override);

      ProfileSectionRegistry.I.ensureDefaultSections();

      expect(ProfileSectionRegistry.I.sections.single, same(override));
      expect(ProfileSectionRegistry.I.sections.single.order, 140);
    });

    test('footer slot is hideable via a false visible gate', () async {
      final hidden = ProfileSection(
        id: 'base.footer',
        order: 1000,
        builder: (_) => const SizedBox(),
        visible: () async => false,
      );
      ProfileSectionRegistry.I.register(hidden);

      ProfileSectionRegistry.I.ensureDefaultSections();

      // The gated registration wins the slot, and its gate resolves
      // false — the host hides gated sections whose gate is false.
      expect(ProfileSectionRegistry.I.sections.single, same(hidden));
      await expectLater(
        ProfileSectionRegistry.I.sections.single.visible!(),
        completion(isFalse),
      );
    });
  });

  group('header slots', () {
    test('start unclaimed — the header renders slot-less by default', () {
      for (final slot in ProfileHeaderSlot.values) {
        expect(ProfileSectionRegistry.I.containsHeaderSlot(slot), isFalse);
        expect(ProfileSectionRegistry.I.headerSlot(slot), isNull);
      }
    });

    test('a registered slot is retrievable with its id and builder', () {
      ProfileSectionRegistry.I.registerHeaderSlot(
        ProfileHeaderSlot.stats,
        id: 'lms.student.header_stats',
        builder: (_) => const SizedBox(),
      );

      expect(
        ProfileSectionRegistry.I.containsHeaderSlot(ProfileHeaderSlot.stats),
        isTrue,
      );
      final content =
          ProfileSectionRegistry.I.headerSlot(ProfileHeaderSlot.stats)!;
      expect(content.id, 'lms.student.header_stats');
      expect(content.visible, isNull);
      // The other slots stay unclaimed — slots are independent.
      expect(
        ProfileSectionRegistry.I.containsHeaderSlot(ProfileHeaderSlot.badge),
        isFalse,
      );
      expect(
        ProfileSectionRegistry.I.containsHeaderSlot(ProfileHeaderSlot.plan),
        isFalse,
      );
    });

    test('a slot claimed twice keeps the first registration', () {
      ProfileSectionRegistry.I.registerHeaderSlot(
        ProfileHeaderSlot.badge,
        id: 'first.badge',
        builder: (_) => const SizedBox(),
      );
      ProfileSectionRegistry.I.registerHeaderSlot(
        ProfileHeaderSlot.badge,
        id: 'second.badge',
        builder: (_) => const SizedBox(),
      );

      expect(
        ProfileSectionRegistry.I.headerSlot(ProfileHeaderSlot.badge)!.id,
        'first.badge',
      );
    });

    test('the same id may claim different slots (first-wins is per slot)',
        () {
      ProfileSectionRegistry.I.registerHeaderSlot(
        ProfileHeaderSlot.badge,
        id: 'lms.student.identity',
        builder: (_) => const SizedBox(),
      );
      ProfileSectionRegistry.I.registerHeaderSlot(
        ProfileHeaderSlot.stats,
        id: 'lms.student.identity',
        builder: (_) => const SizedBox(),
      );

      expect(
        ProfileSectionRegistry.I.containsHeaderSlot(ProfileHeaderSlot.badge),
        isTrue,
      );
      expect(
        ProfileSectionRegistry.I.containsHeaderSlot(ProfileHeaderSlot.stats),
        isTrue,
      );
    });

    test('planBack and corner are claimable like every other slot', () {
      ProfileSectionRegistry.I.registerHeaderSlot(
        ProfileHeaderSlot.planBack,
        id: 'marketplace.plan_back',
        builder: (_) => const SizedBox(),
      );
      ProfileSectionRegistry.I.registerHeaderSlot(
        ProfileHeaderSlot.corner,
        id: 'marketplace.settings',
        builder: (_) => const SizedBox(),
      );

      expect(
        ProfileSectionRegistry.I
            .headerSlot(ProfileHeaderSlot.planBack)!
            .id,
        'marketplace.plan_back',
      );
      expect(
        ProfileSectionRegistry.I.headerSlot(ProfileHeaderSlot.corner)!.id,
        'marketplace.settings',
      );
      // The front-face slots stay unclaimed — slots are independent.
      expect(
        ProfileSectionRegistry.I.containsHeaderSlot(ProfileHeaderSlot.plan),
        isFalse,
      );
    });

    test('a slot is hideable via a false visible gate', () async {
      ProfileSectionRegistry.I.registerHeaderSlot(
        ProfileHeaderSlot.plan,
        id: 'marketplace.plan',
        builder: (_) => const SizedBox(),
        visible: () async => false,
      );

      // The registration holds the slot (so nothing else claims it), and
      // its gate resolves false — the host keeps a gated slot empty until
      // its gate resolves true, exactly like gated sections.
      final content =
          ProfileSectionRegistry.I.headerSlot(ProfileHeaderSlot.plan)!;
      await expectLater(content.visible!(), completion(isFalse));
    });

    test('reset clears claimed slots', () {
      ProfileSectionRegistry.I.registerHeaderSlot(
        ProfileHeaderSlot.stats,
        id: 'lms.student.header_stats',
        builder: (_) => const SizedBox(),
      );

      ProfileSectionRegistry.I.reset();

      expect(
        ProfileSectionRegistry.I.containsHeaderSlot(ProfileHeaderSlot.stats),
        isFalse,
      );
    });
  });
}
