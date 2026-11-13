/// Oryantasyon karşılama ekranının gösterildiği tarih aralığı — sadece bu 3
/// gün boyunca (Boğaziçi Güney Kampüs stant günleri) uygulama açılışında
/// splash'tan sonra araya girer, aralık dışında hiç gösterilmez.
final DateTime orientationStart = DateTime(2026, 9, 21);
final DateTime orientationEnd = DateTime(2026, 9, 23, 23, 59, 59);

// GEÇİCİ — App Store review sürecinde reviewer'ın karşısına çıkmaması için
// ekran tamamen kapatıldı. Apple onayı gelince bu satırı kaldırıp tarih
// aralığına geri dön.
bool get isOrientationActive => false;
