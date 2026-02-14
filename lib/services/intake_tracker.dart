import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Model for a single intake record
class IntakeRecord {
  final String medicineName;
  final DateTime takenAt;
  final String scheduledTime; // The time it was supposed to be taken (HH:mm)
  final bool wasMissed; // true if marked as missed, false if taken
  final String? notes;

  IntakeRecord({
    required this.medicineName,
    required this.takenAt,
    required this.scheduledTime,
    this.wasMissed = false,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'medicineName': medicineName,
        'takenAt': takenAt.toIso8601String(),
        'scheduledTime': scheduledTime,
        'wasMissed': wasMissed,
        'notes': notes,
      };

  factory IntakeRecord.fromJson(Map<String, dynamic> json) => IntakeRecord(
        medicineName: json['medicineName'],
        takenAt: DateTime.parse(json['takenAt']),
        scheduledTime: json['scheduledTime'],
        wasMissed: json['wasMissed'] ?? false,
        notes: json['notes'],
      );
}

// Statistics model
class IntakeStatistics {
  final int totalDoses;
  final int takenDoses;
  final int missedDoses;
  final double adherenceRate;
  final Map<String, int> dailyIntake; // Date -> count

  IntakeStatistics({
    required this.totalDoses,
    required this.takenDoses,
    required this.missedDoses,
    required this.adherenceRate,
    required this.dailyIntake,
  });
}

// Service to manage intake records
class IntakeTracker {
  static const String _intakeKey = 'MEDICINE_INTAKE_RECORDS';

  // Record that a medicine was taken
  static Future<void> markAsTaken({
    required String medicineName,
    required String scheduledTime,
    String? notes,
  }) async {
    final record = IntakeRecord(
      medicineName: medicineName,
      takenAt: DateTime.now(),
      scheduledTime: scheduledTime,
      wasMissed: false,
      notes: notes,
    );

    await _saveRecord(record);
  }

  // Record that a medicine was missed
  static Future<void> markAsMissed({
    required String medicineName,
    required String scheduledTime,
    String? notes,
  }) async {
    final record = IntakeRecord(
      medicineName: medicineName,
      takenAt: DateTime.now(),
      scheduledTime: scheduledTime,
      wasMissed: true,
      notes: notes,
    );

    await _saveRecord(record);
  }

  // Save a record
  static Future<void> _saveRecord(IntakeRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await getAllRecords();
    records.add(record);

    final jsonList = records.map((r) => r.toJson()).toList();
    await prefs.setString(_intakeKey, json.encode(jsonList));
  }

