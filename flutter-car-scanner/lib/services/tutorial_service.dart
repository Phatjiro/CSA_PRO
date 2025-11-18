import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const String _keyTutorialCompleted = 'tutorial_completed';
  static const String _keyTutorialStep = 'tutorial_step';

  /// Check if tutorial has been completed
  static Future<bool> isTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTutorialCompleted) ?? false;
  }

  /// Mark tutorial as completed
  static Future<void> completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTutorialCompleted, true);
  }

  /// Reset tutorial (for testing or re-showing)
  static Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTutorialCompleted, false);
    await prefs.remove(_keyTutorialStep);
  }

  /// Get current tutorial step
  static Future<int> getCurrentStep() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTutorialStep) ?? 0;
  }

  /// Save current tutorial step
  static Future<void> saveStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTutorialStep, step);
  }
}

