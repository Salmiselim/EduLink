import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Statut retourné par l'API Calendrier pour une date donnée.
class CalendarDayInfo {
  final DateTime date;
  final String formattedDate;
  final bool isHoliday;
  final String? holidayName;
  final bool isWeekend;

  const CalendarDayInfo({
    required this.date,
    required this.formattedDate,
    this.isHoliday = false,
    this.holidayName,
    this.isWeekend = false,
  });

  String get statusLabel {
    if (isHoliday) {
      return 'Jour férié en Tunisie : ${holidayName ?? "Férié officiel"}';
    }
    if (isWeekend) {
      return 'Week-end — Créneau de révision intensif';
    }
    return 'Jour ouvrable universitaire — Disponible';
  }
}

/// Service d'intégration de l'API Calendrier pour la Marketplace (Module M5) :
/// 1. Interroge l'API REST publique Nager.Date (`https://date.nager.at/api/v3/PublicHolidays/{year}/TN`)
///    pour détecter les jours fériés tunisiens (avec cache et repli hors-ligne).
/// 2. Garantit que toutes les dates de créneaux (`availabilities`) commencent au minimum
///    à la date d'aujourd'hui (`DateTime.now()`), interdisant toute date passée.
/// 3. Génère et ouvre des événements Google Calendar (`calendar.google.com/calendar/render`)
///    pré-remplis avec l'horaire du créneau, le lien Jitsi Meet et l'adresse OpenStreetMap.
class CalendarApiService {
  const CalendarApiService();

  static const List<String> _weekdaysShort = [
    'Lun',
    'Mar',
    'Mer',
    'Jeu',
    'Ven',
    'Sam',
    'Dim',
  ];

  static const List<String> _monthsShort = [
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Août',
    'Sep',
    'Oct',
    'Nov',
    'Déc',
  ];

  /// Cache en mémoire des jours fériés par année (`year -> { "MM-dd": "Nom du jour férié" }`).
  static final Map<int, Map<String, String>> _holidaysCache = {};

  /// Jours fériés fixes en Tunisie (repli instantané si hors-ligne).
  static const Map<String, String> _fixedTunisianHolidays = {
    '01-01': 'Nouvel An',
    '03-20': 'Fête de l\'Indépendance',
    '04-09': 'Journée des Martyrs',
    '05-01': 'Fête du Travail',
    '07-25': 'Fête de la République',
    '08-13': 'Fête de la Femme',
    '10-15': 'Fête de l\'Évacuation',
    '12-17': 'Fête de la Révolution',
  };

  /// Retourne la date d'aujourd'hui normalisée à minuit (`00:00:00`).
  static DateTime todayNormalized() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Formate un [DateTime] au format standard de la Marketplace (ex: `Mar 10 Nov 2026`).
  static String formatSlotDate(DateTime date) {
    final wd = _weekdaysShort[(date.weekday - 1).clamp(0, 6)];
    final month = _monthsShort[(date.month - 1).clamp(0, 11)];
    final day = date.day.toString().padLeft(2, '0');
    return '$wd $day $month ${date.year}';
  }

  /// Retourne une date formatée décalée de [daysFromToday] jours à partir d'aujourd'hui.
  static String formatRelativeDay(int daysFromToday) {
    final target = todayNormalized().add(Duration(days: daysFromToday));
    return formatSlotDate(target);
  }

  /// Tente de convertir une chaîne (ex: `Mar 10 Nov 2026`) en [DateTime].
  static DateTime? parseSlotDate(String raw) {
    final cleaned = raw.trim();
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length < 3) return null;
    // Format attendu : [JourSemaine, JJ, Mois, AAAA] ou [JJ, Mois, AAAA]
    final offset = parts.length >= 4 ? 1 : 0;
    final day = int.tryParse(parts[offset]);
    final monthStr = parts[offset + 1].toLowerCase();
    final year = int.tryParse(parts[offset + 2]);
    if (day == null || year == null) return null;

