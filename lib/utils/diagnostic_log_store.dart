import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DiagnosticLogEntry {
  const DiagnosticLogEntry({
    required this.occurredAt,
    required this.event,
    this.errorType,
  });

  final DateTime occurredAt;
  final String event;
  final String? errorType;

  Map<String, dynamic> toJson() => {
    'occurredAt': occurredAt.toIso8601String(),
    'event': event,
    if (errorType != null) 'errorType': errorType,
  };

  static DiagnosticLogEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final occurredAt = DateTime.tryParse(value['occurredAt']?.toString() ?? '');
    final event = value['event']?.toString();
    if (occurredAt == null || event == null || event.isEmpty) return null;
    return DiagnosticLogEntry(
      occurredAt: occurredAt,
      event: event,
      errorType: value['errorType']?.toString(),
    );
  }
}

/// A privacy-preserving local log. Callers provide a fixed event code; raw
/// messages, stack traces, paths and user content are deliberately excluded.
class DiagnosticLogStore {
  DiagnosticLogStore._();

  static final DiagnosticLogStore instance = DiagnosticLogStore._();
  static const _preferenceKey = 'anonymous_diagnostic_log_v1';
  static const _maximumEntries = 50;

  final List<DiagnosticLogEntry> _entries = [];
  SharedPreferences? _preferences;
  Future<void>? _initializing;

  Future<void> initialize() => _initializing ??= _load();

  Future<void> _load() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      final stored = _preferences?.getStringList(_preferenceKey) ?? const [];
      _entries
        ..clear()
        ..addAll(
          stored.map((item) {
            try {
              return DiagnosticLogEntry.fromJson(jsonDecode(item));
            } catch (_) {
              return null;
            }
          }).whereType<DiagnosticLogEntry>(),
        );
    } catch (_) {
      // Diagnostics must never prevent the application from starting.
    }
  }

  void record(String event, {Object? error}) {
    unawaited(_recordAndPersist(event, error));
  }

  Future<void> _recordAndPersist(String event, Object? error) async {
    await initialize();
    final safeEvent = event.replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
    final entry = DiagnosticLogEntry(
      occurredAt: DateTime.now().toUtc(),
      event: safeEvent,
      errorType: error?.runtimeType.toString(),
    );
    _entries.add(entry);
    if (_entries.length > _maximumEntries) {
      _entries.removeRange(0, _entries.length - _maximumEntries);
    }
    await _persist();
  }

  Future<List<DiagnosticLogEntry>> readAll() async {
    await initialize();
    return List.unmodifiable(_entries.reversed);
  }

  Future<void> clear() async {
    await initialize();
    _entries.clear();
    await _preferences?.remove(_preferenceKey);
  }

  Future<void> _persist() async {
    await initialize();
    try {
      await _preferences?.setStringList(
        _preferenceKey,
        _entries.map((entry) => jsonEncode(entry.toJson())).toList(),
      );
    } catch (_) {
      // A full or unavailable preference store is non-fatal.
    }
  }
}
