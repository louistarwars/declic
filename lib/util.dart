import 'package:timezone/timezone.dart' as tz;

import 'config.dart';

/// Heure actuelle dans le fuseau du jeu (Europe/Paris).
DateTime gameNow() {
  try {
    return tz.TZDateTime.now(tz.getLocation(AppConfig.gameTimezone));
  } catch (_) {
    return DateTime.now();
  }
}

String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Temps restant jusqu'à une heure donnée (aujourd'hui, heure du jeu).
Duration untilGameHour(int hour) {
  final now = gameNow();
  final target = DateTime(now.year, now.month, now.day, hour);
  final nowNaive = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);
  return target.difference(nowNaive);
}

/// Temps restant jusqu'à minuit (heure du jeu).
Duration untilMidnight() {
  final now = gameNow();
  final nowNaive = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);
  return DateTime(now.year, now.month, now.day + 1).difference(nowNaive);
}

String formatDuration(Duration d) {
  if (d.isNegative) return '0 min';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}';
  if (m > 0) return '$m min';
  return '${d.inSeconds} s';
}

const monthNames = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

const weekdayNames = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

String seasonName(DateTime month) => 'Saison ${monthNames[month.month - 1]} ${month.year}';

String prettyDay(DateTime d) {
  final today = gameNow();
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff == 0) return "Aujourd'hui";
  if (diff == 1) return 'Hier';
  final wd = weekdayNames[d.weekday - 1];
  return '${wd[0].toUpperCase()}${wd.substring(1)} ${d.day} ${monthNames[d.month - 1].toLowerCase()}';
}
