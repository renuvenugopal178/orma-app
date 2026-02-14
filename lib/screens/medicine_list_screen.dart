import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ormayuapp/services/notification_service.dart';
import 'package:ormayuapp/services/intake_tracker.dart';
import 'medicine_schedule_screen.dart';
import 'intake_history_screen.dart';

class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({Key? key}) : super(key: key);

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  List<String> medicines = [];
  Map<String, MedicineSchedule?> schedules = {};
  Map<String, Map<String, bool>> takenToday = {}; // medicine -> {time -> taken}
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMedicines();
  }

  Future<void> loadMedicines() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final medicineList = prefs.getStringList('MEDICINE_LIST') ?? [];

    // Load schedules for all medicines
    Map<String, MedicineSchedule?> tempSchedules = {};
    Map<String, Map<String, bool>> tempTakenToday = {};

    for (final medicine in medicineList) {
      final schedule = await ScheduleManager.getScheduleForMedicine(medicine);
      tempSchedules[medicine] = schedule;

      // Check which doses were taken today
      if (schedule != null) {
        Map<String, bool> timesStatus = {};
        for (final time in schedule.times) {
          final taken = await IntakeTracker.wasTakenToday(
            medicineName: medicine,
            scheduledTime: time,
          );
          timesStatus[time] = taken;
        }
        tempTakenToday[medicine] = timesStatus;
      }
    }

    setState(() {
      medicines = medicineList;
      schedules = tempSchedules;
      takenToday = tempTakenToday;
      isLoading = false;
    });
  }

  Future<void> deleteMedicine(String medicineName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text('Are you sure you want to delete $medicineName, its schedule, and all intake records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Delete schedule and notifications
      await ScheduleManager.deleteSchedule(medicineName);

      // Delete intake records
      await IntakeTracker.deleteRecordsForMedicine(medicineName);

      // Delete medicine data
      await prefs.remove('${medicineName}_USAGE');
      await prefs.remove('${medicineName}_TIMING');
      await prefs.remove('${medicineName}_IMAGE');

      // Remove from list
      medicines.remove(medicineName);
      await prefs.setStringList('MEDICINE_LIST', medicines);

      await loadMedicines();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicine deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> toggleSchedule(String medicineName, bool isActive) async {
    await ScheduleManager.toggleSchedule(medicineName, isActive);
    await loadMedicines();
  }

  Future<void> markAsTaken(String medicineName, String scheduledTime) async {
    await IntakeTracker.markAsTaken(
      medicineName: medicineName,
      scheduledTime: scheduledTime,
    );

    await loadMedicines();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Marked $medicineName as taken'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medicines'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const IntakeHistoryScreen(),
                ),
              );
            },
            tooltip: 'View All History',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : medicines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medication_outlined,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No medicines added yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add medicines from caregiver screen',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: medicines.length,
                  itemBuilder: (context, index) {
                    final medicine = medicines[index];
                    final schedule = schedules[medicine];
                    final hasSchedule = schedule != null && schedule.times.isNotEmpty;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.medication_rounded,
                                color: Colors.blue.shade700,
                                size: 28,
                              ),
                            ),
                            title: Text(
                              medicine,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: hasSchedule
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.alarm,
                                          size: 16,
                                          color: schedule.isActive
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${schedule.times.length} reminder${schedule.times.length > 1 ? 's' : ''}',
                                          style: TextStyle(
                                            color: schedule.isActive
                                                ? Colors.green
                                                : Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (!schedule.isActive) ...[
                                          const SizedBox(width: 8),
                                          const Text(
                                            '(Paused)',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'No reminders set',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) async {
                                if (value == 'delete') {
                                  await deleteMedicine(medicine);
                                } else if (value == 'toggle' && hasSchedule) {
                                  await toggleSchedule(medicine, !schedule.isActive);
                                } else if (value == 'history') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => IntakeHistoryScreen(
                                        medicineName: medicine,
                                      ),
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'history',
                                  child: Row(
                                    children: [
                                      Icon(Icons.history, size: 20),
                                      SizedBox(width: 8),
                                      Text('View History'),
                                    ],
                                  ),
                                ),
                                if (hasSchedule)
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(
                                          schedule.isActive
                                              ? Icons.pause_circle_outline
                                              : Icons.play_circle_outline,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(schedule.isActive
                                            ? 'Pause Reminders'
                                            : 'Resume Reminders'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Schedule times with "Mark as Taken" buttons
                          if (hasSchedule && schedule.times.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Today\'s Schedule:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => MedicineScheduleScreen(
                                                medicineName: medicine,
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            await loadMedicines();
                                          }
                                        },
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text('Edit'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.blue,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...schedule.times.map((time) {
                                    final isTaken = takenToday[medicine]?[time] ?? false;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isTaken
                                            ? Colors.green.shade50
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isTaken
                                              ? Colors.green.shade200
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isTaken ? Icons.check_circle : Icons.access_time,
                                            color: isTaken ? Colors.green : Colors.blue.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            time,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: isTaken ? Colors.green.shade700 : Colors.black87,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (!isTaken)
                                            ElevatedButton(
                                              onPressed: () => markAsTaken(medicine, time),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                'Mark as Taken',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'Taken ✓',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                              child: TextButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MedicineScheduleScreen(
                                        medicineName: medicine,
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    await loadMedicines();
                                  }
                                },
                                icon: const Icon(Icons.alarm_add, size: 18),
                                label: const Text('Set Reminders'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}