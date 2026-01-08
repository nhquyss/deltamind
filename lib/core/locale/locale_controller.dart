import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locale state
class LocaleState {
  final Locale locale;

  LocaleState(this.locale);
}

/// Locale controller provider
final localeControllerProvider =
    StateNotifierProvider<LocaleController, LocaleState>((ref) {
  return LocaleController();
});

/// Controller for managing app locale
class LocaleController extends StateNotifier<LocaleState> {
  static const String _localeKey = 'app_locale';

  LocaleController() : super(LocaleState(const Locale('en', ''))) {
    _loadLocale();
  }

  /// Load saved locale from preferences
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_localeKey);

      if (localeCode != null) {
        final parts = localeCode.split('_');
        state = LocaleState(Locale(parts[0], parts.length > 1 ? parts[1] : ''));
      } else {
        // Default to system locale or English
        state = LocaleState(const Locale('en', ''));
      }
    } catch (e) {
      // If error, default to English
      state = LocaleState(const Locale('en', ''));
    }
  }

  /// Change locale
  Future<void> setLocale(Locale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _localeKey, '${locale.languageCode}_${locale.countryCode ?? ''}');
      state = LocaleState(locale);
    } catch (e) {
      // Handle error silently
      debugPrint('Error saving locale: $e');
    }
  }

  /// Get current locale
  Locale get currentLocale => state.locale;
}
