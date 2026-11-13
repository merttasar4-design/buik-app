import 'package:supabase_flutter/supabase_flutter.dart';

final SupabaseClient supabase = Supabase.instance.client;

/// Returns the current user's role ('member', 'coordinator', 'board', 'mezun'),
/// or null if signed out or no profile row exists yet.
Future<String?> fetchMyRole() async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;
  final row = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();
  return row?['role'] as String?;
}

bool isCoordinatorRole(String? role) =>
    role == 'coordinator' || role == 'board';

bool isBoardRole(String? role) => role == 'board';

bool isMezunRole(String? role) => role == 'mezun';

/// Supabase Auth (GoTrue) hata mesajları İngilizce gelir; uygulama arayüzü
/// Türkçe olduğu için bilinen mesajları çevirir, bilinmeyenleri genel bir
/// mesaja indirger (ham İngilizce/teknik metni kullanıcıya sızdırmamak için).
String translateAuthError(String message) {
  final m = message.toLowerCase();
  if (m.contains('invalid login credentials')) {
    return 'E-posta veya şifre hatalı.';
  }
  if (m.contains('email not confirmed')) {
    return 'E-postanızı henüz onaylamadınız. Gelen kutunuzu kontrol edin.';
  }
  if (m.contains('already registered') || m.contains('already exists')) {
    return 'Bu e-posta adresiyle zaten bir hesap var.';
  }
  if (m.contains('password should be at least')) {
    return 'Şifre en az 6 karakter olmalı.';
  }
  if (m.contains('rate limit') || m.contains('too many requests')) {
    return 'Çok fazla deneme yaptınız. Lütfen biraz sonra tekrar deneyin.';
  }
  if (m.contains('unable to validate email') || m.contains('invalid email')) {
    return 'Geçerli bir e-posta adresi girin.';
  }
  if (m.contains('token has expired') ||
      m.contains('invalid token') ||
      m.contains('otp_expired') ||
      m.contains('token is invalid')) {
    return 'Kod geçersiz veya süresi dolmuş. Yeni kod isteyin.';
  }
  if (m.contains('network')) {
    return 'Bağlantı hatası. İnternet bağlantınızı kontrol edin.';
  }
  return 'Bir hata oluştu. Lütfen tekrar deneyin.';
}
