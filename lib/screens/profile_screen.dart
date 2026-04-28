import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;

  final Color primaryColor = const Color(0xFF1E3A8A);
  final Color backgroundColor = const Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_profile');
    if (data != null) {
      setState(() {
        _profile = jsonDecode(data);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _profile == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: primaryColor,
                      child: Text(
                        _profile!['name'] != null && _profile!['name'].isNotEmpty 
                            ? _profile!['name'][0].toUpperCase() 
                            : 'U', 
                        style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildProfileTile('Name', _profile!['name'] ?? 'N/A'),
                  _buildProfileTile('Email', _profile!['email'] ?? 'N/A'),
                  _buildProfileTile('Phone', _profile!['phone'] ?? 'N/A'),
                  _buildProfileTile('Career Goal', _profile!['career'] ?? 'N/A'),
                  _buildProfileTile('Gender', _profile!['gender'] ?? 'N/A'),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await AuthService().logout();
                      if (mounted) {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, 
                      padding: const EdgeInsets.symmetric(vertical: 16), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
