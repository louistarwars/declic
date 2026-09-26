import 'package:flutter/foundation.dart';

/// Configuration injectée à la compilation :
///   flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Fuseau horaire du jeu (doit correspondre à app_today() dans supabase/schema.sql).
  static const gameTimezone = 'Europe/Paris';

  static const appName = 'Déclic';

  /// Version web (PWA) pour les iPhone, hébergée sur GitHub Pages.
  static const webAppUrl = 'https://louistarwars.github.io/declic/';

  /// Dernier APK Android.
  static const androidDownloadUrl = 'https://github.com/louistarwars/declic/releases/latest';

  /// Retour après un lien reçu par e-mail (à autoriser dans Supabase > Authentication > URL Configuration).
  static String get authRedirectUrl =>
      kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : 'com.louistarwars.declic://login-callback/';
}
