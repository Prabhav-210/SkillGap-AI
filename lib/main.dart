import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'screens/user_details_screen.dart';
import 'screens/home_screen.dart';
import 'data/progress_data.dart';
import 'services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Note: Firebase.initializeApp() requires google-services.json (Android) 
  // or GoogleService-Info.plist (iOS) to be added to the respective native folders.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase initialization failed: $e");
  }

  await loadRoadmaps();
  runApp(const SkillGapApp());
}

class SkillGapApp extends StatelessWidget {
  const SkillGapApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkillGap AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1E3A8A),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData) {
            return const PostAuthWrapper();
          } else {
            return const LoginScreen();
          }
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class PostAuthWrapper extends StatefulWidget {
  const PostAuthWrapper({Key? key}) : super(key: key);

  @override
  _PostAuthWrapperState createState() => _PostAuthWrapperState();
}

class _PostAuthWrapperState extends State<PostAuthWrapper> {
  bool? _hasProfile;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = prefs.getString('user_profile');
    setState(() {
      _hasProfile = profile != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _hasProfile! ? const HomeScreen() : const UserDetailsScreen();
  }
}