  // Get all intake records
  static Future<List<IntakeRecord>> getAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_intakeKey);

    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => IntakeRecord.fromJson(json)).toList();
  }

  // Get records for a specific medicine
  static Future<List<IntakeRecord>> getRecordsForMedicine(String medicineName) async {
    final allRecords = await getAllRecords();
    return allRecords.where((r) => r.medicineName == medicineName).toList();
  }

  // Get records for a specific date
  static Future<List<IntakeRecord>> getRecordsForDate(DateTime date) async {
    final allRecords = await getAllRecords();
    return allRecords.where((r) {
      return r.takenAt.year == date.year &&
          r.takenAt.month == date.month &&
          r.takenAt.day == date.day;
    }).toList();
  }

  // Get records for a date range
  static Future<List<IntakeRecord>> getRecordsForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final allRecords = await getAllRecords();
    return allRecords.where((r) {
      return r.takenAt.isAfter(startDate.subtract(const Duration(days: 1))) &&
          r.takenAt.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  // Check if medicine was taken at a specific time today
  static Future<bool> wasTakenToday({
    required String medicineName,
    required String scheduledTime,
  }) async {
    final today = DateTime.now();
    final todayRecords = await getRecordsForDate(today);

    return todayRecords.any((r) =>
        r.medicineName == medicineName &&
        r.scheduledTime == scheduledTime &&
        !r.wasMissed);
  }

  // Get statistics for a medicine
  static Future<IntakeStatistics> getStatisticsForMedicine({
    required String medicineName,
    int daysBack = 30,
  }) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: daysBack));
    final records = await getRecordsForDateRange(startDate, endDate);

    final medicineRecords = records.where((r) => r.medicineName == medicineName).toList();

    final takenCount = medicineRecords.where((r) => !r.wasMissed).length;
    final missedCount = medicineRecords.where((r) => r.wasMissed).length;
    final totalCount = medicineRecords.length;

    final adherenceRate = totalCount > 0 ? (takenCount / totalCount) * 100 : 0.0;

    // Daily intake map
    final Map<String, int> dailyIntake = {};
    for (final record in medicineRecords) {
      if (!record.wasMissed) {
        final dateKey = _formatDate(record.takenAt);
        dailyIntake[dateKey] = (dailyIntake[dateKey] ?? 0) + 1;
      }
    }

    return IntakeStatistics(
      totalDoses: totalCount,
      takenDoses: takenCount,
      missedDoses: missedCount,
      adherenceRate: adherenceRate,
      dailyIntake: dailyIntake,
    );
  }

  // Get overall statistics (all medicines)
  static Future<IntakeStatistics> getOverallStatistics({int daysBack = 30}) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: daysBack));
    final records = await getRecordsForDateRange(startDate, endDate);

    final takenCount = records.where((r) => !r.wasMissed).length;
    final missedCount = records.where((r) => r.wasMissed).length;
    final totalCount = records.length;

    final adherenceRate = totalCount > 0 ? (takenCount / totalCount) * 100 : 0.0;

    // Daily intake map
    final Map<String, int> dailyIntake = {};
    for (final record in records) {
      if (!record.wasMissed) {
        final dateKey = _formatDate(record.takenAt);
        dailyIntake[dateKey] = (dailyIntake[dateKey] ?? 0) + 1;
      }
    }

    return IntakeStatistics(
      totalDoses: totalCount,
      takenDoses: takenCount,
      missedDoses: missedCount,
      adherenceRate: adherenceRate,
      dailyIntake: dailyIntake,
    );
  }

  // Delete all records for a medicine
  static Future<void> deleteRecordsForMedicine(String medicineName) async {
    final allRecords = await getAllRecords();
    final filteredRecords = allRecords.where((r) => r.medicineName != medicineName).toList();

    final prefs = await SharedPreferences.getInstance();
    final jsonList = filteredRecords.map((r) => r.toJson()).toList();
    await prefs.setString(_intakeKey, json.encode(jsonList));
  }

  // Delete a specific record
  static Future<void> deleteRecord(IntakeRecord record) async {
    final allRecords = await getAllRecords();
    allRecords.removeWhere((r) =>
        r.medicineName == record.medicineName &&
        r.takenAt == record.takenAt &&
        r.scheduledTime == record.scheduledTime);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = allRecords.map((r) => r.toJson()).toList();
    await prefs.setString(_intakeKey, json.encode(jsonList));
  }

  // Clear all records
  static Future<void> clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_intakeKey);
  }

  // Helper to format date as string
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Get today's pending medicines (scheduled but not taken yet)
  static Future<List<Map<String, dynamic>>> getTodaysPendingMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final medicines = prefs.getStringList('MEDICINE_LIST') ?? [];

    final List<Map<String, dynamic>> pending = [];
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final medicine in medicines) {
      // Get schedule for medicine (assuming it's stored somewhere)
      // This is a placeholder - adjust based on your actual schedule storage
      final scheduleJson = prefs.getString('${medicine}_SCHEDULE');
      if (scheduleJson != null) {
        final schedule = json.decode(scheduleJson);
        final times = List<String>.from(schedule['times'] ?? []);

        for (final time in times) {
          final wasTaken = await wasTakenToday(
            medicineName: medicine,
            scheduledTime: time,
          );

          if (!wasTaken && _isTimePassed(time, currentTime)) {
            pending.add({
              'medicineName': medicine,
              'scheduledTime': time,
            });
          }
        }
      }
    }

    return pending;
  }

  static bool _isTimePassed(String scheduledTime, String currentTime) {
    final scheduled = scheduledTime.split(':');
    final current = currentTime.split(':');

    final scheduledMinutes = int.parse(scheduled[0]) * 60 + int.parse(scheduled[1]);
    final currentMinutes = int.parse(current[0]) * 60 + int.parse(current[1]);

    return currentMinutes >= scheduledMinutes;
  }
}