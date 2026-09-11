enum AppFailureKind {
  startup,
  network,
  authentication,
  permission,
  storage,
  synchronization,
  unknown,
}

class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    required this.userMessage,
    this.retryable = true,
    this.cause,
    this.stackTrace,
  });

  final AppFailureKind kind;
  final String userMessage;
  final bool retryable;
  final Object? cause;
  final StackTrace? stackTrace;

  factory AppFailure.from(
    Object error, {
    StackTrace? stackTrace,
    AppFailureKind kind = AppFailureKind.unknown,
    String message = '処理を完了できませんでした。時間をおいて再試行してください。',
  }) {
    if (error is AppFailure) return error;
    return AppFailure(
      kind: kind,
      userMessage: message,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() => 'AppFailure($kind)';
}
