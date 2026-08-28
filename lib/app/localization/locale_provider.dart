import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('he'));

  void setLocale(Locale newLocale) {
    if (newLocale.languageCode == 'he' || newLocale.languageCode == 'en') {
      state = newLocale;
    }
  }

  void toggleLocale() {
    if (state.languageCode == 'he') {
      state = const Locale('en');
    } else {
      state = const Locale('he');
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
