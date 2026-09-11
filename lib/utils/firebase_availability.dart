abstract final class FirebaseAvailability {
  static bool _isReady = false;

  static bool get isReady => _isReady;

  static void markReady() => _isReady = true;

  static void markUnavailable() => _isReady = false;
}
