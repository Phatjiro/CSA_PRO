import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/prefs_keys.dart';

class AppSettings {
  AppSettings._();

  static const int _defaultPollInterval = 1000;
  static SharedPreferences? _prefs;

  static final ValueNotifier<int> pollIntervalMs =
      ValueNotifier<int>(_defaultPollInterval);

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getInt(PrefsKeys.pollIntervalMs);
    pollIntervalMs.value = saved != null && saved >= 300 && saved <= 5000
        ? saved
        : _defaultPollInterval;
  }

  static Future<void> setPollInterval(int milliseconds) async {
    final clamped = milliseconds.clamp(300, 5000);
    pollIntervalMs.value = clamped;
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setInt(PrefsKeys.pollIntervalMs, clamped);
  }

  static int get defaultPollInterval => _defaultPollInterval;
}

