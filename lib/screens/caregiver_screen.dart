import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'medicine_schedule_screen.dart';

class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({Key? key}) : super(key: key);

  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  final TextEditingController medicineNameController = TextEditingController();
  final TextEditingController usageController = TextEditingController();
  final TextEditingController timingController = TextEditingController();

  File? imageFile;
  final ImagePicker picker = ImagePicker();
  bool isSaving = false;

  Future<void> pickImage() async {
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      showError('Failed to capture image: $e');
    }
  }

  Future<void> savePrescription() async {
    if (medicineNameController.text.trim().isEmpty) {
      showError('Please enter medicine name');
      return;
    }

    if (usageController.text.trim().isEmpty) {
      showError('Please enter usage instructions');
      return;
    }

    if (timingController.text.trim().isEmpty) {
      showError('Please enter timing instructions');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      String medicineName = medicineNameController.text.trim().toUpperCase();

      // Save image path if image exists
      String? savedImagePath;
      if (imageFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = '${medicineName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await imageFile!.copy('${directory.path}/$fileName');
        savedImagePath = savedImage.path;
        await prefs.setString('${medicineName}_IMAGE', savedImagePath);
      }

      // Save medicine details
      await prefs.setString('${medicineName}_USAGE', usageController.text.trim());
      await prefs.setString('${medicineName}_TIMING', timingController.text.trim());

      // Add to medicine list
      List<String> medicines = prefs.getStringList('MEDICINE_LIST') ?? [];
      if (!medicines.contains(medicineName)) {
        medicines.add(medicineName);
        await prefs.setStringList('MEDICINE_LIST', medicines);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Prescription saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Ask if user wants to set reminder
        final setReminder = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Set Reminder?'),
            content: Text('Would you like to set reminder times for $medicineName?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: const Text('Yes', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (setReminder == true && mounted) {
          // Navigate to schedule screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MedicineScheduleScreen(
                medicineName: medicineName,
              ),
            ),
          );
        }

        // Clear form
        medicineNameController.clear();
        usageController.clear();
        timingController.clear();
        setState(() {
          imageFile = null;
        });
      }
    } catch (e) {
      showError('Failed to save: $e');
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Medicine Instructions'),
        elevation: 0,
        backgroundColor: Colors.blue,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Picker Section
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_rounded,
                              size: 64,
                              color: Colors.blue.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tap to capture medicine image',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            imageFile!,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Medicine Name
              _buildTextField(
                controller: medicineNameController,
                label: 'Medicine Name',
                hint: 'e.g., PARACETAMOL',
                icon: Icons.medication_rounded,
              ),

              const SizedBox(height: 16),

              // Usage
              _buildTextField(
                controller: usageController,
                label: 'What is it used for?',
                hint: 'e.g., ശരീരവേദനയ്ക്കും പനിക്കും',
                icon: Icons.info_outline,
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              // Timing
              _buildTextField(
                controller: timingController,
                label: 'When to take it?',
                hint: 'e.g., ഭക്ഷണത്തിന് ശേഷം കഴിക്കുക',
                icon: Icons.access_time_rounded,
                maxLines: 2,
              ),

              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: isSaving ? null : savePrescription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Prescription',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.blue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  @override
  void dispose() {
    medicineNameController.dispose();
    usageController.dispose();
    timingController.dispose();
    super.dispose();
  }
}