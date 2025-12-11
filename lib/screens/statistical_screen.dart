import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../services/statistics_service.dart';

class StatisticalScreen extends StatefulWidget {
  const StatisticalScreen({super.key});

  @override
  State<StatisticalScreen> createState() => _StatisticalScreenState();
}

class _StatisticalScreenState extends State<StatisticalScreen> {
  final _statisticsService = StatisticsService();
  
  StatisticsData? _statistics;
  bool isLoadingData = true;
  bool isRefreshing = false; // refresh vs full load

  // Date range filter
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Predefined filters
  String _selectedFilter = '30_days';

  @override
  void initState() {
    super.initState();
    _initializeDateRange();
    _loadStatistics(showFullLoading: true);
  }

  void _initializeDateRange() {
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 30));
  }

  Future<void> _loadStatistics({bool showFullLoading = false}) async {
    if (showFullLoading) {
      setState(() => isLoadingData = true);
    } else {
      setState(() => isRefreshing = true);
    }
    
    try {
      final data = await _statisticsService.loadStatistics(
        startDate: _startDate,
        endDate: _endDate,
      );
      
      setState(() {
        _statistics = data;
        isLoadingData = false;
        isRefreshing = false;
      });
    } catch (e) {
      print('Error loading statistics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải thống kê: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      setState(() {
        isLoadingData = false;
        isRefreshing = false;
      });
    }
  }

  void _applyQuickFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _endDate = DateTime.now();
      
      switch (filter) {
        case '7_days':
          _startDate = _endDate!.subtract(const Duration(days: 7));
          break;
        case '30_days':
          _startDate = _endDate!.subtract(const Duration(days: 30));
          break;
        case '90_days':
          _startDate = _endDate!.subtract(const Duration(days: 90));
          break;
        case 'all_time':
          _startDate = DateTime(2025, 9, 1);
          break;
      }
    });
    _loadStatistics(showFullLoading: false); // Không show full loading
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 9, 1),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFilter = 'custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadStatistics(showFullLoading: false); // Không show full loading
    }
  }

  @override
  Widget build(BuildContext context) {
    // Chỉ show loading spinner lần đầu
    if (isLoadingData && _statistics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadStatistics(showFullLoading: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Filter Section
              _buildDateFilter(),
              const SizedBox(height: 16),

              // Linear progress indicator khi refresh - GỌN GÀN HƠN
              if (isRefreshing)
                Column(
                  children: const [
                    LinearProgressIndicator(color: Colors.blue),
                    SizedBox(height: 16),
                  ],
                ),

              // Overview Cards
              AnimatedOpacity(
                opacity: isRefreshing ? 0.6 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Lọc theo thời gian',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_startDate != null && _endDate != null)
                  Text(
                    '${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Quick filter buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('7 ngày', '7_days'),
                  const SizedBox(width: 8),
                  _buildFilterChip('30 ngày', '30_days'),
                  const SizedBox(width: 8),
                  _buildFilterChip('90 ngày', '90_days'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Tất cả', 'all_time'),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Tùy chỉnh'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedFilter == 'custom'
                          ? Colors.blue.withOpacity(0.1)
                          : null,
                      foregroundColor: _selectedFilter == 'custom'
                          ? Colors.blue
                          : Colors.grey[700],
                      side: BorderSide(
                        color: _selectedFilter == 'custom'
                            ? Colors.blue
                            : Colors.grey[300]!,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) _applyQuickFilter(value);
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey[300]!,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildOverviewCards() {
    if (_statistics == null) return const SizedBox.shrink();
    
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
    if (_statistics == null || _statistics!.weeklyExercises.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('Chưa có dữ liệu'),
      );
    }

    // Tính max value và interval động
    final maxValue = _statistics!.weeklyExercises.values.reduce((a, b) => a > b ? a : b);
    double interval;
    
    if (maxValue <= 10) {
      interval = 2;
    } else if (maxValue <= 20) {
      interval = 5;
    } else if (maxValue <= 50) {
      interval = 10;
    } else if (maxValue <= 100) {
      interval = 20;
    } else {
      interval = 50;
    }

    final maxY = ((maxValue / interval).ceil() + 1) * interval;

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
          maxY: maxY.toDouble(),
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
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        keys[value.toInt()],
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
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
    if (_statistics == null || _statistics!.totalExercisesCompleted == 0) {
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