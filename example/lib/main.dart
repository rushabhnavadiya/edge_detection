import 'dart:async';
import 'dart:io';
import 'package:edge_detection/edge_detection.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';


import 'package:camera/camera.dart';

import 'package:image_picker/image_picker.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: CustomCameraScreen(),
    );
  }
}

class CustomCameraScreen extends StatefulWidget {
  @override
  _CustomCameraScreenState createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  CameraController? _controller;
  bool _isFlashOn = false;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // Initialize Camera
  Future<void> _initializeCamera() async {
    await Permission.camera.request(); // Request camera permission

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  // Toggle Flashlight
  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    _isFlashOn = !_isFlashOn;
    await _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  // Capture Image and Apply Edge Detection
  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final image = await _controller!.takePicture();
    _applyEdgeDetection(image.path);
  }

  // Pick Image from Gallery
  Future<void> _pickImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _applyEdgeDetection(pickedFile.path);
    }
  }

  // Apply Edge Detection to Image
  Future<void> _applyEdgeDetection(String imagePath) async {
    final appDir = await getApplicationSupportDirectory();
    String outputPath = join(appDir.path, "${DateTime.now().millisecondsSinceEpoch}.jpeg");

    bool success = false;
    try {
      success = await EdgeDetection.detectEdge(outputPath);
    } catch (e) {
      print(e);
    }

    if (!mounted) return;
    setState(() {
      _imagePath = success ? outputPath : imagePath;
    });
  }

  // Dispose Camera Controller
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_controller != null && _controller!.value.isInitialized)
            CameraPreview(_controller!)
          else
            Center(child: CircularProgressIndicator()),

          // Cancel Button (Top Right)
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 40),
              onPressed: () {
                Navigator.pop(context); // Go back to previous screen
              },
            ),
          ),

          // Flashlight Button (Top Left)
          Positioned(
            top: 20,
            left: 20,
            child: IconButton(
              icon: Icon(
                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
                size: 40,
              ),
              onPressed: _toggleFlash,
            ),
          ),

          // Gallery Button (Bottom Left)
          Positioned(
            bottom: 50,
            left: 20,
            child: IconButton(
              icon: Icon(Icons.photo_library, color: Colors.white, size: 40),
              onPressed: _pickImageFromGallery,
            ),
          ),

          // Capture Button (Center Bottom)
          Positioned(
            bottom: 20,
            left: MediaQuery.of(context).size.width / 2 - 30,
            child: GestureDetector(
              onTap: _captureImage,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 4),
                ),
              ),
            ),
          ),

          // Display Column with Buttons, Image Path, and Preview
          Positioned(
            bottom: 120,
            left: 20,
            right: 20,
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _captureImage,
                  child: Text('Scan'),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _pickImageFromGallery,
                  child: Text('Upload'),
                ),
                SizedBox(height: 20),

                // Display Cropped Image Path
                Text('Cropped Image Path:', style: TextStyle(fontSize: 16)),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _imagePath ?? "No Image Captured",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ),

                // Display Image Preview
                if (_imagePath != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.file(File(_imagePath!)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
