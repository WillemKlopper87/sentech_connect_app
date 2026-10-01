/// A multi-request operation belongs to its starting session and tenant.
/// This guard is synchronous so interceptors can check immediately before
/// attaching credentials; rotating tokens within that session remains allowed.
class ApiOperationScope {
  ApiOperationScope(bool Function() isCurrent) : _isCurrent = isCurrent;
  final bool Function() _isCurrent;
  bool get isCurrent => _isCurrent();
}
