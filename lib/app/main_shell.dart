import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/features/account/presentation/pages/account_page.dart';
import 'package:sentech_connect_app/features/account_dashboard/presentation/bloc/account_cubit.dart';
import 'package:sentech_connect_app/features/account_dashboard/presentation/pages/dashboard_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/catalog_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/catalog_page.dart';
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
    required this.onLoggedOut,
    required this.onOpenPromotions,
    required this.onFindHotspots,
  });

  final VoidCallback onOpenCart;
  final VoidCallback onLoggedOut;
  final VoidCallback onOpenPromotions;
  final VoidCallback onFindHotspots;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // Held as a stable instance (rather than created inline in `pages`) so
  // the dashboard's "Top up"/"Upgrade" quick actions can drive the Shop
  // tab's category filter directly, not just switch to it blindly.
  late final CatalogCubit _catalogCubit = CatalogCubit(locator());

  @override
  void dispose() {
    _catalogCubit.close();
    super.dispose();
  }

  void _goToShop(ProductCategory category) {
    _catalogCubit.selectCategory(category);
    setState(() => _index = 1);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BlocProvider(
        create: (_) => AccountCubit(locator()),
        child: DashboardPage(
          onTopUp: () => _goToShop(ProductCategory.voucher),
          onUpgrade: () => _goToShop(ProductCategory.home5g),
          onReportIssue: () => submitSupportTicket(context, initialCategory: TicketCategory.technical),
          onOpenPromotions: widget.onOpenPromotions,
        ),
      ),
      BlocProvider.value(
        value: _catalogCubit,
        child: CatalogPage(onOpenCart: widget.onOpenCart, onFindHotspots: widget.onFindHotspots),
      ),
      const VoucherScannerPage(),
      BlocProvider(create: (_) => SupportCubit(locator()), child: const SupportPage()),
      AccountPage(onLoggedOut: widget.onLoggedOut),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < pages.length; i++) TickerMode(enabled: i == _index, child: pages[i]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Shop'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_outlined), selectedIcon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Support'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}
