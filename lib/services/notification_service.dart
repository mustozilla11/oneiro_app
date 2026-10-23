import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class DreamNotificationItem {
  final String title;
  final String body;

  const DreamNotificationItem({
    required this.title,
    required this.body,
  });
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  static const String _prefNotificationIndexKey = 'oneiro_notification_seq_index';

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// 10 Farklı Sıralı Sabah ve Merak Uyandırıcı Rüya Bildirimi
  static const List<DreamNotificationItem> notifications = [
    DreamNotificationItem(
      title: 'Bilinçaltın seni arıyor... 👀',
      body: 'Uyanma vakti! Bu gece rüyanda kim vardı öyle? Aklındayken gel hemen tabirine bakalım.',
    ),
    DreamNotificationItem(
      title: 'Gizemli Biri 🤫',
      body: 'Günaydınnn... Az önce gördüğün rüyayı hala hatırlıyorken gel bana anlat, aramızda kalacak 🌙',
    ),
    DreamNotificationItem(
      title: 'Kahveden önce... ☕',
      body: 'Rüyalar uyandıktan 10 dakika sonra %90 unutulur! Unutmadan hemen günlüğüne kaydet.',
    ),
    DreamNotificationItem(
      title: 'Kaderinden bir işaret mi? 📜',
      body: 'Dün gece gördüğün sembol tesadüf değildi. Kadim bilgelik senin için ne fısıldıyor?',
    ),
    DreamNotificationItem(
      title: 'Carl Jung fısıldıyor... 🧠',
      body: '“Dışarı bakan rüya görür, içeri bakan uyanır.” Bu gece bilinçaltın hangi arketipi seçti?',
    ),
    DreamNotificationItem(
      title: 'Gözlerini açtın mı? ✨',
      body: 'O hissi hala taşıyorsun değil mi? Rüyadaki o kapının arkasında ne olduğunu çözme vakti.',
    ),
    DreamNotificationItem(
      title: 'Günün Kozmik Pusulası 🧭',
      body: 'Rüyalar evrenin sana gönderdiği şifreli mektuplardır. Mührü kırmaya hazır mısın?',
    ),
    DreamNotificationItem(
      title: 'Psikolojik Aynan Hazır 🪞',
      body: 'Gece zihninde canlanan gölgeler sana bir şey anlatmak istiyor. Gel birlikte tercüme edelim.',
    ),
    DreamNotificationItem(
      title: 'Antik Akdeniz Kehaneti 🏛️',
      body: 'Artemidorus der ki: “Sabahın ilk ışığıyla hatırlanan rüya, günün pusulasıdır.” Gel tabirini aç.',
    ),
    DreamNotificationItem(
      title: 'Sessiz bir mesajın var 🌙',
      body: 'Dün geceki rüyan zihninin derinliklerinden fısıldadı. Günlük silinmeden gel DreamApp\'e yaz.',
    ),
  ];

  /// Cihazın gerçek saat dilimi farkına (UTC offset) göre doğru tz.Location nesnesini ayarlar.
  /// Böylece tz.local varsayılan UTC'de kalmaz ve 08:30 alarmı tam olarak telefonun yerel saatinde 08:30'da çalar.
  void _configureLocalTimeZone() {
    tz.initializeTimeZones();
    final offset = DateTime.now().timeZoneOffset;

    // Türkiye ve UTC+3 için doğrudan Europe/Istanbul önceliği
    if (offset.inMinutes == 180) {
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
        return;
      } catch (_) {}
    }

    // Tüm bilinen saat dilimleri arasından cihazın şu anki UTC offset'i ile eşleşeni bul
    final nowUtc = DateTime.now().toUtc();
    for (final loc in tz.timeZoneDatabase.locations.values) {
      final tzNow = tz.TZDateTime.from(nowUtc, loc);
      if (tzNow.timeZoneOffset == offset) {
        tz.setLocalLocation(loc);
        debugPrint('[NotificationService] Yerel saat dilimi ayarlandı: ${loc.name} (Offset: $offset)');
        return;
      }
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _configureLocalTimeZone();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('[NotificationService] Bildirime tıklandı: ${details.payload}');
        },
      );

      // Android 13+ bildirim izni ve Android 12+ tam saat (exact alarm) izni iste
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        try {
          await androidImplementation.requestExactAlarmsPermission();
        } catch (_) {}
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Bildirim servisi başarıyla başlatıldı.');

      // Her sabah 08:30 için sıralı bildirimi otomatik zamanla
      await scheduleNextMorningNotification();
    } catch (e) {
      debugPrint('[NotificationService] Başlatma hatası: $e');
    }
  }

  /// Sıradaki bildirimin indeksini alır ve döngüsel olarak artırır
  Future<int> _getNextNotificationIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int currentIndex = prefs.getInt(_prefNotificationIndexKey) ?? 0;
      int nextIndex = (currentIndex + 1) % notifications.length;
      await prefs.setInt(_prefNotificationIndexKey, nextIndex);
      return currentIndex;
    } catch (_) {
      return 0;
    }
  }

  static const String _prefMorningReminderEnabledKey = 'oneiro_morning_reminder_enabled';

  /// Sabah hatırlatıcısının açık olup olmadığını döner (Varsayılan: true)
  Future<bool> isMorningReminderEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefMorningReminderEnabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Sabah hatırlatıcısını açar veya kapatır
  Future<void> setMorningReminderEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefMorningReminderEnabledKey, enabled);
      if (enabled) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          await androidImplementation.requestNotificationsPermission();
          try {
            await androidImplementation.requestExactAlarmsPermission();
          } catch (_) {}
        }
        await scheduleNextMorningNotification();
      } else {
        await _notificationsPlugin.cancel(1001);
        debugPrint('[NotificationService] Sabah hatırlatıcısı kapatıldı.');
      }
    } catch (e) {
      debugPrint('[NotificationService] setMorningReminderEnabled hatası: $e');
    }
  }

  /// Kullanıcının seçtiği dile göre sabah bildirim metnini döner
  DreamNotificationItem _getLocalizedNotification(int index, String lang) {
    if (lang == 'tr') {
      return notifications[index % notifications.length];
    }
    const localizedByLang = <String, DreamNotificationItem>{
      'en': DreamNotificationItem(
        title: 'Morning Dream Reminder (08:30) 🌙',
        body: '90% of dreams fade within 10 minutes of waking! Write your dream now to analyze it from 11 source books.',
      ),
      'es': DreamNotificationItem(
        title: 'Recordatorio de Sueños (08:30) 🌙',
        body: '¡El 90% de los sueños se olvidan en 10 minutos! Anota tu sueño ahora para analizarlo.',
      ),
      'ar': DreamNotificationItem(
        title: 'تذكير الرؤى الصباحي (08:30) 🌙',
        body: 'تُنسى الأحلام سريعاً بعد الاستيقاظ! دوّن حلمك الآن لتفسيره من أمهات الكتب.',
      ),
      'de': DreamNotificationItem(
        title: 'Morgendliche Traumerinnerung (08:30) 🌙',
        body: '90 % aller Träume verblassen kurz nach dem Aufwachen! Notiere deinen Traum jetzt im Tagebuch.',
      ),
      'fr': DreamNotificationItem(
        title: 'Rappel de Rêve Matinal (08:30) 🌙',
        body: 'Les rêves s’effacent rapidement au réveil ! Notez votre rêve dès maintenant pour l’analyser.',
      ),
      'pt': DreamNotificationItem(
        title: 'Lembrete Matinal de Sonhos (08:30) 🌙',
        body: '90% dos sonhos são esquecidos 10 minutos após acordar! Anote seu sonho agora.',
      ),
      'ru': DreamNotificationItem(
        title: 'Утреннее напоминание о сне (08:30) 🌙',
        body: '90% снов забываются через 10 минут после пробуждения! Запишите свой сон прямо сейчас.',
      ),
      'hi': DreamNotificationItem(
        title: 'सुबह का सपना स्मरण (08:30) 🌙',
        body: 'जागने के 10 मिनट बाद 90% सपने भूल जाते हैं! अपना सपना अभी दर्ज करें।',
      ),
      'zh': DreamNotificationItem(
        title: '晨间梦境提醒 (08:30) 🌙',
        body: '醒来10分钟后90%的梦境会被遗忘！趁记忆清晰，立即记录并解析您的梦境。',
      ),
    };
    return localizedByLang[lang] ?? localizedByLang['en']!;
  }

  /// Bildirim sisteminin çalıştığını anında doğrulamak için test bildirimi gönderir
  Future<void> showInstantTestNotification({String lang = 'tr'}) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      const androidDetails = AndroidNotificationDetails(
        'oneiro_morning_reminders',
        'DreamApp Sabah Rüya Hatırlatıcıları',
        channelDescription: 'Her sabah 08:30 rüya hatırlatma bildirimleri',
        importance: Importance.max,
        priority: Priority.high,
        enableLights: true,
        playSound: true,
      );
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      final item = _getLocalizedNotification(0, lang);
      await _notificationsPlugin.show(
        1002,
        item.title,
        item.body,
        notificationDetails,
      );
    } catch (e) {
      debugPrint('[NotificationService] Test bildirimi hatası: $e');
    }
  }

  /// Cihazın yerel saatine göre her sabah 08:30 için sıradaki bildirimi zamanlar
  Future<void> scheduleNextMorningNotification() async {
    try {
      final enabled = await isMorningReminderEnabled();
      if (!enabled) return;

      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('oneiro_selected_language') ?? 'tr';

      final index = await _getNextNotificationIndex();
      final item = _getLocalizedNotification(index, savedLang);

      final scheduledDate = _nextInstanceOfMorningTime(hour: 8, minute: 30);

      const androidDetails = AndroidNotificationDetails(
        'oneiro_morning_reminders',
        'DreamApp Sabah Rüya Hatırlatıcıları',
        channelDescription: 'Her sabah 08:30 rüya hatırlatma bildirimleri',
        importance: Importance.max,
        priority: Priority.high,
        enableLights: true,
        playSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      // Önce tam saat (exactAllowWhileIdle) ile zamanlamayı dene, izin kısıtlıysa inexactAllowWhileIdle kullan
      try {
        await _notificationsPlugin.zonedSchedule(
          1001,
          item.title,
          item.body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {
        await _notificationsPlugin.zonedSchedule(
          1001,
          item.title,
          item.body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      debugPrint('[NotificationService] Sabah 08:30 alarmı (${scheduledDate.toString()}) için aktif edildi.');
    } catch (e) {
      debugPrint('[NotificationService] Zamanlama hatası: $e');
    }
  }

  /// Belirlenen sabah saatini (08:30) doğrudan telefonun yerel saatine göre hesaplar
  tz.TZDateTime _nextInstanceOfMorningTime({required int hour, required int minute}) {
    final nowLocal = DateTime.now();
    DateTime targetLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, hour, minute);
    if (!targetLocal.isAfter(nowLocal)) {
      targetLocal = targetLocal.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(targetLocal, tz.local);
  }
}
