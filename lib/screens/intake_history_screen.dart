import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/intake_tracker.dart';

class IntakeHistoryScreen extends StatefulWidget {
  final String? medicineName; // null = show all medicines

  const IntakeHistoryScreen({
    Key? key,
    this.medicineName,
  }) : super(key: key);

  @override
  State<IntakeHistoryScreen> createState() => _IntakeHistoryScreenState();
}

class _IntakeHistoryScreenState extends State<IntakeHistoryScreen> {
  List<IntakeRecord> records = [];
  IntakeStatistics? statistics;
  bool isLoading = true;
  int selectedDays = 7; // 7, 30, or 90 days

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
    });

    if (widget.medicineName != null) {
      final allRecords = await IntakeTracker.getRecordsForMedicine(widget.medicineName!);
      final stats = await IntakeTracker.getStatisticsForMedicine(
        medicineName: widget.medicineName!,
        daysBack: selectedDays,
      );

      setState(() {
        records = allRecords.reversed.toList(); // Most recent first
        statistics = stats;
        isLoading = false;
      });
    } else {
      final allRecords = await IntakeTracker.getAllRecords();
      final stats = await IntakeTracker.getOverallStatistics(daysBack: selectedDays);

      setState(() {
        records = allRecords.reversed.toList(); // Most recent first
        statistics = stats;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicineName ?? 'All Medicines'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Statistics Card
                if (statistics != null) _buildStatisticsCard(),

                // Time Period Selector
                _buildTimePeriodSelector(),

                // Records List
                Expanded(
                  child: records.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No intake records yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            return _buildRecordCard(records[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatisticsCard() {
    final stats = statistics!;
    final adherenceColor = stats.adherenceRate >= 80
        ? Colors.green
        : stats.adherenceRate >= 50
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last $selectedDays Days',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: adherenceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${stats.adherenceRate.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.check_circle,
                label: 'Taken',
                value: stats.takenDoses.toString(),
                color: Colors.white,
              ),
              _buildStatItem(
                icon: Icons.cancel,
                label: 'Missed',
                value: stats.missedDoses.toString(),
                color: Colors.white70,
              ),
              _buildStatItem(
                icon: Icons.medication,
                label: 'Total',
                value: stats.totalDoses.toString(),
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPeriodChip('7 Days', 7),
          const SizedBox(width: 8),
          _buildPeriodChip('30 Days', 30),
          const SizedBox(width: 8),
          _buildPeriodChip('90 Days', 90),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, int days) {
    final isSelected = selectedDays == days;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDays = days;
        });
        loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(IntakeRecord record) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: record.wasMissed ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            record.wasMissed ? Icons.cancel : Icons.check_circle,
            color: record.wasMissed ? Colors.red : Colors.green,
            size: 28,
          ),
        ),
        title: Text(
          record.medicineName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Scheduled: ${record.scheduledTime}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(record.takenAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  timeFormat.format(record.takenAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            if (record.notes != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.note, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      record.notes!,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(record),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(IntakeRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text('Are you sure you want to delete this intake record?'),
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

    if (confirm == true) {
      await IntakeTracker.deleteRecord(record);
      loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}