    int? month;
    for (int i = 0; i < _monthsShort.length; i++) {
      final m = _monthsShort[i].toLowerCase();
      if (monthStr.startsWith(m) ||
          (i == 1 && monthStr.startsWith('fev')) ||
          (i == 7 && monthStr.startsWith('aou')) ||
          (i == 11 && monthStr.startsWith('dec'))) {
        month = i + 1;
        break;
      }
    }
    if (month == null) return null;
    return DateTime(year, month, day);
  }

  /// Vérifie si une date textuelle est antérieure à aujourd'hui.
  static bool isPastDateString(String raw) {
    final parsed = parseSlotDate(raw);
    if (parsed == null) return false;
    return parsed.isBefore(todayNormalized());
  }

  /// Interroge l'API publique Nager.Date (`GET https://date.nager.at/api/v3/PublicHolidays/{year}/TN`)
  /// pour vérifier si [date] est un jour férié en Tunisie ou un week-end.
  Future<CalendarDayInfo> inspectDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final holidays = await _fetchHolidaysForYear(normalized.year);
    final key =
        '${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
    final holidayName = holidays[key];
    final isWeekend = normalized.weekday == DateTime.saturday ||
        normalized.weekday == DateTime.sunday;

    return CalendarDayInfo(
      date: normalized,
      formattedDate: formatSlotDate(normalized),
      isHoliday: holidayName != null,
      holidayName: holidayName,
      isWeekend: isWeekend,
    );
  }

  Future<Map<String, String>> _fetchHolidaysForYear(int year) async {
    if (_holidaysCache.containsKey(year)) {
      return _holidaysCache[year]!;
    }
    final result = Map<String, String>.from(_fixedTunisianHolidays);
    try {
      final uri = Uri.https(
        'date.nager.at',
        '/api/v3/PublicHolidays/$year/TN',
      );
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final dateStr = map['date'] as String?; // "YYYY-MM-DD"
          final localName =
              (map['name'] ?? map['localName']) as String? ?? 'Jour férié';
          if (dateStr != null && dateStr.length >= 10) {
            final mmDd = dateStr.substring(5, 10);
            result[mmDd] = localName;
          }
        }
      }
    } catch (_) {
      // Repli silencieux sur les jours fériés fixes en cas d'absence de réseau
    }
    _holidaysCache[year] = result;
    return result;
  }

  /// Construit l'URL Google Calendar (`https://calendar.google.com/calendar/render`)
  /// pour un créneau horaire donné (`dateLabel`, `startTime`, `endTime`).
  static Uri buildGoogleCalendarUri({
    required String title,
    required String dateLabel,
    required String startTime,
    required String endTime,
    String? description,
    String? location,
  }) {
    final baseDate = parseSlotDate(dateLabel) ?? todayNormalized();
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    final sh = int.tryParse(startParts.first) ?? 14;
    final sm = startParts.length > 1 ? (int.tryParse(startParts[1]) ?? 0) : 0;
    final eh = int.tryParse(endParts.first) ?? (sh + 1);
    final em = endParts.length > 1 ? (int.tryParse(endParts[1]) ?? 0) : 0;

    final startDt = DateTime(baseDate.year, baseDate.month, baseDate.day, sh, sm);
    final endDt = DateTime(baseDate.year, baseDate.month, baseDate.day, eh, em);

    String fmt(DateTime d) {
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      final h = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '$y$m${day}T$h${min}00';
    }

    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'EduLink · $title',
      'dates': '${fmt(startDt)}/${fmt(endDt)}',
      if (description != null && description.isNotEmpty) 'details': description,
      if (location != null && location.isNotEmpty) 'location': location,
    });
  }

  /// Ouvre Google Calendar avec les informations d'un créneau réservé (format `Date · HH:mm - HH:mm`).
  static Future<bool> openGoogleCalendarSlot({
    required String title,
    required String slotLabel,
    String? description,
    String? location,
  }) async {
    String datePart = formatRelativeDay(0);
    String startPart = '14:00';
    String endPart = '15:00';

    if (slotLabel.contains('·')) {
      final segments = slotLabel.split('·');
      datePart = segments.first.trim();
      final times = segments.last.split('-');
      if (times.isNotEmpty) startPart = times.first.trim();
      if (times.length > 1) endPart = times.last.trim();
    } else {
      datePart = slotLabel.trim();
    }

    final uri = buildGoogleCalendarUri(
      title: title,
      dateLabel: datePart,
      startTime: startPart,
      endTime: endPart,
      description: description,
      location: location,
    );

    return launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
  }
}
