import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:device_apps/device_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const platform = MethodChannel('com.example.vero/settings');
  
  final GlobalKey _shareKey = GlobalKey(); 

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  
  bool _isLoading = true;
  int _thisWeekTotalMs = 0;
  int _lastWeekTotalMs = 0;
  List<Map<String, dynamic>> _culprits = [];
  
  Map<String, int> _focusHistory = {};
  
  int _slideDirection = 1;
  bool _showWeeklyChart = true;


  @override
  void initState() {
    super.initState();
    _initDates();
    _fetchStats();
    _loadHeatmapData();
  }

  void _initDates() {
    final now = DateTime.now();
    _startDate = now.subtract(Duration(days: now.weekday - 1));
    _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day); 
    _endDate = _startDate.add(const Duration(days: 6, hours: 23, minutes: 59));
  }
  
  Future<void> _loadHeatmapData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); 
    
    String? historyJson = prefs.getString('daily_focus_history');
    if (historyJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(historyJson);
        final Map<String, int> history = {};
        
        decoded.forEach((key, value) {
           if (value is int) {
             history[key] = value;
           } else if (value is double) {
             history[key] = value.toInt();
           } else if (value is String) {
             history[key] = int.tryParse(value) ?? 0;
           }
        });
        
        if (mounted) {
          setState(() {
            _focusHistory = history;
          });
        }
      } catch (e) {
        print("Error parsing focus history: $e");
      }
    }
  }


  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final thisWeekData = await platform.invokeMethod('getAppUsageStats', {
        'start': _startDate.millisecondsSinceEpoch,
        'end': _endDate.millisecondsSinceEpoch, 
      });

      final lastWeekStart = _startDate.subtract(const Duration(days: 7));
      final lastWeekEnd = _endDate.subtract(const Duration(days: 7));
      final lastWeekData = await platform.invokeMethod('getAppUsageStats', {
        'start': lastWeekStart.millisecondsSinceEpoch,
        'end': lastWeekEnd.millisecondsSinceEpoch,
      });

      _thisWeekTotalMs = thisWeekData['totalTime'] ?? 0;
      _lastWeekTotalMs = lastWeekData['totalTime'] ?? 0;

      List<dynamic> rawApps = thisWeekData['apps'] ?? [];
      rawApps.sort((a, b) => (b['time'] as int).compareTo(a['time'] as int));
      
      _culprits = [];
      for (var item in rawApps.take(5)) {
        String pkg = item['package'];
        int time = item['time'];
        String name = pkg.split('.').last; 
        
        try {
          if (await DeviceApps.isAppInstalled(pkg)) {
            final Application? app = await DeviceApps.getApp(pkg, true);
            if (app != null) {
              name = app.appName;
            }
          }
        } catch (e) { }

        _culprits.add({
          'pkg': pkg,
          'name': name,
          'time': _formatDuration(time),
          'rawTime': time,
          'color': _getColorForIndex(_culprits.length)
        });
      }

    } catch (e) {
      print("Stats Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeWeek(int offset) {
    HapticFeedback.selectionClick();
    setState(() {
      _slideDirection = offset;
      _startDate = _startDate.add(Duration(days: offset * 7));
      _endDate = _endDate.add(Duration(days: offset * 7));
    });
    _fetchStats();
  }


  Future<void> _shareStats() async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));

      RenderRepaintBoundary? boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        return;
      }

      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 20));
      }

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        await platform.invokeMethod('shareScreenImage', {'bytes': pngBytes});
      }
    } catch (e) {
      print("Share Error: $e");
    }
  }

  String _formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    if (duration.inHours > 0) {
      return "${duration.inHours}h ${duration.inMinutes % 60}m";
    }
    return "${duration.inMinutes}m";
  }

  Color _getColorForIndex(int index) {
    const colors = [Colors.purpleAccent, Colors.blueAccent, Colors.orangeAccent, Colors.greenAccent, Colors.redAccent];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A0B2E), Colors.black],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.grey, size: 16), 
                        onPressed: () => _changeWeek(-1)
                      ),
                      const SizedBox(width: 20),
                      Text(
                        "${_startDate.month}/${_startDate.day} - ${_endDate.month}/${_endDate.day}", 
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16), 
                        onPressed: () => _changeWeek(1)
                      ),
                    ],
                  ),
                ),
    
                Expanded(
                  child: ClipRect( 
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeInOutCubic,
                      switchOutCurve: Curves.easeInOutCubic,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        final isEntering = child.key == ValueKey(_startDate);
                        final dx = _slideDirection.toDouble();
                        final inTween = Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero);
                        final outTween = Tween<Offset>(begin: Offset(-dx, 0), end: Offset.zero);

                        return SlideTransition(
                          position: isEntering 
                            ? inTween.animate(animation) 
                            : outTween.animate(animation),
                          child: child,
                        );
                      },
                      child: _isLoading 
                        ? const Center(key: ValueKey('loading'), child: CircularProgressIndicator(color: Colors.purpleAccent))
                        : KeyedSubtree(
                            key: ValueKey(_startDate), 
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
                              child: _buildStatsColumn(), 
                            ),
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 20, right: 20, bottom: 20,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _shareStats();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.share, size: 20),
                      SizedBox(width: 10),
                      Text("Share", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: -9999,
            top: 0,
            child: UnconstrainedBox(
              child: RepaintBoundary(
                key: _shareKey,
                child: Container(
                  width: 400, 
                  color: const Color(0xFF0F0518), 
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 40),
                      const Text("VERO STATS", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 32, color: Colors.white)),
                      const SizedBox(height: 10),
                      Text(
                        "${_startDate.month}/${_startDate.day} - ${_endDate.month}/${_endDate.day}", 
                        style: const TextStyle(color: Colors.grey, fontSize: 16)
                      ),
                      const SizedBox(height: 30),
                      _buildStatsColumn(), 
                      const SizedBox(height: 40),
                      const Text("Generated by VERO", style: TextStyle(color: Colors.white24, fontSize: 10)),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsColumn() {
    int diff = _thisWeekTotalMs - _lastWeekTotalMs;
    String diffStr = _formatDuration(diff.abs());
    String comparisonText = diff > 0 
        ? "You spent $diffStr more than last week" 
        : "You saved $diffStr compared to last week!";
    
    double max = (_thisWeekTotalMs > _lastWeekTotalMs ? _thisWeekTotalMs : _lastWeekTotalMs).toDouble();
    if (max == 0) max = 1;
    double h1 = (_lastWeekTotalMs / max) * 160;
    double h2 = (_thisWeekTotalMs / max) * 160;

    double maxWeeklyMinutes = 0;
    for (int i = 0; i < 7; i++) {
      DateTime day = _startDate.add(Duration(days: i));
      String key = "${day.year}-${day.month}-${day.day}";
      double minutes = (_focusHistory[key] ?? 0).toDouble();
      if (minutes > maxWeeklyMinutes) maxWeeklyMinutes = minutes;
    }
    double chartMaxY = (maxWeeklyMinutes > 120 ? maxWeeklyMinutes : 120) * 1.2;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 15, right: 10),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showWeeklyChart = !_showWeeklyChart);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_showWeeklyChart ? Icons.bar_chart : Icons.compare_arrows, color: Colors.purpleAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _showWeeklyChart ? "Daily View" : "Comparison",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (_showWeeklyChart)
          Container(
            height: 300,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF150A1F),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Daily Focus", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Expanded(
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: chartMaxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.purpleAccent,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${rod.toY.round()}m',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                              const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                              if (value.toInt() >= 0 && value.toInt() < days.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(days[value.toInt()], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: _getWeeklyBarGroups(chartMaxY),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF150A1F),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Text(
                  comparisonText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 60,
                          height: h1 < 10 ? 10 : h1,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                        ),
                        const SizedBox(height: 10),
                        const Text("Last week", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(_formatDuration(_lastWeekTotalMs), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(width: 40),
                    Column(
                      children: [
                        Container(
                          width: 60,
                          height: h2 < 10 ? 10 : h2,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF4B4B), Color(0xFF8B0000)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 30, spreadRadius: 5)],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text("This week", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(_formatDuration(_thisWeekTotalMs), style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 30),
        const Align(alignment: Alignment.centerLeft, child: Text("Focus History", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))),
        const SizedBox(height: 15),
        _buildHeatmap(),

        const SizedBox(height: 30),
        const Align(alignment: Alignment.centerLeft, child: Text("Culprit Apps", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))),
        const SizedBox(height: 20),
        if (_culprits.isEmpty) 
          const Padding(padding: EdgeInsets.all(20), child: Text("No usage data yet.", style: TextStyle(color: Colors.grey))),
        ..._culprits.map((app) => _buildCulpritRow(
          app['pkg'], app['name'], app['time'], app['color'], app['rawTime'] / (_thisWeekTotalMs == 0 ? 1 : _thisWeekTotalMs)
        )),
      ],
    );
  }

  List<BarChartGroupData> _getWeeklyBarGroups(double maxY) {
    List<BarChartGroupData> groups = [];
    
    DateTime startOfWeek = _startDate;

    for (int i = 0; i < 7; i++) {
      DateTime day = startOfWeek.add(Duration(days: i));
      String key = "${day.year}-${day.month}-${day.day}";
      double minutes = (_focusHistory[key] ?? 0).toDouble();

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: minutes,
              color: minutes > 0 ? Colors.purpleAccent : Colors.white10,
              width: 16,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ],
        ),
      );
    }
    return groups;
  }


  Widget _buildHeatmap() {
    final now = DateTime.now();
    final List<DateTime> days = [];
    for (int i = 27; i >= 0; i--) {
      days.add(now.subtract(Duration(days: i)));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Last 4 Weeks", style: TextStyle(color: Colors.white, fontSize: 14)),
              Text("Less ⬜ 🟩 🟩 🟩 More", style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 28,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, 
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final date = days[index];
              final dateKey = "${date.year}-${date.month}-${date.day}";
              final minutes = _focusHistory[dateKey] ?? 0;
              
              Color color = Colors.white10;
              if (minutes > 0) color = Colors.green.withOpacity(0.3);
              if (minutes > 30) color = Colors.green.withOpacity(0.6);
              if (minutes > 60) color = Colors.greenAccent;

              return Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white12),
                ),
                child: Center(
                  child: Text(
                    "${date.day}",
                    style: TextStyle(fontSize: 10, color: minutes > 0 ? Colors.black : Colors.grey),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCulpritRow(String pkg, String name, String time, Color color, double factor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          FutureBuilder(
            future: DeviceApps.getApp(pkg, true),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data is ApplicationWithIcon) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Image.memory((snapshot.data as ApplicationWithIcon).icon, width: 24, height: 24),
                );
              }
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.android, color: color, size: 24),
              );
            }
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(time, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
          Container(
            height: 4,
            width: 100,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: factor.clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            ),
          ),
        ],
      ),
    );
  }
}
