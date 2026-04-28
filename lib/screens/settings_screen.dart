import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _notificationsEnabled = true;
  final Color primaryColor = const Color(0xFF1E3A8A);
  final Color backgroundColor = const Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final profileData = prefs.getString('user_profile');
    final notifs = prefs.getBool('notifications_enabled') ?? true;
    
    setState(() {
      if (profileData != null) {
        _profile = jsonDecode(profileData);
      }
      _notificationsEnabled = notifs;
    });
  }

  Future<void> _updateNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Wipe everything
    await AuthService().logout();
    if (mounted) {
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (context) => const LoginScreen()),
         (route) => false,
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: primaryColor)),
            const SizedBox(height: 32),

            // --- ACCOUNT INFO SECTION ---
            _buildSectionHeader('Account Information'),
            _buildProfileCard(),
            const SizedBox(height: 24),

            // --- NOTIFICATIONS SECTION ---
            _buildSectionHeader('Notifications'),
            _buildToggleTile(
              title: 'Enable Notifications',
              value: _notificationsEnabled,
              onChanged: _updateNotifications,
              icon: Icons.notifications_active_outlined,
            ),
            const SizedBox(height: 24),

            // --- PRIVACY & SECURITY SECTION ---
            _buildSectionHeader('Privacy & Security'),
            _buildPrivacyCard(),
            const SizedBox(height: 24),

            // --- HELP & SUPPORT SECTION ---
            _buildSectionHeader('Help & Support'),
            _buildAboutCard(),
            const SizedBox(height: 12),
            _buildSupportButtons(),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            
            // Log Out
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.logout, color: Colors.red, size: 24),
              ),
              title: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 16)),
              onTap: () async {
                await AuthService().logout();
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.2)),
    );
  }

  Widget _buildProfileCard() {
    if (_profile == null) return const Center(child: CircularProgressIndicator());
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Name', _profile!['name'] ?? 'N/A'),
          _buildInfoRow('Email', _profile!['email'] ?? 'N/A'),
          _buildInfoRow('Phone', _profile!['phone'] ?? 'N/A'),
          _buildInfoRow('Gender', _profile!['gender'] ?? 'N/A'),
          _buildInfoRow('Career Goal', _profile!['career'] ?? 'N/A'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showEditProfileDialog,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildToggleTile({required String title, required bool value, required Function(bool) onChanged, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ListTile(
        leading: Icon(icon, color: primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: primaryColor,
        ),
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your data is stored securely on your device.\nWe do not share your data with third parties.",
            style: TextStyle(height: 1.5, fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showClearDataConfirmation,
              icon: const Icon(Icons.delete_forever_outlined, color: Colors.white),
              label: const Text('Clear All Data', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: const Text(
        "SkillGap AI is an intelligent career guidance platform designed to bridge the gap between ambition and ability. It helps users identify what they want to become and analyzes their current skills to highlight gaps that need improvement. The system generates structured, week-by-week roadmaps that guide users toward their desired career path with clarity and precision. By combining artificial intelligence with practical learning strategies, SkillGap AI transforms confusion into direction and action. It not only suggests what to learn but also provides resources to start immediately. Users can track their progress, stay accountable, and continuously improve through a personalized experience. The platform is built to support students and individuals who lack proper career guidance and want a clear, actionable path forward. SkillGap AI focuses on real outcomes by turning goals into measurable progress. It is not just a chatbot, but a complete system for career growth and skill development.",
        style: TextStyle(height: 1.6, fontSize: 13, color: Colors.black87),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _buildSupportButtons() {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(Icons.email_outlined, color: primaryColor),
          title: const Text('Contact Support'),
          subtitle: const Text('your@email.com'),
          onTap: () {},
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(Icons.bug_report_outlined, color: primaryColor),
          title: const Text('Report Issue'),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report Issue coming soon!')));
          },
        ),
      ],
    );
  }

  void _showClearDataConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text('This will delete your profile, chat history, and all progress. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: _clearAllData, child: const Text('Clear Everything', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _profile!['name']);
    final phoneController = TextEditingController(text: _profile!['phone']);
    final careerController = TextEditingController(text: _profile!['career']);
    String gender = _profile!['gender'] ?? 'Male';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField('Name', nameController),
                _buildDialogField('Phone', phoneController),
                _buildDialogField('Career Goal', careerController),
                DropdownButton<String>(
                  value: gender,
                  isExpanded: true,
                  items: ['Male', 'Female', 'Other'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                  onChanged: (val) => setDialogState(() => gender = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newProfile = {
                  ..._profile!,
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'career': careerController.text.trim(),
                  'gender': gender,
                };
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_profile', jsonEncode(newProfile));
                setState(() => _profile = newProfile);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
