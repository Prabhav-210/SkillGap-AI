import 'package:flutter/material.dart';

class ResumeUploadScreen extends StatefulWidget {
  const ResumeUploadScreen({Key? key}) : super(key: key);

  @override
  _ResumeUploadScreenState createState() => _ResumeUploadScreenState();
}

class _ResumeUploadScreenState extends State<ResumeUploadScreen> {
  // Colors from Stitch Design System
  final Color primaryColor = const Color(0xFF1E3A8A); 
  final Color secondaryColor = const Color(0xFF3B82F6); 
  final Color backgroundColor = const Color(0xFFF3F4F6); 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Upload Resume', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Let\'s see what you\'re working with.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Upload your resume in PDF or DOCX format to get an AI-powered skill analysis.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Drag and drop / File upload area
              GestureDetector(
                onTap: () {
                  // Trigger file picker
                },
                child: Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: secondaryColor.withOpacity(0.5),
                      width: 2,
                      style: BorderStyle.solid, // In a real app we might use dotted_border package
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: secondaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.cloud_upload_outlined, size: 48, color: secondaryColor),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Tap to Upload File',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Supported formats: PDF, DOCX (Max 5MB)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Submit Button
              ElevatedButton(
                onPressed: () {
                  // Navigate to Analysis/Results
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  fixedSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  shadowColor: primaryColor.withOpacity(0.4),
                ),
                child: const Text('Submit for Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
