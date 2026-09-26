/// Configuration injectée à la compilation :
///   flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Fuseau horaire du jeu (doit correspondre à app_today() dans supabase/schema.sql).
  static const gameTimezone = 'Europe/Paris';

  static const appName = 'Déclic';

  /// Lien profond vers l'app (à ajouter dans Supabase > Authentication > URL Configuration).
  static const authRedirectUrl = 'com.louistarwars.declic://login-callback/';
}
