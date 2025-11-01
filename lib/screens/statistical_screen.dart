import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/statistics_service.dart';

class StatisticalScreen extends StatefulWidget {
  const StatisticalScreen({super.key});

  @override
  State<StatisticalScreen> createState() => _StatisticalScreenState();
}

class _StatisticalScreenState extends State<StatisticalScreen> {
  final _statisticsService = StatisticsService();
  
  StatisticsData? _statistics;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => isLoading = true);
    
    try {
      _statistics = await _statisticsService.loadStatistics();
      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading statistics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải thống kê: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || _statistics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overview Cards
              _buildSectionTitle('Tổng quan'),
              const SizedBox(height: 12),
              _buildOverviewCards(),
              const SizedBox(height: 24),

              // Exercise Progress Chart
              _buildSectionTitle('Bài tập ngữ pháp'),
              const SizedBox(height: 12),
              _buildWeeklyExercisesBarChart(),
              const SizedBox(height: 24),

              // Exercise Accuracy Pie Chart
              _buildSectionTitle('Tỷ lệ làm bài ngữ pháp'),
              const SizedBox(height: 12),
              _buildAccuracyPieChart(),
              const SizedBox(height: 24),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          FaIcon(FontAwesomeIcons.book, size: 20, color: Colors.blue),
          'Từ vựng đã học',
          _statistics!.totalLearnedWords.toString(),
          Colors.blue,
        ),
        _buildStatCard(
          FaIcon(FontAwesomeIcons.pen, size: 20, color: Colors.purple),
          'Bài ngữ pháp',
          _statistics!.totalGrammarLessons.toString(),
          Colors.purple,
        ),
        _buildStatCard(
          FaIcon(FontAwesomeIcons.clipboardList, size: 20, color: Colors.orange),
          'Bài tập đã làm',
          _statistics!.totalExercisesCompleted.toString(),
          Colors.orange,
        ),
        _buildStatCard(
          FaIcon(FontAwesomeIcons.graduationCap, size: 20, color: Colors.teal),
          'Khóa học hoàn thành',
          _statistics!.totalLessonsCourseCompleted.toString(),
          Colors.teal,
        ),
       
      ],
    );
  }

  Widget _buildStatCard(Widget icon, String title, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildWeeklyExercisesBarChart() {
    if (_statistics!.weeklyExercises.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('Chưa có dữ liệu'),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (_statistics!.weeklyExercises.values.reduce((a, b) => a > b ? a : b) + 5).toDouble(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final keys = _statistics!.weeklyExercises.keys.toList();
                final date = keys[groupIndex];
                final value = rod.toY.toInt();
                return BarTooltipItem(
                  '$date\n$value bài tập',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final keys = _statistics!.weeklyExercises.keys.toList();
                  if (value.toInt() < keys.length) {
                    return Text(keys[value.toInt()], style: const TextStyle(fontSize: 10));
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: _statistics!.weeklyExercises.entries.toList().asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value.toDouble(),
                  color: Colors.blue,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAccuracyPieChart() {
    if (_statistics!.totalExercisesCompleted == 0) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('Chưa có dữ liệu'),
      );
    }

    final wrongRate = 100 - _statistics!.correctAnswerRate;
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: _statistics!.correctAnswerRate,
                    title: '${_statistics!.correctAnswerRate.toStringAsFixed(1)}%',
                    color: Colors.green,
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: wrongRate,
                    title: '${wrongRate.toStringAsFixed(1)}%',
                    color: Colors.red,
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem('Đúng', Colors.green),
              const SizedBox(height: 8),
              _buildLegendItem('Sai', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}