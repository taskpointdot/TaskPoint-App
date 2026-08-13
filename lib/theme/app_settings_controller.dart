import 'package:flutter/material.dart';

/// App-wide settings that need to be readable/changeable from anywhere in
/// the widget tree — currently theme mode (light/dark) and language
/// (English / Roman Urdu).
///
/// This is a plain singleton `ChangeNotifier` rather than a package like
/// `provider`, since the rest of the app doesn't use any state-management
/// package. `main.dart` listens to it with a `ListenableBuilder` around
/// `MaterialApp` so `themeMode` changes rebuild the whole app immediately;
/// any screen can also listen to it directly to react to language changes.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController._();
  static final AppSettingsController instance = AppSettingsController._();

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  bool _isEnglish = true;
  bool get isEnglish => _isEnglish;

  void setDarkMode(bool enabled) {
    final next = enabled ? ThemeMode.dark : ThemeMode.light;
    if (next == _themeMode) return;
    _themeMode = next;
    notifyListeners();
  }

  void setEnglish(bool english) {
    if (english == _isEnglish) return;
    _isEnglish = english;
    notifyListeners();
  }
}

/// Small helper for picking between an English and a Roman Urdu string
/// based on the current language setting, e.g.:
/// `t(context, en: 'Settings', ur: 'ترتیبات')`.
///
/// Kept deliberately simple (no codegen / .arb files) since only a
/// handful of screens are localized so far. Screens opt in by calling this
/// instead of hardcoding a string.
String t(BuildContext context, {required String en, required String ur}) {
  return AppSettingsController.instance.isEnglish ? en : ur;
}
