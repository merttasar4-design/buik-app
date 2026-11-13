/// Supabase bağlantı ayarları derleme anında verilir:
///   flutter run --dart-define-from-file=env.json
/// Örnek için bkz. env.example.json
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
