import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class ElderScreen extends StatefulWidget {
  const ElderScreen({Key? key}) : super(key: key);

  @override
  State<ElderScreen> createState() => _ElderScreenState();
}

class _ElderScreenState extends State<ElderScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isProcessing = false;
  String? _recognizedText;
  Map<String, String>? _medicineDetails;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    await _flutterTts.setLanguage("ml-IN");
    await _flutterTts.setSpeechRate(0.4); // Slower for elderly
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  Future<void> _initializeCamera() async {
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      _showError('Camera permission denied');
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        _showError('No camera found');
        return;
      }

      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  Future<void> _scanMedicine() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showError('Camera not ready');
      return;
    }

    setState(() {
      _isProcessing = true;
      _recognizedText = null;
      _medicineDetails = null;
    });

    try {
      // Capture image
      final XFile imageFile = await _cameraController!.takePicture();

      // Perform OCR
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      String fullText = recognizedText.text.toUpperCase();

      // Clean up
      await textRecognizer.close();

      if (fullText.isEmpty) {
        _showError('No text detected. Please try again.');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Search for medicine in saved data
      await _searchMedicine(fullText);

    } catch (e) {
      _showError('Scanning failed: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _searchMedicine(String scannedText) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> medicines = prefs.getStringList('MEDICINE_LIST') ?? [];

    String? foundMedicine;

    // Search for matching medicine name
    for (String medicine in medicines) {
      if (scannedText.contains(medicine)) {
        foundMedicine = medicine;
        break;
      }
    }

    if (foundMedicine != null) {
      // Found medicine - load details
      String? usage = prefs.getString('${foundMedicine}_USAGE');
      String? timing = prefs.getString('${foundMedicine}_TIMING');
      String? imagePath = prefs.getString('${foundMedicine}_IMAGE');

      setState(() {
        _recognizedText = foundMedicine;
        _medicineDetails = {
          'name': foundMedicine!,
          'usage': usage ?? 'No usage information',
          'timing': timing ?? 'No timing information',
          'image': imagePath ?? '',
        };
      });

      // Speak the instructions
      await _speakInstructions(foundMedicine, usage, timing);

    } else {
      // No medicine found
      setState(() {
        _recognizedText = 'Medicine not found';
      });
      await _speak('ഈ മരുന്ന് തിരിച്ചറിയാൻ കഴിഞ്ഞില്ല. ദയവായി ഡോക്ടറെ സമീപിക്കുക.');
    }
  }

  Future<void> _speakInstructions(String name, String? usage, String? timing) async {
    String instruction = '';

    if (usage != null && usage.isNotEmpty) {
      instruction += usage;
    }

    if (timing != null && timing.isNotEmpty) {
      if (instruction.isNotEmpty) {
        instruction += '. ';
      }
      instruction += timing;
    }

    if (instruction.isNotEmpty) {
      await _speak(instruction);
    }
  }

  Future<void> _speak(String text) async {
    setState(() {
      _isSpeaking = true;
    });
    await _flutterTts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Medicine'),
        elevation: 0,
        backgroundColor: Colors.green,
      ),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Camera Preview
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                CameraPreview(_cameraController!),

                // Scanning overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Scanning...',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Results Section
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: _medicineDetails == null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Point camera at medicine strip\nand tap Scan button',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Medicine Name
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green.shade700,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _medicineDetails!['name']!,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Usage
                    _buildInfoCard(
                      icon: Icons.info_outline,
                      title: 'What is it for?',
                      content: _medicineDetails!['usage']!,
                      color: Colors.blue,
                    ),

                    const SizedBox(height: 16),

                    // Timing
                    _buildInfoCard(
                      icon: Icons.access_time_rounded,
                      title: 'When to take?',
                      content: _medicineDetails!['timing']!,
                      color: Colors.orange,
                    ),

                    const SizedBox(height: 16),

                    // Repeat Voice Button
                    if (!_isSpeaking)
                      ElevatedButton.icon(
                        onPressed: () => _speakInstructions(
                          _medicineDetails!['name']!,
                          _medicineDetails!['usage'],
                          _medicineDetails!['timing'],
                        ),
                        icon: const Icon(Icons.volume_up_rounded),
                        label: const Text('Repeat Instructions'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _stopSpeaking,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isProcessing
          ? null
          : FloatingActionButton.extended(
        onPressed: _scanMedicine,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.camera_alt_rounded, size: 28),
        label: const Text(
          'SCAN',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color.lerp(color, Colors.black, 0.3)!,  // ✅ Singular 'color:'
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 18,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _flutterTts.stop();
    super.dispose();
  }
}