import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../util.dart';
import 'api.dart';

/// Rappels quotidiens programmés localement sur le téléphone.
///
/// Les défis des 7 prochains jours sont générés à l'avance côté serveur, ce qui permet
/// d'annoncer le thème exact dans la notification du matin, même application fermée.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Les rappels programmés n'existent que dans l'app Android (pas dans la version web).
  bool get isSupported => !kIsWeb;

  static const _kEnabled = 'notif_enabled';
  static const _kHour = 'notif_hour';
  static const _kMinute = 'notif_minute';
  static const _kVoteReminder = 'notif_vote';

  static const _channel = AndroidNotificationDetails(
    'daily_challenge',
    'Défi du jour',
    channelDescription: 'Le thème photo du jour et les rappels de vote',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFFFF4D8D),
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    }
    if (!isSupported) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_notification')),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications indisponibles : $e');
    }
  }

  Future<NotificationSettings> settings() async {
    final p = await SharedPreferences.getInstance();
    return NotificationSettings(
      enabled: p.getBool(_kEnabled) ?? true,
      hour: p.getInt(_kHour) ?? 9,
      minute: p.getInt(_kMinute) ?? 0,
      voteReminder: p.getBool(_kVoteReminder) ?? true,
    );
  }

  Future<void> save(NotificationSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, s.enabled);
    await p.setInt(_kHour, s.hour);
    await p.setInt(_kMinute, s.minute);
    await p.setBool(_kVoteReminder, s.voteReminder);
    await reschedule();
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Reprogramme toutes les notifications des 14 prochains jours.
  Future<void> reschedule() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final s = await settings();
      if (!s.enabled && !s.voteReminder) return;

      List<Map<String, dynamic>> upcoming = [];
      if (Api.myId != null) {
        try {
          upcoming = await Api.upcomingChallenges();
        } catch (_) {}
      }
      if (Api.myId == null) return;

      final byDay = <String, List<Map<String, dynamic>>>{};
      var voteHour = 20;
      for (final c in upcoming) {
        byDay.putIfAbsent(c['day'] as String, () => []).add(c);
        final vh = c['vote_hour'];
        if (vh is int && vh < voteHour) voteHour = vh;
      }

      final now = tz.TZDateTime.now(tz.local);
      for (var i = 0; i < 14; i++) {
        final date = DateTime(now.year, now.month, now.day + i);
        final dayKey = isoDay(date);

        if (s.enabled) {
          final when = tz.TZDateTime(tz.local, date.year, date.month, date.day, s.hour, s.minute);
          if (when.isAfter(now)) {
            final items = byDay[dayKey] ?? const [];
            final String title;
            final String body;
            if (items.isEmpty) {
              title = '📸 Nouveau défi du jour !';
              body = 'Ouvre Déclic pour découvrir le thème et poster ta photo.';
            } else if (items.length == 1) {
              title = '${items.first['group_emoji']} ${items.first['group_name']} · Défi du jour';
              body = '${items.first['emoji']} ${items.first['text']}';
            } else {
              title = '📸 Tes ${items.length} défis du jour';
              body = items.map((c) => '${c['group_emoji']} ${c['group_name']} : ${c['text']}').join('\n');
            }
            await _schedule(100 + i, when, title, body);
          }
        }

        if (s.voteReminder && byDay.containsKey(dayKey)) {
          final when = tz.TZDateTime(tz.local, date.year, date.month, date.day, voteHour, 30);
          if (when.isAfter(now)) {
            await _schedule(
              300 + i,
              when,
              '🗳️ Les votes sont ouverts !',
              'La plus drôle, la plus belle, la plus originale… à toi de juger avant minuit.',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur de programmation des notifications : $e');
    }
  }

  Future<void> _schedule(int id, tz.TZDateTime when, String title, String body) {
    return _plugin.zonedSchedule(
      id: id,
      scheduledDate: when,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.channelId,
          _channel.channelName,
          channelDescription: _channel.channelDescription,
          importance: _channel.importance,
          priority: _channel.priority,
          color: _channel.color,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }
}

class NotificationSettings {
  NotificationSettings({required this.enabled, required this.hour, required this.minute, required this.voteReminder});

  final bool enabled;
  final int hour;
  final int minute;
  final bool voteReminder;

  NotificationSettings copyWith({bool? enabled, int? hour, int? minute, bool? voteReminder}) => NotificationSettings(
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    voteReminder: voteReminder ?? this.voteReminder,
  );
}
