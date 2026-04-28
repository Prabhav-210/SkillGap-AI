import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/progress_data.dart';

class ResultDashboardScreen extends StatefulWidget {
  const ResultDashboardScreen({Key? key}) : super(key: key);

  @override
  _ResultDashboardScreenState createState() => _ResultDashboardScreenState();
}

class _ResultDashboardScreenState extends State<ResultDashboardScreen> {
  final Color primaryColor = const Color(0xFF1E3A8A);
  final Color secondaryColor = const Color(0xFF3B82F6);
  final Color backgroundColor = const Color(0xFFF3F4F6);
  final Color successColor = const Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    if (allRoadmaps.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(title: const Text('Result Dashboard')),
        body: const Center(child: Text('No roadmaps found. Generate one first!')),
      );
    }

    final latestRoadmap = allRoadmaps.last;
    final tasks = List<Map<String, dynamic>>.from(latestRoadmap['tasks']);
    final total = tasks.length;
    final completed = tasks.where((t) => t['completed'] == true).length;
    final percentage = total > 0 ? completed / total : 0.0;
    final pendingTasks = tasks.where((t) => t['completed'] == false).toList();
    final resources = latestRoadmap['resources'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(latestRoadmap['title'], style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Progress % (Circular Indicator)
              _buildProgressCard(percentage),
              const SizedBox(height: 32),

              // 2. Graph (Learning Curve)
              Text('Learning Progress', style: _headerStyle()),
              const SizedBox(height: 16),
              _buildGraphCard(tasks),
              const SizedBox(height: 32),

              // 3. Pending Tasks
              if (pendingTasks.isNotEmpty) ...[
                Text('Pending Tasks', style: _headerStyle()),
                const SizedBox(height: 16),
                _buildPendingTasksList(pendingTasks),
                const SizedBox(height: 32),
              ],

              // 4. Recommended Resources
              if (resources.isNotEmpty) ...[
                Text('Recommended Resources', style: _headerStyle()),
                const SizedBox(height: 16),
                _buildResourcesList(resources),
              ],
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _headerStyle() => TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: primaryColor);

  Widget _buildProgressCard(double percentage) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          const Text('Overall Progress', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 12,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                ),
              ),
              Text(
                '${(percentage * 100).toInt()}%',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGraphCard(List<Map<String, dynamic>> tasks) {
    // Data for the graph: cumulative completion over time
    List<FlSpot> spots = [const FlSpot(0, 0)];
    double completedSoFar = 0;
    for (int i = 0; i < tasks.length; i++) {
      if (tasks[i]['completed'] == true) {
        completedSoFar += 1;
      }
      spots.add(FlSpot((i + 1).toDouble(), completedSoFar));
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: secondaryColor,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: secondaryColor.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTasksList(List<Map<String, dynamic>> pendingTasks) {
    return Column(
      children: pendingTasks.map((task) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Icon(Icons.pending_actions, color: secondaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  task['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResourcesList(List<dynamic> resources) {
    return Column(
      children: resources.map((res) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          ),
          child: ListTile(
            leading: const Icon(Icons.link, color: Colors.green),
            title: Text(res['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(res['url'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () async {
              final uri = Uri.tryParse(res['url'] as String);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        );
      }).toList(),
    );
  }
}
