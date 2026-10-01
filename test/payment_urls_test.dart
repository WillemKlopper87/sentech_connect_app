import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/payment_urls.dart';

void main() {
  test(
    'our return URLs end the hand-off (any host: they only trigger polling)',
    () {
      expect(
        isPaymentReturnUrl(
          Uri.parse('https://www.example.test/sentech/checkout/accepted'),
        ),
        isTrue,
      );
      expect(
        isPaymentReturnUrl(
          Uri.parse('https://www.example.test/acme-wifi/checkout/declined'),
        ),
        isTrue,
      );
      expect(
        isPaymentReturnUrl(
          Uri.parse('http://127.0.0.1:3000/sentech/checkout/return'),
        ),
        isTrue,
      );
      expect(
        isPaymentReturnUrl(
          Uri.parse('https://paynow.netcash.co.za/site/paynow.aspx'),
        ),
        isFalse,
      );
      expect(
        isPaymentReturnUrl(
          Uri.parse('https://www.example.test/checkout/accepted'),
        ),
        isFalse,
      );
    },
  );

  test('only https is navigable; local http only when allowed (debug)', () {
    expect(
      isAllowedPaymentUrl(
        Uri.parse('https://paynow.netcash.co.za/x'),
        allowLocalHttp: false,
      ),
      isTrue,
    );
    expect(
      isAllowedPaymentUrl(
        Uri.parse('http://paynow.netcash.co.za/x'),
        allowLocalHttp: true,
      ),
      isFalse,
    );
    expect(
      isAllowedPaymentUrl(
        Uri.parse('http://10.0.2.2:3000/x'),
        allowLocalHttp: true,
      ),
      isTrue,
    );
    expect(
      isAllowedPaymentUrl(
        Uri.parse('http://10.0.2.2:3000/x'),
        allowLocalHttp: false,
      ),
      isFalse,
    );
    for (final url in [
      'javascript:alert(1)',
      'intent://pay#Intent;end',
      'file:///etc/hosts',
      'data:text/html,hi',
    ]) {
      expect(
        isAllowedPaymentUrl(Uri.parse(url), allowLocalHttp: true),
        isFalse,
        reason: url,
      );
    }
  });

  test(
    'GET hand-offs carry the fields in the query; POST bodies are form-encoded',
    () {
      final handoff = PaymentHandoff(
        paymentId: 'p1',
        reference: 'SC1',
        gateway: 'fake',
        method: PaymentHandoffMethod.get,
        url: Uri.parse('https://fake-gateway.invalid/pay?x=1'),
        fields: const {'reference': 'SC1', 'amount_cents': '3000'},
        amountCents: 3000,
      );
      expect(getHandoffUri(handoff).queryParameters, {
        'x': '1',
        'reference': 'SC1',
        'amount_cents': '3000',
      });
      expect(
        formBody(const {'p3': '1 Hour Pass', 'a&b': 'c=d'}),
        'p3=1+Hour+Pass&a%26b=c%3Dd',
      );
    },
  );

  test(
    'web view navigation is pinned to the gateway origin and the return URL',
    () {
      final handoff = PaymentHandoff(
        paymentId: 'p1',
        reference: 'SC1',
        gateway: 'netcash',
        method: PaymentHandoffMethod.post,
        url: Uri.parse('https://paynow.netcash.co.za/site/paynow.aspx'),
        amountCents: 3000,
      );
      bool allowed(String url, {bool local = false}) =>
          isAllowedHandoffNavigation(
            Uri.parse(url),
            handoff: handoff,
            allowLocalHttp: local,
          );
      expect(allowed('https://paynow.netcash.co.za/site/other'), isTrue);
      // Return URLs (any host) are intercepted before this check, so a random
      // other https origin is not navigable.
      expect(allowed('https://evil.example/phish'), isFalse);
      expect(allowed('https://paynow.netcash.co.za.evil.example/x'), isFalse);
      expect(allowed('http://paynow.netcash.co.za/x', local: true), isFalse);
      expect(allowed('about:blank'), isTrue);
      expect(allowed('javascript:alert(1)'), isFalse);
    },
  );

  group('decideNavigation', () {
    final handoff = PaymentHandoff(
      paymentId: 'p1',
      reference: 'SC1',
      gateway: 'netcash',
      method: PaymentHandoffMethod.post,
      url: Uri.parse('https://paynow.netcash.co.za/site/paynow.aspx'),
      amountCents: 3000,
    );
    NavigationVerdict decide(
      String url, {
      bool main = true,
      bool local = false,
    }) => decideNavigation(
      Uri.parse(url),
      isMainFrame: main,
      handoff: handoff,
      allowLocalHttp: local,
    );

    test('the initial hand-off URL is allowed', () {
      expect(decide(handoff.url.toString()), NavigationVerdict.allow);
    });
    test('a return URL wins first, even on another host or in a sub-frame', () {
      expect(
        decide('https://www.example.test/sentech/checkout/accepted'),
        NavigationVerdict.returned,
      );
      expect(
        decide(
          'https://www.example.test/sentech/checkout/declined',
          main: false,
        ),
        NavigationVerdict.returned,
      );
    });
    test('main frame is pinned to the gateway host', () {
      expect(decide('https://other.example/x'), NavigationVerdict.block);
      expect(
        decide('http://paynow.netcash.co.za/x', local: true),
        NavigationVerdict.block,
      );
    });
    test('sub-frames follow the scheme rules only', () {
      expect(
        decide('https://3ds.bank.example/frame', main: false),
        NavigationVerdict.allow,
      );
      expect(
        decide('javascript:alert(1)', main: false),
        NavigationVerdict.block,
      );
      expect(
        decide('http://10.0.2.2:3000/x', main: false),
        NavigationVerdict.block,
      );
      expect(
        decide('http://10.0.2.2:3000/x', main: false, local: true),
        NavigationVerdict.allow,
      );
    });
  });
}
