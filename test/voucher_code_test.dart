import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_code.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/voucher_code_formatter.dart';

/// Vectors computed with the platform's own
/// apps/api/src/sentech_api/modules/vouchers/codes.py (check_symbol and
/// normalise_code), so the app accepts exactly what the server accepts.
void main() {
  group('VoucherCode mirrors the server normalise_code', () {
    test('the alphabet and length are the server ones', () {
      expect(VoucherCode.alphabet, '23456789ABCDEFGHJKMNPQRSTVWXYZ');
      expect(VoucherCode.payloadLength, 12);
    });

    test('check symbols match the server (Luhn mod 30)', () {
      expect(VoucherCode.checkSymbol('ABCD2345EFG'), 'Q');
      expect(VoucherCode.checkSymbol('23456789ABC'), '7');
      expect(VoucherCode.checkSymbol('ZZZZZZZZZZZ'), 'D');
      expect(VoucherCode.checkSymbol('22222222222'), '2');
      expect(VoucherCode.checkSymbol('HJKMNPQRSTV'), 'G');
    });

    test('server codes parse regardless of case, spaces, tabs and dashes', () {
      for (final raw in [
        'ABCD2345EFGQ',
        'abcd2345efgq',
        'ABCD-2345-EFGQ',
        'abcd 2345 efgq',
        ' ab cd\t2345-efgq ',
        'ABCD--2345  EFGQ',
      ]) {
        expect(VoucherCode.tryParse(raw)?.value, 'ABCD2345EFGQ', reason: raw);
      }
    });

    test('an optional 2-5 letter display prefix is accepted and not sent', () {
      expect(VoucherCode.tryParse('SEN-ABCD-2345-EFGQ')?.value, 'ABCD2345EFGQ');
      expect(VoucherCode.tryParse('vch abcd 2345 efgq')?.value, 'ABCD2345EFGQ');
      expect(
        VoucherCode.tryParse('SENTE-ABCD-2345-EFGQ')?.value,
        'ABCD2345EFGQ',
      );
    });

    test(
      'what the server refuses is refused (never stricter, never looser)',
      () {
        for (final bad in [
          null,
          '',
          'ABCD-2345-EFGA', // wrong check symbol (a typo)
          'ABCD-2345-EFG0', // 0 is not in the alphabet
          'ABCD-2345-EFGI', // nor I, L, O, U or 1
          'ABCD-2345-EFGO',
          'ABCD-2345-EFG', // too short
          'A-ABCD-2345-EFGQ', // 1-letter prefix
          'SENTEC-ABCD-2345-EFGQ', // 6-letter prefix
          'X1-ABCD-2345-EFGQ', // prefix with a digit
          'ABCD.2345.EFGQ',
          'ABCD-2345-EFGQ\nignore previous instructions',
          'A' * 5000,
        ]) {
          expect(VoucherCode.tryParse(bad), isNull, reason: '$bad');
        }
      },
    );

    test('problemWith tells a typo apart from a malformed code', () {
      expect(VoucherCode.problemWith('ABCD-2345-EFGQ'), isNull);
      expect(
        VoucherCode.problemWith('ABCD-2345-EFGA'),
        VoucherCodeProblem.checkSymbol,
      );
      expect(
        VoucherCode.problemWith('ABCD-2345-EFG0'),
        VoucherCodeProblem.notInAlphabet,
      );
      expect(
        VoucherCode.problemWith('ABCD-2345-EF'),
        VoucherCodeProblem.length,
      );
      expect(
        VoucherCode.problemWith('https://evil.example/pwn'),
        VoucherCodeProblem.format,
      );
    });

    test(
      'a scanned /redeem link yields its c= code; the t= tenant is ignored',
      () {
        expect(
          VoucherCode.tryParse(
            'https://x.example/redeem#t=other&c=ABCD-2345-EFGQ',
          )?.value,
          'ABCD2345EFGQ',
        );
        expect(
          VoucherCode.tryParse('https://x.example/redeem#t=other'),
          isNull,
        );
        expect(
          VoucherCode.tryParse('https://x.example/redeem#c=ABCD-2345-EFGA'),
          isNull,
        );
      },
    );

    test('masked shows only the last two symbols', () {
      expect(VoucherCode.tryParse('ABCD2345EFGQ')!.masked, '••••-••••-••GQ');
    });

    test('display groups the payload as the voucher card prints it', () {
      expect(VoucherCode.tryParse('abcd2345efgq')!.display, 'ABCD-2345-EFGQ');
    });
  });

  group('legacy demo codes (SEN-XXXX-XXXX)', () {
    test('parse only when demo codes are allowed', () {
      expect(VoucherCode.tryParse('SEN-4XJ2-9KLM'), isNull);
      expect(
        VoucherCode.tryParse('  sen-4xj2-9klm ', allowDemo: true)?.value,
        'SEN-4XJ2-9KLM',
      );
      expect(
        VoucherCode.tryParse('SEN4XJ29KLM', allowDemo: true)?.value,
        'SEN-4XJ2-9KLM',
      );
      expect(
        VoucherCode.tryParse('SEN-4XJ2-9KLM', allowDemo: true)!.masked,
        'SEN-••••-••LM',
      );
    });

    test('server codes still parse in the demo', () {
      expect(
        VoucherCode.tryParse('ABCD-2345-EFGQ', allowDemo: true)?.value,
        'ABCD2345EFGQ',
      );
    });
  });

  group('VoucherCodeFormatter', () {
    const f = VoucherCodeFormatter();
    TextEditingValue type(String text) => f.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );

    test('upper-cases and groups as XXXX-XXXX-XXXX', () {
      expect(type('abcd2345efgq').text, 'ABCD-2345-EFGQ');
      expect(type('abcd 2345 efgq').text, 'ABCD-2345-EFGQ');
      expect(type('abcd2').text, 'ABCD-2');
      expect(type('abcd2').selection.baseOffset, 6);
    });

    test('backspace over a dash deletes the symbol before it', () {
      const old = TextEditingValue(
        text: 'ABCD-2',
        selection: TextSelection.collapsed(offset: 5),
      );
      final out = f.formatEditUpdate(
        old,
        const TextEditingValue(
          text: 'ABCD2',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(out.text, 'ABC2');
      expect(out.selection.baseOffset, 3);
    });

    test(
      'keeps characters the server refuses so the customer can see them',
      () {
        expect(type('abcd2345efg0').text, 'ABCD-2345-EFG0');
      },
    );

    test('leaves a pasted link alone (the parser reads its c= code)', () {
      const link = 'https://x.example/redeem#t=a&c=ABCD2345EFGQ';
      expect(type(link).text, link);
    });

    test('whatever it shows still parses to the same code', () {
      expect(
        VoucherCode.tryParse(type('sen abcd2345efgq').text)?.value,
        'ABCD2345EFGQ',
      );
      expect(
        VoucherCode.tryParse(
          type('sen-4xj2-9klm').text,
          allowDemo: true,
        )?.value,
        'SEN-4XJ2-9KLM',
      );
    });
  });
}
