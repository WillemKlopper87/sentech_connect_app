import 'dart:typed_data';

enum IdImageSource { camera, gallery }

/// Outcome of asking the customer for a photo. The picker has already removed
/// any file it created: only [PickedIdImage.bytes] remains, in memory.
sealed class IdImagePickResult {
  const IdImagePickResult();
}

class PickedIdImage extends IdImagePickResult {
  const PickedIdImage(this.bytes);
  final Uint8List bytes;
}

/// The customer closed the camera or gallery without choosing.
class IdImagePickCancelled extends IdImagePickResult {
  const IdImagePickCancelled();
}

/// The camera or photos permission is denied (or restricted); the form offers
/// the gallery and a link to the system settings.
class IdImagePickDenied extends IdImagePickResult {
  const IdImagePickDenied(this.source);
  final IdImageSource source;
}

class IdImagePickFailed extends IdImagePickResult {
  const IdImagePickFailed();
}

/// Seam over `image_picker` so cubit and widget tests need no platform plugin.
abstract interface class IdImagePicker {
  Future<IdImagePickResult> pick(IdImageSource source);
}
