import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'helpers/first_run_tenant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/app.dart';
import 'helpers/test_setup.dart';

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
/// Route transitions animate for longer than the old fixed 400ms on current
/// Flutter/go_router, and the incoming page ignores taps until they finish.
/// `pumpAndSettle` can't be used here (see the class note about the scanner
/// animation), so pump a bounded duration that comfortably covers them.
Future<void> pumpTransition(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 1000));

void main() {
  setUpAppTests();

  testWidgets(
    'splash -> login -> coverage -> catalog -> cart -> checkout -> rica -> confirmation -> dashboard',
    (tester) async {
      // Physical-product demo explicitly includes home-internet onboarding.
      locator.registerSingleton<TenantRepository>(
        FirstRunTenantRepository(cpe: true, rica: true),
      );
      await tester.pumpWidget(const SentechConnectApp());
      await tester.pump(); // splash first frame
      await tester.pump(
        const Duration(milliseconds: 1300),
      ); // splash auto-advance delay
      await tester.pumpAndSettle();

      // 1. Login
      expect(find.text('Hello!'), findsOneWidget);
      expect(
        find.text('Use biometrics'),
        findsNothing,
      ); // no earlier session on this device
      await tester.enterText(
        find.widgetWithText(TextField, 'Mobile number'),
        '0810000000',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // mock OTP request delay
      await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'),
        '123456',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // mock OTP verify delay
      // A returning customer meets the consent step (terms + privacy) before anything else.
      await tester.pumpAndSettle();
      expect(find.text('Terms of Service'), findsOneWidget);
      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();

      // 2. Coverage check
      expect(find.text('Coverage check'), findsOneWidget);
      expect(find.text('Home internet is available here'), findsOneWidget);
      // A typed address is looked up by the phone's map service: say so.
      expect(
        find.textContaining("phone's map service (Google or Apple)"),
        findsOneWidget,
      );
      await tester.tap(find.text('View plans for this address'));
      await tester.pump(); // navigate
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // account cubit load delay (Home tab)

      // 3. Catalog — MainShell lands on Home/Dashboard by default, switch to Shop
      expect(find.text('Home'), findsNWidgets(2));
      // Home includes the router for this physical-product tenant.
      expect(find.text('Buy a pass'), findsWidgets);
      expect(find.text('Living room router'), findsOneWidget);
      await tester.tap(find.text('Shop'));
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // catalog cubit load delay
      expect(find.text('Buy'), findsOneWidget);
      // Hotspot passes lead the Shop; the physical Home 5G plans are a later tab.
      expect(find.text('Day Pass'), findsOneWidget);
      expect(find.text('Home 100'), findsNothing);
      await tester.tap(find.text('Home 5G'));
      await tester.pump();
      expect(find.text('Home 100'), findsOneWidget);

      // 4. Add the featured plan to cart, then open the cart
      await tester.tap(
        find.text('Add to cart').at(1),
      ); // "Home 100", the featured plan
      await tester.pump();
      await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
      await tester.pump();
      await pumpTransition(tester); // push transition

      // 5. Cart review
      expect(find.text('Your cart'), findsOneWidget);
      expect(
        find.text('Home 100'),
        findsWidgets,
      ); // also present in the catalog page underneath
      // The "added to cart" snackbar floats over the Checkout button until it
      // times out, so let it expire before tapping.
      // (The dismiss timer only starts once the snackbar's enter animation
      // finishes, so a single long pump isn't enough — step through time.)
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.text('Checkout'));
      await tester.pump();
      await pumpTransition(tester); // push transition

      // 6. Checkout review — identity is verified BEFORE payment, so this
      // step only creates the (unpaid) order.
      expect(
        find.text('Checkout'),
        findsWidgets,
      ); // app bar title + the cart page's button underneath
      expect(find.text('Verify identity to continue'), findsOneWidget);
      expect(find.textContaining('Pay R'), findsNothing);
      await tester.tap(find.text('Verify identity to continue'));
      await tester.pump();
      await tester.pump(
        const Duration(seconds: 1),
      ); // mock order creation delay
      await pumpTransition(tester); // push transition

      // 7. RICA verification
      expect(find.text('Verify your identity'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester
          .pumpAndSettle(); // POPIA consent dialog (verification has not started yet)
      expect(find.text('Your privacy'), findsOneWidget);
      await tester.tap(find.text('I agree'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3)); // mock liveness delay
      await pumpTransition(tester); // push transition

      // 7b. Payment — only reachable once identity is verified
      expect(find.text('Identity verified'), findsOneWidget);
      await tester.tap(find.textContaining('Pay R'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2)); // mock payment delay
      await pumpTransition(tester); // navigation transition

      // 8. Confirmation
      expect(find.text("You're all set!"), findsOneWidget);
      expect(find.textContaining('SEN-48213'), findsOneWidget);
      await tester.tap(find.text('Back to Home'));
      await tester.pump();
      await pumpTransition(tester); // navigation transition
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // account cubit load delay

      // 9. Dashboard — go_router reuses the existing MainShell instance, which
      // keeps its previous tab selection (Shop, from step 3) rather than
      // resetting to Home. Switch to the Home tab explicitly to reach it.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Home'),
        ),
      );
      await tester.pump();
      expect(find.text('Home'), findsNWidgets(2));

      // 10. Voucher scanner tab
      await tester.tap(find.text('Scan'));
      await tester.pump();
      expect(find.text('Scan voucher'), findsOneWidget);

      // 11. Support tab
      await tester.tap(find.text('Help'));
      await tester.pump();
      expect(find.text('Help & support'), findsOneWidget);
      expect(find.text('Submit a ticket'), findsWidgets);
      expect(find.text('WhatsApp'), findsOneWidget);
    },
  );

  // Audit screenshot 11: buying a WiFi pass under a tenant with rica: true
  // (the demo tenant) used to open the face check. RICA follows the product,
  // not the tenant flag alone: a hotspot pass goes from checkout to payment.
  testWidgets('a WiFi pass goes checkout -> payment with no identity check', (
    tester,
  ) async {
    await tester.pumpWidget(const SentechConnectApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Mobile number'),
      '0810000000',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.widgetWithText(TextField, '6-digit code'),
      '123456',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    expect(find.text('Coverage check'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Shop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Day Pass'), findsOneWidget);
    await tester.tap(find.text('Add to cart').at(1)); // "Day Pass"
    await tester.pump();
    await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
    await tester.pump();
    await pumpTransition(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.tap(find.text('Checkout'));
    await tester.pump();
    await pumpTransition(tester);

    expect(find.text('Verify identity to continue'), findsNothing);
    expect(find.textContaining('RICA'), findsNothing);
    await tester.tap(find.text('Continue to payment'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await pumpTransition(tester);

    expect(find.text('Verify your identity'), findsNothing);
    expect(find.text('Identity verified'), findsNothing);
    expect(find.textContaining('Pay R'), findsOneWidget);
  });
}
