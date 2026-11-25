const Map<int, String> weekdayShortNames = <int, String>{
  1: 'Seg',
  2: 'Ter',
  3: 'Qua',
  4: 'Qui',
  5: 'Sex',
  6: 'Sáb',
  7: 'Dom',
};

const Map<int, String> weekdayFullNames = <int, String>{
  1: 'Segunda',
  2: 'Terça',
  3: 'Quarta',
  4: 'Quinta',
  5: 'Sexta',
  6: 'Sábado',
  7: 'Domingo',
};

const List<String> monthNamesPt = <String>[
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const List<String> monthShortNamesPt = <String>[
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String monthKey(int year, int month) =>
    '$year-${month.toString().padLeft(2, '0')}';

String formatDatePt(DateTime date) {
  final weekday = weekdayFullNames[date.weekday] ?? '';
  final month = monthNamesPt[date.month - 1].toLowerCase();
  return '$weekday, ${date.day} de $month';
}

String formatShortDayMonth(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = monthShortNamesPt[date.month - 1];
  return '$day $month';
}

String formatDateTimePt(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} às $hour:$minute';
}

String formatWeekdays(List<int> weekdays) {
  if (weekdays.isEmpty) return 'Sem dias definidos';
  final sorted = List<int>.from(weekdays)..sort();
  if (sorted.length == 7) return 'Todos os dias';
  if (sorted.length == 5 &&
      sorted.first == 1 &&
      sorted.last == 5) {
    return 'Segunda a sexta';
  }
  if (sorted.length == 2 && sorted.contains(6) && sorted.contains(7)) {
    return 'Fins de semana';
  }
  return sorted.map((d) => weekdayShortNames[d] ?? '').join(' · ');
}

List<int> parseWeekdaysFromLabel(String label) {
  final lower = label.toLowerCase();
  final result = <int>[];
  if (lower.contains('seg')) result.add(1);
  if (lower.contains('ter')) result.add(2);
  if (lower.contains('qua')) result.add(3);
  if (lower.contains('qui')) result.add(4);
  if (lower.contains('sex')) result.add(5);
  if (lower.contains('sáb') || lower.contains('sab')) result.add(6);
  if (lower.contains('dom')) result.add(7);
  return result.isEmpty ? <int>[1] : result;
}

String formatCurrencyBr(double value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final remaining = intPart.length - i;
    if (i > 0 && remaining % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(intPart[i]);
  }
  final formatted = 'R\$ $buffer,$decPart';
  return negative ? '− $formatted' : formatted;
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.course,
    required this.period,
    this.shift = '',
  });

  final String name;
  final String course;
  final String period;
  final String shift;

  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Estudante';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'US';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class SubjectItem {
  const SubjectItem({
    required this.id,
    required this.name,
    required this.weekdays,
    required this.startTime,
    required this.endTime,
    required this.colorIndex,
  });

  final String id;
  final String name;
  final List<int> weekdays;
  final String startTime;
  final String endTime;
  final int colorIndex;

  String get daysLabel => formatWeekdays(weekdays);

  String get timeLabel =>
      endTime.trim().isEmpty ? startTime : '$startTime–$endTime';

  bool occursOnWeekday(int weekday) => weekdays.contains(weekday);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'weekdays': weekdays,
        'startTime': startTime,
        'endTime': endTime,
        'colorIndex': colorIndex,
      };

  factory SubjectItem.fromJson(Map<String, dynamic> json, int fallbackIndex) {
    final name = (json['name'] as String? ?? '').trim();
    final id = (json['id'] as String?)?.trim().isNotEmpty == true
        ? json['id'] as String
        : 'subject_${fallbackIndex}_${name.hashCode.abs()}';

    List<int> weekdays;
    if (json['weekdays'] is List) {
      weekdays = (json['weekdays'] as List<dynamic>)
          .map((value) => (value as num).toInt())
          .where((day) => day >= 1 && day <= 7)
          .toList()
        ..sort();
    } else {
      weekdays = parseWeekdaysFromLabel(json['days'] as String? ?? 'Seg');
    }

    String startTime;
    String endTime;
    if (json['startTime'] is String) {
      startTime = json['startTime'] as String;
      endTime = (json['endTime'] as String?) ?? '';
    } else {
      final rawTime = (json['time'] as String? ?? '08:00–10:00').trim();
      final split = rawTime.split(RegExp(r'[–\-]'));
      startTime = split.isNotEmpty ? split.first.trim() : '08:00';
      endTime = split.length > 1 ? split[1].trim() : '';
    }

    final colorIndex = (json['colorIndex'] as num?)?.toInt() ?? fallbackIndex;

    return SubjectItem(
      id: id,
      name: name,
      weekdays: weekdays,
      startTime: startTime,
      endTime: endTime,
      colorIndex: colorIndex,
    );
  }
}

