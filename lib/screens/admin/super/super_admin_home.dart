import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class SuperAdminDiseases extends StatefulWidget {
  const SuperAdminDiseases({super.key});

  @override
  State<SuperAdminDiseases> createState() => _SuperAdminDiseasesState();
}

class _SuperAdminDiseasesState extends State<SuperAdminDiseases> {
  late Future<Map<String, int>> _diseaseDataFuture;
  String? selectedDisease;
  List<Map<String, dynamic>> lineChartData = [];
  int totalDiseases = 0;

  @override
  void initState() {
    super.initState();
    _diseaseDataFuture = fetchDiseaseDataFromSupabase();
  }

  Future<Map<String, int>> fetchDiseaseDataFromSupabase() async {
    // Fetch all disease data for the last 8 days
    final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
    final response = await Supabase.instance.client
        .from('diseases') // Change to the appropriate table name
        .select('disease, created_at')
        .gte('created_at', eightDaysAgo.toIso8601String());

    final data = response as List<dynamic>;

    Map<String, int> diseaseCount = {};
    for (var entry in data) {
      final disease = entry['disease'] as String;
      diseaseCount[disease] = (diseaseCount[disease] ?? 0) + 1;
    }

    totalDiseases = diseaseCount.values.fold(0, (sum, count) => sum + count);

    return diseaseCount;
  }

  Future<List<Map<String, dynamic>>> fetchDiseaseTrend(String disease) async {
    // Fetch trend data for a specific disease over the last 8 days
    final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
    final response = await Supabase.instance.client
        .from('diseases') // Adjust table name here if needed
        .select('created_at')
        .eq('disease', disease)
        .gte('created_at', eightDaysAgo.toIso8601String())
        .order('created_at', ascending: true);

    final data = response as List<dynamic>;

    // Prepare date range for the last 8 days
    Map<String, int> trendData = {};
    DateTime startDate = DateTime.now().subtract(const Duration(days: 8));

    // Initialize trend data map with 0 counts for each day
    for (int i = 0; i <= 8; i++) {
      final date =
          startDate.add(Duration(days: i)).toIso8601String().split('T').first;
      trendData[date] = 0;
    }

    // Count occurrences for each date in the fetched data
    for (var entry in data) {
      final date = (entry['created_at'] as String).split('T').first;
      trendData[date] = (trendData[date] ?? 0) + 1;
    }

    return trendData.entries
        .map((e) => {"date": e.key, "count": e.value})
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: FutureBuilder<Map<String, int>>(
            future: _diseaseDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No data available'));
              } else {
                final data = snapshot.data!;
                final sortedDiseases = data.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Section
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Summary',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Total Diseases Reported: $totalDiseases',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black54),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Most Prevalent Diseases:',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black54),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: sortedDiseases
                                    .take(3)
                                    .map((e) => Text(
                                          '${e.key}: ${e.value}',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Trending Diseases
                      const Text(
                        'Trending Diseases',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      DiseasesChart(
                        diseaseData: data,
                      ),
                      const SizedBox(height: 16),

                      // Divider
                      const Divider(),
                      const Text(
                        'Disease Trend',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 16),

                      // Dropdown
                      Padding(
                        padding: const EdgeInsets.only(left: 10, right: 10),
                        child: DropdownButton<String>(
                          hint: const Text('Select a disease'),
                          value: selectedDisease,
                          isExpanded: true,
                          onChanged: (value) async {
                            if (value != null) {
                              setState(() {
                                selectedDisease = value;
                              });
                              final trendData =
                                  await fetchDiseaseTrend(selectedDisease!);
                              setState(() {
                                lineChartData = trendData;
                              });
                            }
                          },
                          items: data.keys
                              .map((disease) => DropdownMenuItem(
                                    value: disease,
                                    child: Text(disease),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Line Chart or Prompt
                      lineChartData.isEmpty
                          ? const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.bar_chart,
                                      size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'Select a disease to view the trend',
                                    style: TextStyle(
                                        color: Colors.black54, fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : DiseaseLineChart(data: lineChartData),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

class DiseasesChart extends StatelessWidget {
  final Map<String, int> diseaseData;

  const DiseasesChart({super.key, required this.diseaseData});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(
              show: true,
              border: const Border.symmetric(
                  horizontal: BorderSide(color: Colors.grey))),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value % 1 != 0) return Container(); // Show only integers
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final disease = diseaseData.keys.toList()[value.toInt()];
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      disease,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          barGroups: diseaseData.entries
              .map(
                (e) => BarChartGroupData(
                  x: diseaseData.keys.toList().indexOf(e.key),
                  barRods: [
                    BarChartRodData(
                      toY: e.value.toDouble(),
                      width: 16,
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.purple],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    )
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class DiseaseLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const DiseaseLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Filter data for the last 8 days
    List<Map<String, dynamic>> filteredData = [];
    DateTime today = DateTime.now();
    for (var entry in data) {
      DateTime date = DateTime.parse(entry['date']);
      if (date.isAfter(today.subtract(const Duration(days: 8)))) {
        filteredData.add(entry);
      }
    }

    // Format dates in MM/dd format
    DateFormat dateFormat = DateFormat('MM/dd');

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(
            border: const Border(
              left: BorderSide(color: Colors.black12),
              bottom: BorderSide(color: Colors.black12),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value % 1 != 0) return Container(); // Show only integers
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final date = filteredData[value.toInt()]['date'] ?? '';
                  final formattedDate = dateFormat.format(DateTime.parse(date));
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: false,
              color: Colors.purple,
              spots: filteredData
                  .map((e) => FlSpot(
                        filteredData.indexOf(e).toDouble(),
                        e['count'].toDouble(),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
