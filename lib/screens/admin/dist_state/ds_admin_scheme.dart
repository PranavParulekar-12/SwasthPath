import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DSSchemesHome extends StatefulWidget {
  const DSSchemesHome({super.key});

  @override
  State<DSSchemesHome> createState() => _DSSchemesHomeState();
}

class _DSSchemesHomeState extends State<DSSchemesHome> {
  late Future<List<String>> _subDistrictsFuture;
  late Future<Map<String, int>> _schemeDataFuture;
  late Future<List<Map<String, dynamic>>> _schemeTrendFuture;
  String? selectedSubDistrict;
  String? selectedScheme;
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _subDistrictsFuture = fetchSubDistricts();
  }

  Future<List<String>> fetchSubDistricts() async {
    final adminId = await _secureStorage.read(key: 'adminId');
    if (adminId == null) {
      throw Exception('Admin ID not found in secure storage');
    }

    final adminResponse = await Supabase.instance.client
        .from('admin')
        .select('state, dist')
        .eq('id', adminId)
        .maybeSingle();

    if (adminResponse == null ||
        adminResponse['state'] == null ||
        adminResponse['dist'] == null) {
      throw Exception('State or district not found for admin');
    }

    final state = adminResponse['state'] as String;
    final dist = adminResponse['dist'] as String;

    final subDistResponse = await Supabase.instance.client
        .from(state)
        .select('sub_dist')
        .eq('dist', dist);

    final data = subDistResponse as List<dynamic>;

    final uniqueSubDistricts =
        data.map((entry) => entry['sub_dist'] as String).toSet().toList();

    return uniqueSubDistricts;
  }

  void loadSubDistrictData(String subDist) {
    setState(() {
      selectedSubDistrict = subDist;
      _schemeDataFuture = fetchSchemeDataFromSupabase(subDist);
      _schemeTrendFuture = fetchSchemeTrend(selectedScheme ?? '');
    });
  }

  Future<Map<String, int>> fetchSchemeDataFromSupabase(String subDist) async {
    final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
    final response = await Supabase.instance.client
        .from('applied_schemes')
        .select('scheme_name, created_at')
        .eq('sub_dist', subDist)
        .gte('created_at', eightDaysAgo.toIso8601String());

    final data = response as List<dynamic>;
    Map<String, int> schemeCount = {};
    for (var entry in data) {
      final scheme = entry['scheme_name'] as String;
      schemeCount[scheme] = (schemeCount[scheme] ?? 0) + 1;
    }

    print("Scheme Count: $schemeCount");

    return schemeCount;
  }

  Future<List<Map<String, dynamic>>> fetchSchemeTrend(String scheme) async {
    final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
    final response = await Supabase.instance.client
        .from('applied_schemes')
        .select('created_at')
        .eq('scheme_name', scheme)
        .eq('sub_dist', selectedSubDistrict!)
        .gte('created_at', eightDaysAgo.toIso8601String())
        .order('created_at', ascending: true);

    print('Supabase Response: $response');

    final data = response as List<dynamic>;

    Map<String, int> trendData = {};
    DateTime startDate = DateTime.now().subtract(const Duration(days: 8));

    for (int i = 0; i <= 8; i++) {
      final date =
          startDate.add(Duration(days: i)).toIso8601String().split('T').first;
      trendData[date] = 0;
    }

    for (var entry in data) {
      final createdAtDate = DateTime.parse(entry['created_at'] as String);
      final date = createdAtDate.toIso8601String().split('T').first;
      trendData[date] = (trendData[date] ?? 0) + 1;
    }

    print("Processed Trend Data: $trendData");

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
          child: FutureBuilder<List<String>>(
            future: _subDistrictsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No sub-districts available'));
              } else {
                final subDistricts = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButton<String>(
                      hint: const Text('Select a Sub-District'),
                      value: selectedSubDistrict,
                      isExpanded: true,
                      onChanged: (value) {
                        if (value != null) {
                          loadSubDistrictData(value);
                        }
                      },
                      items: subDistricts
                          .map((subDist) => DropdownMenuItem(
                                value: subDist,
                                child: Text(subDist),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    if (selectedSubDistrict != null)
                      FutureBuilder<Map<String, int>>(
                        future: _schemeDataFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}'));
                          } else if (!snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return const Center(
                                child: Text('No data available'));
                          } else {
                            final data = snapshot.data!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Scheme Trend',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SchemesChart(schemeData: data),
                                const SizedBox(height: 16),
                                DropdownButton<String>(
                                  hint: const Text('Select a Scheme'),
                                  value: selectedScheme,
                                  isExpanded: true,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        selectedScheme = value;
                                        _schemeTrendFuture =
                                            fetchSchemeTrend(value);
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
                                const SizedBox(height: 16),
                                if (selectedScheme != null)
                                  FutureBuilder<List<Map<String, dynamic>>>(
                                    future: _schemeTrendFuture,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                            child: CircularProgressIndicator());
                                      } else if (snapshot.hasError) {
                                        return Center(
                                            child: Text(
                                                'Error: ${snapshot.error}'));
                                      } else if (!snapshot.hasData ||
                                          snapshot.data!.isEmpty) {
                                        return const Center(
                                            child: Text('No data available'));
                                      } else {
                                        final trendData = snapshot.data!;
                                        return SchemeLineChart(data: trendData);
                                      }
                                    },
                                  ),
                              ],
                            );
                          }
                        },
                      ),
                  ],
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
                horizontal: BorderSide(color: Colors.grey)),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value % 1 == 0) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final keys = schemeData.keys.toList();
                  if (value.toInt() >= 0 && value.toInt() < keys.length) {
                    return Text(
                      keys[value.toInt()],
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
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
          barGroups: schemeData.entries.map((entry) {
            final index = schemeData.keys.toList().indexOf(entry.key);
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: entry.value.toDouble(),
                  color: Colors.blue,
                  width: 15,
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  // Adding titles on top of the bars
                  rodStackItems: [
                    BarChartRodStackItem(0, entry.value.toDouble(),
                        Colors.transparent) // Ensure rod covers the whole bar
                  ],
                ),
              ],
            );
          }).toList(),
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
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(
            show: true,
            border: const Border.symmetric(
                horizontal: BorderSide(color: Colors.grey)),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value % 1 == 0) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final dateIndexes = data.asMap().keys.toList();
                  if (value.toInt() >= 0 &&
                      value.toInt() < dateIndexes.length) {
                    final dateStr = data[value.toInt()]['date'];
                    if (dateStr != null) {
                      final date = DateTime.parse(dateStr);
                      final formattedDate = DateFormat('dd/MM').format(date);
                      return Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                data.length,
                (index) => FlSpot(
                  index.toDouble(),
                  (data[index]['count'] as int).toDouble(),
                ),
              ),
              isCurved: false,
              barWidth: 4,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                  show: false), // Optionally hide the area below the line
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.blueAccent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
