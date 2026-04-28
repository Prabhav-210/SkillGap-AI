import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const String _storageKey = 'all_roadmaps';

/// Each roadmap: { "id": String, "title": String, "date": String, "tasks": [...], "resources": [...] }
List<Map<String, dynamic>> allRoadmaps = [];

Future<void> loadRoadmaps() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonStr = prefs.getString(_storageKey);
  if (jsonStr != null) {
    final List<dynamic> decoded = jsonDecode(jsonStr);
    allRoadmaps = decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
  }
}

Future<void> saveRoadmaps() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_storageKey, jsonEncode(allRoadmaps));
}

/// Add or Update a roadmap by ID.
Future<void> addRoadmap({
  required String id,
  required String title,
  required List<String> weekLines,
  List<Map<String, String>> resources = const [],
}) async {
  // Remove existing roadmap with same ID if it exists (Sync overwrite)
  allRoadmaps.removeWhere((r) => r['id'] == id);

  final roadmap = <String, dynamic>{
    'id': id,
    'title': title,
    'date': _formattedDate(),
    'tasks': weekLines
        .map((w) => {'title': w, 'completed': false})
        .toList(),
    'resources': resources,
  };
  allRoadmaps.add(roadmap);
  await saveRoadmaps();
}

Future<void> deleteRoadmapById(String id) async {
  allRoadmaps.removeWhere((r) => r['id'] == id);
  await saveRoadmaps();
}

String _formattedDate() {
  final now = DateTime.now();
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[now.month - 1]} ${now.day}, ${now.year}';
}
