import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sentech_connect_app/features/subscriber/domain/kyc/id_document_encoder.dart';

Uint8List _noisyJpeg(int w, int h) {
  final random = Random(1);
  final image = img.Image(width: w, height: h);
  for (final p in image) {
    p.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

void main() {
  test('a big photo is scaled to the long edge and re-encoded as JPEG under the cap', () {
    final result = const IdDocumentEncoder().encode(_noisyJpeg(3000, 2000));
    expect(result.issue, isNull);
    final jpeg = result.document!.jpeg;
    expect(jpeg.take(3), [0xff, 0xd8, 0xff]);
    expect(jpeg.length, lessThanOrEqualTo(4 * 1024 * 1024));
    final out = img.decodeJpg(jpeg)!;
    expect(out.width, 2000);
    expect(out.height, 1333);
    expect(result.document!.base64.length, greaterThan(jpeg.length));
  });

  test('a portrait photo is limited by its height', () {
    final out = img.decodeJpg(const IdDocumentEncoder().encode(_noisyJpeg(1500, 3000)).document!.jpeg)!;
    expect(out.height, 2000);
    expect(out.width, 1000);
  });

  test('a small photo keeps its size', () {
    final out = img.decodeJpg(const IdDocumentEncoder().encode(_noisyJpeg(640, 480)).document!.jpeg)!;
    expect((out.width, out.height), (640, 480));
  });

  test('a PNG with transparency is flattened onto white and comes out as JPEG', () {
    final image = img.Image(width: 40, height: 40, numChannels: 4); // fully transparent
    final result = const IdDocumentEncoder().encode(Uint8List.fromList(img.encodePng(image)));
    final out = img.decodeJpg(result.document!.jpeg)!;
    final pixel = out.getPixel(20, 20);
    expect(pixel.r, greaterThan(240));
    expect(pixel.g, greaterThan(240));
    expect(pixel.b, greaterThan(240));
  });

  test('the output carries no EXIF block', () {
    final image = img.Image(width: 64, height: 64)..exif.imageIfd.make = 'PhoneMaker';
    final input = Uint8List.fromList(img.encodeJpg(image));
    expect(String.fromCharCodes(input), contains('PhoneMaker'));
    final out = const IdDocumentEncoder().encode(input).document!.jpeg;
    expect(String.fromCharCodes(out), isNot(contains('PhoneMaker')));
  });

  test('quality then size are lowered until it fits; impossible caps report tooLarge', () {
    final input = _noisyJpeg(1600, 1200);
    final tight = const IdDocumentEncoder(maxBytes: 300 * 1024).encode(input);
    expect(tight.document, isNotNull);
    expect(tight.document!.jpeg.length, lessThanOrEqualTo(300 * 1024));
    final impossible = const IdDocumentEncoder(maxBytes: 100).encode(input);
    expect(impossible.issue, IdDocumentIssue.tooLarge);
  });

  test('garbage, empty and oversized input are unreadable', () {
    expect(const IdDocumentEncoder().encode(Uint8List.fromList([1, 2, 3, 4])).issue, IdDocumentIssue.unreadable);
    expect(const IdDocumentEncoder().encode(Uint8List(0)).issue, IdDocumentIssue.unreadable);
    expect(const IdDocumentEncoder(maxInputBytes: 10).encode(_noisyJpeg(64, 64)).issue, IdDocumentIssue.unreadable);
  });
}
