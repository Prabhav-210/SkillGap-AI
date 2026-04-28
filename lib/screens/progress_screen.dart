import 'package:flutter/material.dart';
import '../data/progress_data.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final Color primaryColor = const Color(0xFF1E3A8A);
  final Color secondaryColor = const Color(0xFF3B82F6);
  final Color backgroundColor = const Color(0xFFF3F4F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: allRoadmaps.isEmpty
            ? _buildEmptyState()
            : _buildRoadmapList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No roadmaps yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete a chat session with the AI assistant to generate your personalized career roadmaps.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
          child: Text(
            'Your Career Plans',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: primaryColor,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '${allRoadmaps.length} roadmaps generated',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: allRoadmaps.length,
            itemBuilder: (context, index) {
              final roadmap = allRoadmaps[index];
              final tasks = List<Map<String, dynamic>>.from(roadmap['tasks']);
              final completedCount = tasks.where((t) => t['completed'] == true).length;
              final totalCount = tasks.length;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          roadmap['title'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _confirmDelete(roadmap['id']),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        roadmap['date'] ?? 'Recent',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: totalCount > 0 ? completedCount / totalCount : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$completedCount of $totalCount weeks completed',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoadmapDetailScreen(
                          roadmapIndex: index,
                        ),
                      ),
                    );
                    setState(() {}); // Refresh list on return
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmDelete(String? id) {
    if (id == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Roadmap'),
        content: const Text('Are you sure you want to delete this roadmap?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await deleteRoadmapById(id);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class RoadmapDetailScreen extends StatefulWidget {
  final int roadmapIndex;

  const RoadmapDetailScreen({Key? key, required this.roadmapIndex}) : super(key: key);

  @override
  State<RoadmapDetailScreen> createState() => _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends State<RoadmapDetailScreen> {
  final Color primaryColor = const Color(0xFF1E3A8A);
  final Color secondaryColor = const Color(0xFF3B82F6);
  final Color backgroundColor = const Color(0xFFF3F4F6);

  void _toggleTask(int taskIndex) {
    setState(() {
      final roadmap = allRoadmaps[widget.roadmapIndex];
      roadmap['tasks'][taskIndex]['completed'] = !roadmap['tasks'][taskIndex]['completed'];
    });
    saveRoadmaps(); // Persist changes immediately

    // Check if all tasks are completed
    final roadmap = allRoadmaps[widget.roadmapIndex];
    final tasks = List<Map<String, dynamic>>.from(roadmap['tasks']);
    final allDone = tasks.every((t) => t['completed'] == true);
    
    if (allDone) {
      _showCongratsDialog();
    }
  }

  void _showCongratsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: secondaryColor, size: 28),
            const SizedBox(width: 10),
            const Text('Congratulations!'),
          ],
        ),
        content: const Text(
          'Great! You completed this roadmap 🎉',
          style: TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roadmap = allRoadmaps[widget.roadmapIndex];
    final tasks = roadmap['tasks'] as List<dynamic>;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(roadmap['title'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          final bool completed = task['completed'] == true;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Checkbox(
                value: completed,
                onChanged: (_) => _toggleTask(index),
                activeColor: secondaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              title: Text(
                task['title'] as String,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: completed ? Colors.grey[400] : Colors.black87,
                  decoration: completed ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: Colors.grey[400],
                ),
              ),
              trailing: completed
                  ? Icon(Icons.check_circle, color: secondaryColor, size: 24)
                  : Icon(Icons.radio_button_unchecked, color: Colors.grey[300], size: 24),
              onTap: () => _toggleTask(index),
            ),
          );
        },
      ),
    );
  }
}
