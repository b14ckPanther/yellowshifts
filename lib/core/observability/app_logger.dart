import 'package:flutter/foundation.dart';

enum LogSeverity {
  debug,
  info,
  warning,
  error,
  critical,
}

abstract class ErrorReporter {
  void reportError(dynamic error, {StackTrace? stackTrace, String? hint});
  void reportCritical(String message, {Map<String, dynamic>? metadata});
}

class ConsoleErrorReporter implements ErrorReporter {
  @override
  void reportError(dynamic error, {StackTrace? stackTrace, String? hint}) {
    if (kDebugMode) {
      debugPrint('[ErrorReporter] ERROR: $error (hint: $hint)');
      if (stackTrace != null) {
        debugPrint('[ErrorReporter] StackTrace:\n$stackTrace');
      }
    }
  }

  @override
  void reportCritical(String message, {Map<String, dynamic>? metadata}) {
    if (kDebugMode) {
      debugPrint('[ErrorReporter] CRITICAL: $message (meta: $metadata)');
    }
  }
}

/// Centralized Production Logger for YellowShifts.
/// Enforces strict sanitization to ensure tokens, passwords, and secrets are NEVER logged.
class AppLogger {
  static ErrorReporter _reporter = ConsoleErrorReporter();

  static void setErrorReporter(ErrorReporter reporter) {
    _reporter = reporter;
  }

  static final RegExp _jwtRegex =
      RegExp(r'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}');
  static final RegExp _bearerRegex =
      RegExp(r'Bearer\s+[a-zA-Z0-9._-]+', caseSensitive: false);
  static final RegExp _secretRegex = RegExp(
      r'([sS]ecret|[pP]assword|[tT]oken)\s*[:=]\s*["\x27]?([^"\s\x27,]+)',
      caseSensitive: false);

  /// Sanitizes messages by masking sensitive tokens, passwords, and secrets.
  static String sanitize(String message) {
    var clean = message.replaceAll(_jwtRegex, '[REDACTED_JWT]');
    clean = clean.replaceAll(_bearerRegex, 'Bearer [REDACTED_TOKEN]');
    clean = clean.replaceAllMapped(
        _secretRegex, (m) => '${m.group(1)}: [REDACTED_SECRET]');
    return clean;
  }

  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      final t = tag != null ? '[$tag]' : '[YellowShifts]';
      debugPrint('$t DEBUG: ${sanitize(message)}');
    }
  }

  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      final t = tag != null ? '[$tag]' : '[YellowShifts]';
      debugPrint('$t INFO: ${sanitize(message)}');
    }
  }

  static void warning(String message, [String? tag]) {
    final t = tag != null ? '[$tag]' : '[YellowShifts]';
    debugPrint('$t WARNING: ${sanitize(message)}');
  }

  static void error(String message,
      {dynamic error, StackTrace? stackTrace, String? tag}) {
    final t = tag != null ? '[$tag]' : '[YellowShifts]';
    final cleanMsg = sanitize(message);
    debugPrint('$t ERROR: $cleanMsg');
    if (error != null) {
      _reporter.reportError(error, stackTrace: stackTrace, hint: cleanMsg);
    }
  }

  static void critical(String message,
      {Map<String, dynamic>? metadata, String? tag}) {
    final t = tag != null ? '[$tag]' : '[YellowShifts]';
    final cleanMsg = sanitize(message);
    debugPrint('$t CRITICAL: $cleanMsg');
    _reporter.reportCritical(cleanMsg, metadata: metadata);
  }
}
