import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _locale = 'en';

  ThemeMode get themeMode => _themeMode;
  String get locale => _locale;

  AppState({ThemeMode themeMode = ThemeMode.light, String locale = 'en'})
      : _themeMode = themeMode,
        _locale = locale;

  /// Load saved preferences. Call once at startup before runApp.
  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getString('themeMode') == 'dark';
    final locale = prefs.getString('locale') ?? 'en';
    return AppState(
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
    );
  }

  void toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'themeMode', _themeMode == ThemeMode.dark ? 'dark' : 'light');
  }

  void setLocale(String code) async {
    if (code == _locale) return;
    _locale = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', code);
  }
}
