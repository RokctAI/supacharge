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

// Host-side route shells + profile-host wiring for wallet_sdk (#33). The
// `/wallet-topup` path this registers is the exact string lms_sdk's
// subscribe surface pushes beside its insufficient-funds refusal
// (agent PR #150: `context.router.pushNamed('/wallet-topup', ...)`), so
// changing it there means changing it here in the same breath.
// `/wallet-history` is the wallet card's history arrow target (pushed by
// path from wallet_sdk's WalletProfileCard, same guarded idiom).

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:wallet_sdk/wallet_sdk.dart';

/// Registers the 'wallet.card' profile section with base_sdk's
/// ProfileSectionRegistry — called once at boot from this SDK's `di_hooks`
/// manifest entry (the same pattern as marketplace_sdk's
/// registerMarketplaceProfileSections). Configuration rides
/// [WalletCardSection]'s static seam; a home SDK that wants to reconfigure
/// the card (symbol, visibility, extra actions, display-only) sets those
/// fields from its own di_hook.
void registerWalletProfileSection() {
  WalletCardSection.register();
}

/// Host route shell for [WalletTopUpPage] (wallet_sdk-resident page).
@RoutePage(name: 'WalletTopUpRoute')
class WalletTopUpRouteView extends StatelessWidget {
  const WalletTopUpRouteView({super.key});

  @override
  Widget build(BuildContext context) => const WalletTopUpPage();
}

/// Host route shell for [WalletHistoryPage] (wallet_sdk-resident page).
/// Constructor keeps the donor page's `isBackButton` param so navigation
/// call-sites that pushed marketplace's page keep working after recompose.
@RoutePage(name: 'WalletHistoryRoute')
class WalletHistoryRouteView extends StatelessWidget {
  final bool isBackButton;

  const WalletHistoryRouteView({super.key, this.isBackButton = true});

  @override
  Widget build(BuildContext context) =>
      WalletHistoryPage(isBackButton: isBackButton);
}
