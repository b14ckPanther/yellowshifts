import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/app_config.dart';

/// Initializes core services before launching the root Flutter widget.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // Initialize Supabase Client
  try {
    // ignore: deprecated_member_use
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
      debug: kDebugMode,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[YellowShifts Bootstrap] Supabase initialization notice: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: YellowShiftsApp(),
    ),
  );
}
