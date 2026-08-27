import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';

/// Persists the user's language choice across app launches, mirroring
/// [ThemeProvider]'s pattern. `null` means "follow system" — falls back to
/// English for anything other than Chinese.
class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'app_locale';

  Locale? _locale;
  Locale? get locale => _locale;

  /// The effective language code, resolving "system" against the device
  /// locale so UI (e.g. a settings row) can show the active choice.
  String resolvedLanguageCode(BuildContext context) {
    if (_locale != null) return _locale!.languageCode;
    final deviceLang = View.of(context).platformDispatcher.locale.languageCode;
    return deviceLang == 'zh' ? 'zh' : 'en';
  }

  LocaleProvider() {
    _load();
    // Best-effort initial value for non-widget code (see
    // AppLocalizations.currentLanguageCode) — refined below once
    // shared_preferences finishes loading, and again on system default
    // via _load()/setLanguage().
    final deviceLang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    AppLocalizations.currentLanguageCode = deviceLang == 'zh' ? 'zh' : 'en';
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'en' || saved == 'zh') {
      _locale = Locale(saved!);
      AppLocalizations.currentLanguageCode = saved;
      notifyListeners();
    }
    // else: leave null -> MaterialApp falls back to system locale.
  }

  Future<void> setLanguage(String? languageCode) async {
    _locale = languageCode == null ? null : Locale(languageCode);
    AppLocalizations.currentLanguageCode = languageCode == 'zh' ? 'zh' : 'en';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (languageCode == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, languageCode);
    }
  }
}
