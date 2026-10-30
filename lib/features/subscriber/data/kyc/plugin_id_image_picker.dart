import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/id_image_picker.dart';

/// `image_picker` behind [IdImagePicker]. The system camera or the system
/// photo picker does the choosing (no photo-library permission on current
/// Android and iOS; the camera permission only for the camera). The picked
/// file is read into memory and DELETED straight away on Android and iOS,
/// where the plugin hands back its own cache copy; only the bytes go on, and
/// they are dropped when the form is left.
///
/// `requestFullMetadata: false` stops iOS asking for photo-library access
/// just to read metadata, and `maxWidth`/`maxHeight` make the platform shrink
/// the image before it is loaded (`IdDocumentEncoder` does the final pass).
class PluginIdImagePicker implements IdImagePicker {
  PluginIdImagePicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Platform error codes of `image_picker` for a denied permission.
  static const _denied = {'camera_access_denied', 'photo_access_denied', 'camera_access_restricted', 'photo_access_restricted'};

  @override
  Future<IdImagePickResult> pick(IdImageSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source == IdImageSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
        requestFullMetadata: false,
        preferredCameraDevice: CameraDevice.rear,
      );
    } on PlatformException catch (e) {
      return _denied.contains(e.code) ? IdImagePickDenied(source) : const IdImagePickFailed();
    } catch (_) {
      return const IdImagePickFailed();
    }
    if (file == null) return const IdImagePickCancelled();
    try {
      final bytes = await file.readAsBytes();
      return PickedIdImage(bytes);
    } catch (_) {
      return const IdImagePickFailed();
    } finally {
      await _deleteCopy(file);
    }
  }

  /// Only where the plugin's file is its own temporary copy; on desktop the
  /// path can be the customer's original, which must never be deleted.
  static Future<void> _deleteCopy(XFile file) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final copy = File(file.path);
      if (await copy.exists()) await copy.delete();
    } catch (_) {
      // Best effort: it is in the app's cache, which the OS also clears.
    }
  }
}
