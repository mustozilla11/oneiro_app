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
      title: 'Kahveden önce bir sır... ☕',
      body: 'Rüyalar uyandıktan 10 dakika sonra %90 silinir! Uçup gitmeden hemen günlüğüne mühürle.',
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
      body: 'Dün geceki rüyan zihninin derinliklerinden fısıldadı. Günlük silinmeden gel Oneiro\'ya yaz.',
    ),
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

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

      // Android 13+ bildirim izni iste
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Bildirim servisi başarıyla başlatıldı.');

      // Her sabah için sıralı bildirimi otomatik zamanla
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

  /// Cihazın yerel saatine göre her sabah 08:30 için sıradaki bildirimi zamanlar
  Future<void> scheduleNextMorningNotification() async {
    try {
      final index = await _getNextNotificationIndex();
      final item = notifications[index];

      final scheduledDate = _nextInstanceOfMorningTime(hour: 8, minute: 30);

      const androidDetails = AndroidNotificationDetails(
        'oneiro_morning_reminders',
        'Oneiro Sabah Rüya Hatırlatıcıları',
        channelDescription: 'Her sabah rüyanızı unutmadan tabir ettirmeniz için bilge fısıltılar',
        importance: Importance.high,
        priority: Priority.high,
        enableLights: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _notificationsPlugin.zonedSchedule(
        1001,
        item.title,
        item.body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('[NotificationService] Bildirim ($index: "${item.title}") ${scheduledDate.toLocal()} saatine zamanlandı.');
    } catch (e) {
      debugPrint('[NotificationService] Zamanlama hatası: $e');
    }
  }

  /// Belirlenen sabah saatini yerel saat diliminde hesaplar
  tz.TZDateTime _nextInstanceOfMorningTime({required int hour, required int minute}) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
