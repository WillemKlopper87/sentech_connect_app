import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/features/account/presentation/pages/account_page.dart';
import 'package:sentech_connect_app/features/account_dashboard/presentation/bloc/account_cubit.dart';
import 'package:sentech_connect_app/features/account_dashboard/presentation/pages/dashboard_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/catalog_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/catalog_page.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/support_page.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/pages/voucher_scanner_page.dart';
import 'package:sentech_connect_app/shared/actions/support_actions.dart';

/// The persistent bottom-nav shell (Home/Shop/Scan/Support/Account),
/// hosting the four "Manage"/"Discover" tabs a customer returns to daily.
/// Onboarding and checkout screens (login, coverage, cart, checkout,
/// RICA, confirmation) are pushed full-screen on top of this shell.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.onOpenCart,
    required this.onResumeOrder,
    required this.onOpenPromotions,
    required this.onFindHotspots,
    this.onOpenPasses,
    this.showRouterCard = true,
    this.showMockFeatures = true,
    this.onChangeProvider,
    this.providerName,
    this.supportWhatsAppNumber,
  });

  final VoidCallback onOpenCart;
  final void Function(Order order) onResumeOrder;
  final VoidCallback onOpenPromotions;
  final VoidCallback onFindHotspots;
  final VoidCallback? onOpenPasses;

  /// The tenant's `cpe` flag: router and fixed-plan content is hidden when off.
  final bool showRouterCard;

  /// Support tickets and free Wi-Fi (and the hotspot finder) are backed by
  /// mock repositories until real APIs exist: shown in demo only, never prod.
  /// Scan (voucher redemption) is real (`POST /v1/me/vouchers/redeem`) and
  /// shows in both flavors.
  final bool showMockFeatures;
  final VoidCallback? onChangeProvider;
  final String? providerName;
  final String? supportWhatsAppNumber;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // Held as a stable instance (rather than created inline in `pages`) so
  // the dashboard's "Top up"/"Upgrade" quick actions can drive the Shop
  // tab's category filter directly, not just switch to it blindly.
  late final CatalogCubit _catalogCubit = CatalogCubit(locator());

  /// Unpaid order shown as a "finish your order" banner on the dashboard.
  late final OpenOrderCubit _openOrderCubit = OpenOrderCubit(locator());

  /// The customer's current hotspot pass, shown first on the dashboard.
  late final PassesCubit _passesCubit = PassesCubit(locator());

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // go_router reuses this shell when a checkout flow returns to /main, so
    // pick up an order that was just completed (or created) in the meantime.
    _openOrderCubit.refresh();
    _passesCubit.load();
  }

  @override
  void dispose() {
    _passesCubit.close();
    _catalogCubit.close();
    _openOrderCubit.close();
    super.dispose();
  }

  void _goToShop(ProductCategory category) {
    _catalogCubit.selectCategory(category);
    setState(() => _index = 1);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      MultiBlocProvider(
        providers: [
          // Fixed-plan account data is only loaded when the cpe flag is on.
          if (widget.showRouterCard)
            BlocProvider(create: (_) => AccountCubit(locator())),
          BlocProvider.value(value: _openOrderCubit),
          BlocProvider.value(value: _passesCubit),
        ],
        child: DashboardPage(
          onBuyPass: () => _goToShop(ProductCategory.hotspotPass),
          onTopUp: () => _goToShop(ProductCategory.voucher),
          onUpgrade: () => _goToShop(ProductCategory.home5g),
          onReportIssue: widget.showMockFeatures
              ? () => submitSupportTicket(
                  context,
                  initialCategory: TicketCategory.technical,
                )
              : null,
          onOpenPromotions: widget.showMockFeatures
              ? widget.onOpenPromotions
              : null,
          onResumeOrder: widget.onResumeOrder,
          onOpenPasses: widget.onOpenPasses,
          showRouterCard: widget.showRouterCard,
        ),
      ),
      BlocProvider.value(
        value: _catalogCubit,
        child: CatalogPage(
          onOpenCart: widget.onOpenCart,
          onOrderCreated: (order) => context.push(AppRoutes.forOrder(order)),
          onFindHotspots: widget.showMockFeatures
              ? widget.onFindHotspots
              : null,
        ),
      ),
      const VoucherScannerPage(),
      if (widget.showMockFeatures)
        BlocProvider(
          create: (_) => SupportCubit(locator()),
          child: SupportPage(
            cpe: widget.showRouterCard,
            whatsAppNumber: widget.supportWhatsAppNumber,
          ),
        ),
      AccountPage(
        onChangeProvider: widget.onChangeProvider,
        providerName: widget.providerName,
      ),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < pages.length; i++)
            TickerMode(enabled: i == _index, child: pages[i]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i == 0) {
            _openOrderCubit.refresh();
            _passesCubit.load();
          }
          setState(() => _index = i);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: context.l10n.navHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: context.l10n.navShop,
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: context.l10n.navScan,
          ),
          if (widget.showMockFeatures) ...[
            NavigationDestination(
              icon: Icon(Icons.support_agent_outlined),
              selectedIcon: Icon(Icons.support_agent),
              label: context.l10n.navHelp,
            ),
          ],
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: context.l10n.navAccount,
          ),
        ],
      ),
    );
  }
}
