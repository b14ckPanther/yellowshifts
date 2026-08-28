import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_system/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'localization/locale_provider.dart';
import 'routing/app_router.dart';

class YellowShiftsApp extends ConsumerWidget {
  const YellowShiftsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'YellowShifts',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.buildTheme(localeCode: locale.languageCode),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
