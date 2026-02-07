import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLog extends ChangeNotifier {
  AppLog._();

  static final AppLog instance = AppLog._();

  static const String _prefsLinesKey = 'app_log_lines';
  static const String _prefsCrashKey = 'app_log_crash';
  static const int _defaultMaxLines = 200;
  static const List<String> _secretKeywords = <String>[
    'password',
    'secret',
    'token',
    'apikey',
    'api_key',
    'authorization',
  ];

  final List<String> _lines = <String>[];
  int _maxLines = _defaultMaxLines;
  bool _previousCrash = false;

  List<String> get lines => List<String>.unmodifiable(_lines);
  bool get previousCrash => _previousCrash;

  static Future<void> initialize({int maxLines = _defaultMaxLines}) async {
    await instance._load(maxLines);
  }

  Future<void> _load(int maxLines) async {
    _maxLines = maxLines;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _lines
      ..clear()
      ..addAll(prefs.getStringList(_prefsLinesKey) ?? <String>[]);
    _previousCrash = prefs.getBool(_prefsCrashKey) ?? false;
    await prefs.setBool(_prefsCrashKey, false);
    notifyListeners();
  }

  Future<void> add(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final DateTime now = DateTime.now();
    final StringBuffer buffer = StringBuffer(
      '[${now.toIso8601String()}] ${_sanitize(message)}',
    );
    if (error != null) {
      buffer.write('\nError: ${_sanitize(error.toString())}');
    }
    if (stackTrace != null) {
      buffer.write('\nStack: ${_sanitize(stackTrace.toString())}');
    }
    _lines.add(buffer.toString());
    _trim();
    await _persist();
    notifyListeners();
  }

  Future<void> e(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {
    await add(
      message,
      error: error ?? 'Unknown error',
      stackTrace: stackTrace,
    );
  }

  Future<void> clear() async {
    _lines.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _lines.join('\n')));
  }

  Future<void> markCrash() async {
    _previousCrash = true;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsCrashKey, true);
    notifyListeners();
  }

  void _trim() {
    if (_lines.length <= _maxLines) {
      return;
    }
    _lines.removeRange(0, _lines.length - _maxLines);
  }

  Future<void> _persist() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsLinesKey, _lines);
  }

  String _sanitize(String value) {
    String sanitized = value;
    for (final String keyword in _secretKeywords) {
      final RegExp pattern = RegExp(
        '(${RegExp.escape(keyword)}\\s*[:=]\\s*)([^\\s,;]+)',
        caseSensitive: false,
      );
      sanitized = sanitized.replaceAllMapped(
        pattern,
        (Match match) => '${match[1]}***',
      );
    }
    return sanitized;
  }
}
