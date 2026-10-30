import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A photo shrunk and re-encoded for upload.
class EncodedIdDocument {
  const EncodedIdDocument(this.jpeg);

  /// The JPEG bytes (also what the preview shows: the customer sees what is sent).
  final Uint8List jpeg;

  String get base64 => base64Encode(jpeg);
}

enum IdDocumentIssue {
  /// Not an image the device can decode.
  unreadable,

  /// Could not be brought under the size cap even at the smallest setting.
  tooLarge,
}

/// Pure image preparation for the ID document (platform: base64 string, JPEG,
/// PNG or PDF, decoded at most 5 MiB). Decodes, applies the EXIF rotation,
/// flattens transparency onto white, scales the long edge down to
/// [maxEdge] and re-encodes as JPEG. Re-encoding drops all metadata
/// (location, device) from the file that leaves the phone. If the result is
/// still over [maxBytes] it lowers the quality, then the size, until it fits.
///
/// CPU-heavy on a large photo: callers run [encode] off the UI isolate
/// (`compute`).
class IdDocumentEncoder {
  const IdDocumentEncoder({
    this.maxEdge = 2000,
    this.quality = 80,
    this.maxBytes = 4 * 1024 * 1024,
    this.maxInputBytes = 40 * 1024 * 1024,
  });

  final int maxEdge;
  final int quality;

  /// Cap on the JPEG (the platform allows 5 MiB; 4 MB leaves headroom).
  final int maxBytes;

  /// Inputs bigger than this are refused before decoding (memory).
  final int maxInputBytes;

  static const _minQuality = 50;
  static const _minEdge = 800;

  /// Returns the encoded document or the reason it cannot be used.
  ({EncodedIdDocument? document, IdDocumentIssue? issue}) encode(Uint8List input) {
    if (input.isEmpty || input.length > maxInputBytes) {
      return (document: null, issue: IdDocumentIssue.unreadable);
    }
    img.Image? decoded;
    try {
      decoded = img.decodeImage(input);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null || decoded.width < 1 || decoded.height < 1) {
      return (document: null, issue: IdDocumentIssue.unreadable);
    }
    var image = img.bakeOrientation(decoded);
    if (image.hasAlpha) {
      final background = img.Image(width: image.width, height: image.height, numChannels: 3)
        ..clear(img.ColorRgb8(255, 255, 255));
      img.compositeImage(background, image);
      image = background;
    }
    var edge = maxEdge;
    var q = quality;
    while (true) {
      final scaled = _scaled(image, edge);
      scaled.exif = img.ExifData(); // no location or device metadata leaves the phone
      final bytes = Uint8List.fromList(img.encodeJpg(scaled, quality: q));
      if (bytes.length <= maxBytes) return (document: EncodedIdDocument(bytes), issue: null);
      if (q > _minQuality) {
        q = (q - 10).clamp(_minQuality, 100);
      } else if (edge > _minEdge) {
        edge = (edge * 0.8).round().clamp(_minEdge, maxEdge);
      } else {
        return (document: null, issue: IdDocumentIssue.tooLarge);
      }
    }
  }

  static img.Image _scaled(img.Image image, int edge) {
    final longest = image.width > image.height ? image.width : image.height;
    if (longest <= edge) return image;
    return image.width >= image.height
        ? img.copyResize(image, width: edge, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: edge, interpolation: img.Interpolation.average);
  }
}
