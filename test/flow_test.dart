import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/app.dart';
import 'package:sentech_connect_app/app/locator.dart';

/// Drives the full "Discover → Activate → Manage" journey end-to-end
/// against the mock repositories, asserting each screen renders the
/// content it should. This is the closest available substitute for
/// visually running the app in this environment (no browser/screenshot
/// tool and no Android emulator are available here).
///
/// Note: once the bottom-nav shell mounts, the voucher scanner tab's
/// scan-line animation runs forever (it's kept alive by IndexedStack even
/// while other tabs/routes are shown), so `pumpAndSettle` can never
/// resolve from that point on — bounded `pump(duration)` calls are used
/// instead of `pumpAndSettle` for every step after that.
void main() {
  setUpAll(() {
    setupLocator();
  });

  testWidgets(
      'splash -> login -> coverage -> catalog -> cart -> checkout -> rica -> confirmation -> dashboard',
      (tester) async {
    await tester.pumpWidget(SentechConnectApp());
    await tester.pump(); // splash first frame
    await tester.pump(const Duration(milliseconds: 1300)); // splash auto-advance delay
    await tester.pumpAndSettle();

    // 1. Login
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text('Log in with Face ID'));
    await tester.pumpAndSettle();

    // 2. Coverage check
    expect(find.text('Coverage check'), findsOneWidget);
    expect(find.text('5G FWA available'), findsOneWidget);
    await tester.tap(find.text('View plans for this address'));
    await tester.pump(); // navigate
    await tester.pump(const Duration(milliseconds: 500)); // account cubit load delay (Home tab)

    // 3. Catalog — MainShell lands on Home/Dashboard by default, switch to Shop
    expect(find.text('Dashboard'), findsOneWidget);
    await tester.tap(find.text('Shop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // catalog cubit load delay
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Home 100'), findsOneWidget);

    // 4. Add the featured plan to cart, then open the cart
    await tester.tap(find.text('Add to cart').at(1)); // "Home 100", the featured plan
    await tester.pump();
    await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // push transition

    // 5. Cart review
    expect(find.text('Your cart'), findsOneWidget);
    expect(find.text('Home 100'), findsWidgets); // also present in the catalog page underneath
    await tester.tap(find.text('Checkout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // push transition

    // 6. Checkout
    expect(find.text('Checkout'), findsWidgets); // app bar title + the cart page's button underneath
    expect(find.textContaining('Pay R'), findsOneWidget);
    await tester.tap(find.textContaining('Pay R'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // mock payment delay
    await tester.pump(const Duration(milliseconds: 400)); // push transition

    // 7. RICA verification
    expect(find.text('Verify your identity'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // mock liveness delay
    await tester.pump(const Duration(milliseconds: 400)); // push transition

    // 8. Confirmation
    expect(find.text("You're connected!"), findsOneWidget);
    expect(find.textContaining('SEN-48213'), findsOneWidget);
    await tester.tap(find.text('Back to dashboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // navigation transition
    await tester.pump(const Duration(milliseconds: 500)); // account cubit load delay

    // 9. Dashboard — go_router reuses the existing MainShell instance, which
    // keeps its previous tab selection (Shop, from step 3) rather than
    // resetting to Home. Switch to the Home tab explicitly to reach it.
    await tester.tap(find.text('Home'));
    await tester.pump();
    expect(find.text('Dashboard'), findsOneWidget);

    // 10. Voucher scanner tab
    await tester.tap(find.text('Scan'));
    await tester.pump();
    expect(find.text('Scan voucher'), findsOneWidget);

    // 11. Support tab
    await tester.tap(find.text('Support'));
    await tester.pump();
    expect(find.text('Help & support'), findsOneWidget);
    expect(find.text('Submit a ticket'), findsWidgets);
    expect(find.text('WhatsApp'), findsOneWidget);
  });
}
