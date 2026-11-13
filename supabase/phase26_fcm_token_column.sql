-- Bildirimler baştan beri çalışmıyordu çünkü `profiles.fcm_token` kolonu
-- hiç var olmamıştı — notification_service.dart bu kolona token yazmaya
-- çalışıyor, hata sessizce yutuluyordu (bkz. lib/services/notification_service.dart
-- _saveTokenString: catch (_) {}). send-notification/send-event-reminders
-- fonksiyonları da aynı kolonu okuyup "column does not exist" hatasıyla
-- çöküyordu (2026-08-18'de canlı test sırasında keşfedildi).

alter table profiles add column if not exists fcm_token text;
