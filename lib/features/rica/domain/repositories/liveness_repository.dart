import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';

/// In production this is backed by a certified liveness/KYC vendor
/// (Smile Identity recommended — see docs/prompt-critique.md, fix #1),
/// never by google_mlkit_face_detection alone, which has no anti-spoofing.
abstract class LivenessRepository {
  Future<Either<Failure, bool>> verifyLiveness();
}
