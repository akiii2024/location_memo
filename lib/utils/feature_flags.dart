abstract final class FeatureFlags {
  /// Public clients must never contain a Gemini API key. AI can only be
  /// enabled after it is moved behind an authenticated backend.
  static const bool aiEnabled = bool.fromEnvironment(
    'ENABLE_AI',
    defaultValue: false,
  );

  static const String recaptchaEnterpriseSiteKey = String.fromEnvironment(
    'RECAPTCHA_ENTERPRISE_SITE_KEY',
  );
}
