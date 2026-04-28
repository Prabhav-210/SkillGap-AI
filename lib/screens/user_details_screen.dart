import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({Key? key}) : super(key: key);

  @override
  _UserDetailsScreenState createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _careerController = TextEditingController();
  final _emailController = TextEditingController();
  String _gender = 'Male';
  bool _isLoading = false;

  final Color primaryColor = const Color(0xFF1E3A8A);
  final Color backgroundColor = const Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _careerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
      return;
    }

    setState(() => _isLoading = true);
    final profile = {
      "name": _nameController.text.trim(),
      "phone": _phoneController.text.trim(),
      "career": _careerController.text.trim(),
      "gender": _gender,
      "email": _emailController.text.trim(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(profile));

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tell us about yourself', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 8),
              Text('We use this to personalize your career roadmap', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 32),
              _buildInputField(label: 'Full Name', controller: _nameController, icon: Icons.person_outline),
              const SizedBox(height: 20),
              _buildInputField(label: 'Phone Number', controller: _phoneController, icon: Icons.phone_android_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 20),
              _buildInputField(label: 'Career Goal', controller: _careerController, icon: Icons.work_outline),
              const SizedBox(height: 20),
              _buildInputField(label: 'Email', controller: _emailController, icon: Icons.email_outlined, enabled: false),
              const SizedBox(height: 20),
              _buildDropdownField(),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({required String label, required TextEditingController controller, required IconData icon, TextInputType? keyboardType, bool enabled = true}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.6)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _gender,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: primaryColor),
          items: ['Male', 'Female', 'Other'].map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: (newValue) {
            setState(() { _gender = newValue!; });
          },
        ),
      ),
    );
  }
}
