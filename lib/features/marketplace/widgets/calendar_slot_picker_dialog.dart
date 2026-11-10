import 'package:flutter/material.dart';

import '../services/calendar_api_service.dart';

/// Résultat retourné par le sélecteur de calendrier interactif.
class PickedCalendarSlot {
  final String dateLabel;
  final String startTime;
  final String endTime;
  final CalendarDayInfo? dayInfo;

  const PickedCalendarSlot({
    required this.dateLabel,
    required this.startTime,
    required this.endTime,
    this.dayInfo,
  });
}

/// Feuille modale / boîte de dialogue combinant :
/// - Un calendrier interactif [CalendarDatePicker] verrouillé à partir d'aujourd'hui
///   (`firstDate = DateTime.now()`), empêchant de sélectionner toute date passée.
/// - Une vérification en direct via [CalendarApiService] (API publique Nager.Date des jours fériés).
/// - Une sélection rapide d'horaires ou l'horloge interactive [showTimePicker].
class CalendarSlotPickerDialog extends StatefulWidget {
  final DateTime? initialDate;
  final String initialStartTime;
  final String initialEndTime;

  const CalendarSlotPickerDialog({
    super.key,
    this.initialDate,
    this.initialStartTime = '14:00',
    this.initialEndTime = '15:00',
  });

  /// Ouvre le sélecteur de créneau avec calendrier interactif à partir d'aujourd'hui.
  static Future<PickedCalendarSlot?> show(
    BuildContext context, {
    DateTime? initialDate,
    String initialStartTime = '14:00',
    String initialEndTime = '15:00',
  }) {
    return showModalBottomSheet<PickedCalendarSlot>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CalendarSlotPickerDialog(
        initialDate: initialDate,
        initialStartTime: initialStartTime,
        initialEndTime: initialEndTime,
      ),
    );
  }

  @override
  State<CalendarSlotPickerDialog> createState() =>
      _CalendarSlotPickerDialogState();
}

class _CalendarSlotPickerDialogState extends State<CalendarSlotPickerDialog> {
  static const List<Map<String, String>> _presetSlots = [
    {'start': '09:00', 'end': '10:00'},
    {'start': '10:00', 'end': '11:00'},
    {'start': '14:00', 'end': '15:00'},
    {'start': '16:00', 'end': '17:00'},
    {'start': '18:00', 'end': '19:00'},
    {'start': '20:00', 'end': '21:00'},
  ];

  final CalendarApiService _calendarApi = const CalendarApiService();
  late DateTime _selectedDate;
  late String _startTime;
  late String _endTime;
  CalendarDayInfo? _dayInfo;
  bool _checkingApi = false;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    final today = CalendarApiService.todayNormalized();
    final candidate = widget.initialDate;
    _selectedDate = (candidate != null && !candidate.isBefore(today))
        ? DateTime(candidate.year, candidate.month, candidate.day)
        : today;
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
    _inspectDateWithApi(_selectedDate);
  }

  Future<void> _inspectDateWithApi(DateTime date) async {
    setState(() => _checkingApi = true);
    try {
      final info = await _calendarApi.inspectDate(date);
      if (!mounted) return;
      setState(() => _dayInfo = info);
    } finally {
      if (mounted) setState(() => _checkingApi = false);
    }
  }

  TimeOfDay _parseTime(String hhMm) {
    final parts = hhMm.split(':');
    final h = int.tryParse(parts.first) ?? 14;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickClockTime({required bool isStart}) async {
    final initial = _parseTime(isStart ? _startTime : _endTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'Heure de début du cours' : 'Heure de fin du cours',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startTime = _formatTime(picked);
        // Ajuste automatiquement l'heure de fin à +1h si nécessaire
        final endHour = (picked.hour + 1).clamp(0, 23);
        final candidateEnd =
            _formatTime(TimeOfDay(hour: endHour, minute: picked.minute));
        if (_endTime.compareTo(_startTime) <= 0) {
          _endTime = candidateEnd;
        }
      } else {
        _endTime = _formatTime(picked);
      }
      _validateTimes();
    });
  }

  bool _validateTimes() {
    if (_endTime.compareTo(_startTime) <= 0) {
      _timeError = 'L\'heure de fin ($_endTime) doit être après le début ($_startTime).';
      return false;
    }
    _timeError = null;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final today = CalendarApiService.todayNormalized();
    final lastDate = today.add(const Duration(days: 365));
    final dateFormatted = CalendarApiService.formatSlotDate(_selectedDate);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF7C3AED),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Calendrier des créneaux (API Calendrier)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'À partir d\'aujourd\'hui (${CalendarApiService.formatSlotDate(today)})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Bandeau d'état de l'API Calendrier (Nager.Date Public Holidays TN)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (_dayInfo?.isHoliday ?? false)
                  ? const Color(0xFFFEF2F2)
                  : (_dayInfo?.isWeekend ?? false)
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_dayInfo?.isHoliday ?? false)
                    ? const Color(0xFFFECACA)
                    : (_dayInfo?.isWeekend ?? false)
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFBBF7D0),
              ),
            ),
            child: Row(
              children: [
                if (_checkingApi)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    (_dayInfo?.isHoliday ?? false)
                        ? Icons.celebration_rounded
                        : (_dayInfo?.isWeekend ?? false)
                            ? Icons.weekend_rounded
                            : Icons.verified_rounded,
                    size: 18,
                    color: (_dayInfo?.isHoliday ?? false)
                        ? const Color(0xFFDC2626)
                        : (_dayInfo?.isWeekend ?? false)
                            ? const Color(0xFFD97706)
                            : const Color(0xFF16A34A),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$dateFormatted · ${_dayInfo?.statusLabel ?? "Vérification calendrier..."}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Calendrier Material interactif (bloque automatiquement toute date avant aujourd'hui)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: today,
              lastDate: lastDate,
              onDateChanged: (newDate) {
                setState(() => _selectedDate = newDate);
                _inspectDateWithApi(newDate);
              },
            ),
          ),
          const SizedBox(height: 12),

          // Sélection rapide de tranches d'une heure
          const Text(
            'Tranches horaires rapides (1h) :',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetSlots.map((slot) {
              final s = slot['start']!;
              final e = slot['end']!;
              final selected = _startTime == s && _endTime == e;
              return ChoiceChip(
                selected: selected,
                selectedColor: const Color(0xFF7C3AED),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF1E293B),
                ),
                label: Text('$s - $e'),
                onSelected: (_) {
                  setState(() {
                    _startTime = s;
                    _endTime = e;
                    _timeError = null;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Boutons d'horloge personnalisée (Début / Fin)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickClockTime(isStart: true),
                  icon: const Icon(Icons.access_time_rounded, size: 18),
                  label: Text('Début : $_startTime'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickClockTime(isStart: false),
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text('Fin : $_endTime'),
                ),
              ),
            ],
          ),

          if (_timeError != null) ...[
            const SizedBox(height: 8),
            Text(
              _timeError!,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              if (!_validateTimes()) {
                setState(() {});
                return;
              }
              Navigator.pop(
                context,
                PickedCalendarSlot(
                  dateLabel: dateFormatted,
                  startTime: _startTime,
                  endTime: _endTime,
                  dayInfo: _dayInfo,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.event_available_rounded),
            label: Text(
              'Valider le créneau : $dateFormatted ($_startTime - $_endTime)',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
