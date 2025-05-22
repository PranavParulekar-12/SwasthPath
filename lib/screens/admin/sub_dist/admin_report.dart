import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminScheme extends StatefulWidget {
  const AdminScheme({super.key});

  @override
  State<AdminScheme> createState() => _AdminSchemeState();
}

class _AdminSchemeState extends State<AdminScheme> {
  late Future<Map<String, int>> _schemeDataFuture;
  String? selectedScheme;
  List<Map<String, dynamic>> lineChartData = [];
  int totalSchemes = 0;
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _schemeDataFuture = fetchSchemeDataFromSupabase();
  }

  Future<Map<String, int>> fetchSchemeDataFromSupabase() async {
    final adminId = await _secureStorage.read(key: 'adminId');
    if (adminId == null) {
      throw Exception('Admin ID not found in secure storage');
    }

    // Fetch sub_dist for the admin
    final adminResponse = await Supabase.instance.client
        .from('admin')
        .select('sub_dist')
        .eq('id', adminId)
        .maybeSingle();

    if (adminResponse == null || adminResponse['sub_dist'] == null) {
      throw Exception('Sub-district not found for admin');
    }

    final adminSubDist = adminResponse['sub_dist'] as String;

    // Fetch schemes data for the last 8 days
    final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
    final response = await Supabase.instance.client
        .from('applied_schemes') // Change to the appropriate table name
        .select('scheme_name, created_at, sub_dist')
        .eq('sub_dist', adminSubDist)
        .gte('created_at', eightDaysAgo.toIso8601String());

    final data = response as List<dynamic>;

    Map<String, int> schemeCount = {};
    for (var entry in data) {
      final scheme = entry['scheme_name'] as String;
      schemeCount[scheme] = (schemeCount[scheme] ?? 0) + 1;
    }

    totalSchemes = schemeCount.values.fold(0, (sum, count) => sum + count);

    return schemeCount;
  }

  Future<List<Map<String, dynamic>>> fetchSchemeTrend(String scheme) async {
    final adminId = await _secureStorage.read(key: 'adminId');
    if (adminId == null) {
      throw Exception('Admin ID not found in secure storage');
    }

    // Fetch sub_dist for the admin
    final adminResponse = await Supabase.instance.client
        .from('admin')
        .select('sub_dist')
        .eq('id', adminId)
        .maybeSingle();

    if (adminResponse == null || adminResponse['sub_dist'] == null) {
      throw Exception('Sub-district not found for admin');
    }

    final adminSubDist = adminResponse['sub_dist'] as String;

    // Filter trend data based on sub_dist and scheme
    final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
    final response = await Supabase.instance.client
        .from('applied_schemes') // Adjust table name here if needed
        .select('created_at')
        .eq('scheme_name', scheme)
        .eq('sub_dist', adminSubDist)
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
            future: _schemeDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No data available'));
              } else {
                final data = snapshot.data!;
                final sortedSchemes = data.entries.toList()
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
                                'Total Schemes Recorded: $totalSchemes',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black54),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Most Prevalent Schemes:',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black54),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: sortedSchemes
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

                      // Trending Schemes
                      const Text(
                        'Trending Schemes',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      SchemesChart(
                        schemeData: data,
                      ),
                      const SizedBox(height: 16),

                      // Divider
                      const Divider(),
                      const Text(
                        'Scheme Trend',
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
                          hint: const Text('Select a scheme'),
                          value: selectedScheme,
                          isExpanded: true,
                          onChanged: (value) async {
                            if (value != null) {
                              setState(() {
                                selectedScheme = value;
                              });
                              final trendData =
                                  await fetchSchemeTrend(selectedScheme!);
                              setState(() {
                                lineChartData = trendData;
                              });
                            }
                          },
                          items: data.keys
                              .map((scheme) => DropdownMenuItem(
                                    value: scheme,
                                    child: Text(scheme),
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
                                    'Select a scheme to view the trend',
                                    style: TextStyle(
                                        color: Colors.black54, fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : SchemeLineChart(data: lineChartData),
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

class SchemesChart extends StatelessWidget {
  final Map<String, int> schemeData;

  const SchemesChart({super.key, required this.schemeData});

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
                  final scheme = schemeData.keys.toList()[value.toInt()];
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      scheme,
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
          barGroups: schemeData.entries
              .map(
                (e) => BarChartGroupData(
                  x: schemeData.keys.toList().indexOf(e.key),
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

class SchemeLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const SchemeLineChart({super.key, required this.data});

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
