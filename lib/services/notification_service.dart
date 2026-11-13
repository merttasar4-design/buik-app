import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../config/brand.dart';
import 'supabase_service.dart';

/// Top-level handler — arka planda gelen FCM mesajları için zorunlu.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // OS zaten bildirimi gösteriyor; ek işlem gerekmez.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  static const _channelId = 'buik_default';
  static const _channelName = '${Brand.shortName} Bildirimleri';

  Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      // İzin iste (iOS)
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      // flutter_local_notifications başlat
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      await _local.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );

      // Android bildirim kanalı
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              importance: Importance.high,
            ),
          );

      // Uygulama açıkken gelen bildirimler için local notification göster
      FirebaseMessaging.onMessage.listen(_showLocalNotification);

      // Dinleyiciler token alınmadan ÖNCE kurulmalı: iOS'ta ilk getToken()
      // hata verirse bile sonradan gelen token/giriş kaçırılmasın.
      _messaging.onTokenRefresh.listen(_saveTokenString);

      // initialize() sadece app açılışında bir kez çalışır; o an kullanıcı
      // henüz login değilse _saveToken() sessizce atlanır. Login sonrasında
      // token'ın kaydedilmesini garantilemek için auth state'i dinle.
      supabase.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn) _saveToken();
      });

      await _saveToken();
    } catch (e) {
      // Bildirim kurulumu başarısız olsa da uygulama açılışını engellememeli.
      debugPrint('[push] kurulum hatası: $e');
    }
  }

  Future<void> _saveToken() async {
    try {
      // iOS'ta FCM token'ı APNs token'ına bağlı; APNs token açılıştan birkaç
      // saniye sonra geliyor ve gelmeden getToken() hata fırlatıyor.
      if (Platform.isIOS) {
        String? apns;
        for (var i = 0; i < 20 && apns == null; i++) {
          apns = await _messaging.getAPNSToken();
          if (apns == null) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
        if (apns == null) {
          debugPrint('[push] APNs token alınamadı (izin kapalı olabilir)');
          return;
        }
      }
      final token = await _messaging.getToken();
      debugPrint('[push] FCM token: ${token == null ? 'yok' : 'alındı'}');
      if (token != null) await _saveTokenString(token);
    } catch (e) {
      debugPrint('[push] token alınamadı: $e');
    }
  }

  Future<void> _saveTokenString(String token) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('[push] token kaydedilemedi: $e');
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