class SubjectNote {
  const SubjectNote({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SubjectNote.fromJson(Map<String, dynamic> json) => SubjectNote(
        id: (json['id'] as String?) ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: (json['title'] as String?) ?? '',
        content: (json['content'] as String?) ?? '',
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

enum FixedTaskStatus { pending, completed, missed }

class FixedTask {
  const FixedTask({
    required this.id,
    required this.title,
    required this.time,
    required this.weekdays,
    required this.completedDates,
    this.missedDates = const <String>[],
    this.colorIndex = 0,
  });

  final String id;
  final String title;
  final String time;
  final List<int> weekdays;
  final List<String> completedDates;
  final List<String> missedDates;
  final int colorIndex;

  bool isScheduledForWeekday(int weekday) => weekdays.contains(weekday);

  FixedTaskStatus statusForDate(String key) {
    if (completedDates.contains(key)) return FixedTaskStatus.completed;
    if (missedDates.contains(key)) return FixedTaskStatus.missed;
    return FixedTaskStatus.pending;
  }

  int completedCountInMonth(int year, int month) {
    final prefix = monthKey(year, month);
    return completedDates.where((date) => date.startsWith(prefix)).length;
  }

  int missedCountInMonth(int year, int month) {
    final prefix = monthKey(year, month);
    return missedDates.where((date) => date.startsWith(prefix)).length;
  }

  int scheduledOccurrencesInMonth(int year, int month) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    var count = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final weekday = DateTime(year, month, day).weekday;
      if (weekdays.contains(weekday)) {
        count++;
      }
    }
    return count;
  }

  FixedTask withResponse(String key, bool done) {
    final nextCompleted = List<String>.from(completedDates)..remove(key);
    final nextMissed = List<String>.from(missedDates)..remove(key);
    if (done) {
      nextCompleted.add(key);
    } else {
      nextMissed.add(key);
    }
    return FixedTask(
      id: id,
      title: title,
      time: time,
      weekdays: weekdays,
      completedDates: nextCompleted,
      missedDates: nextMissed,
      colorIndex: colorIndex,
    );
  }

  FixedTask copyWith({
    String? title,
    String? time,
    List<int>? weekdays,
    List<String>? completedDates,
    List<String>? missedDates,
    int? colorIndex,
  }) {
    return FixedTask(
      id: id,
      title: title ?? this.title,
      time: time ?? this.time,
      weekdays: weekdays ?? this.weekdays,
      completedDates: completedDates ?? this.completedDates,
      missedDates: missedDates ?? this.missedDates,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'time': time,
        'weekdays': weekdays,
        'completedDates': completedDates,
        'missedDates': missedDates,
        'colorIndex': colorIndex,
      };

  factory FixedTask.fromJson(Map<String, dynamic> json) => FixedTask(
        id: json['id'] as String,
        title: json['title'] as String,
        time: json['time'] as String,
        weekdays: (json['weekdays'] as List<dynamic>)
            .map((value) => (value as num).toInt())
            .toList(),
        completedDates: (json['completedDates'] as List<dynamic>? ?? const [])
            .map((value) => value as String)
            .toList(),
        missedDates: (json['missedDates'] as List<dynamic>? ?? const [])
            .map((value) => value as String)
            .toList(),
        colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      );
}

class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.date,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final bool isIncome;
  final DateTime date;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'isIncome': isIncome,
        'date': date.toIso8601String(),
      };

  factory FinanceEntry.fromJson(Map<String, dynamic> json) => FinanceEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String? ?? 'Outros',
        amount: (json['amount'] as num).toDouble(),
        isIncome: json['isIncome'] as bool? ?? false,
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      );
}
