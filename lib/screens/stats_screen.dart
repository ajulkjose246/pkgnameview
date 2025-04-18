import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:convert';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const platform = MethodChannel('app.usage/stats');
  bool _isLoading = true;
  List<AppUsageInfo> _usageStats = [];
  String? _error;
  final int _batchSize = 8; // Number of icons to load at once
  int _loadedIconsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUsageStats();
  }

  Future<void> _loadUsageStats() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // First load usage stats without icons
      final List<dynamic> result = await platform.invokeMethod('getUsageStats');

      // Create a map to combine duplicate entries
      final Map<String, AppUsageInfo> statsMap = {};

      for (var data in result) {
        final AppUsageInfo stat = AppUsageInfo.fromMap(data);
        if (statsMap.containsKey(stat.packageName)) {
          // Combine usage times for the same app
          final existing = statsMap[stat.packageName]!;
          final combinedTime = _addUsageTimes(
            existing.usageTime,
            stat.usageTime,
          );
          statsMap[stat.packageName] = AppUsageInfo(
            packageName: stat.packageName,
            appName: stat.appName,
            usageTime: combinedTime,
            lastUsed: stat.lastUsed,
          );
        } else {
          statsMap[stat.packageName] = stat;
        }
      }

      // Convert map back to list and sort by usage time
      final stats =
          statsMap.values.toList()..sort(
            (a, b) => _parseUsageTime(
              b.usageTime,
            ).compareTo(_parseUsageTime(a.usageTime)),
          );

      setState(() {
        _usageStats = stats;
        _isLoading = false;
      });

      // Load icons in batches
      await _loadIconsBatch();
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load app usage stats';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadIconsBatch() async {
    while (_loadedIconsCount < _usageStats.length && mounted) {
      final endIndex = min(_loadedIconsCount + _batchSize, _usageStats.length);
      final batch = _usageStats.sublist(_loadedIconsCount, endIndex);

      await Future.wait(
        batch.map((stat) async {
          try {
            final appInfo = await InstalledApps.getAppInfo(
              stat.packageName,
              null,
            ).timeout(
              const Duration(seconds: 2),
              onTimeout: () => throw TimeoutException('Icon load timeout'),
            );

            if (!mounted) return;

            setState(() {
              stat.appInfo = appInfo;
            });
          } catch (e) {
            debugPrint('Failed to load icon for ${stat.packageName}: $e');
          }
        }),
      );

      _loadedIconsCount = endIndex;

      // Add a small delay between batches to prevent overload
      if (endIndex < _usageStats.length) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_usageStats.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade900, Colors.black],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          // Simple Clean AppBar
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: Colors.blue.shade900.withOpacity(0.8),
            title: const Text(
              'Screen Time',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Total Time Card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade400.withOpacity(0.2),
                    Colors.blue.shade900.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 32,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatTotalTime(_getTotalUsage()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Screen Time Today',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Stats Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCards(),
                  const SizedBox(height: 24),
                  Text(
                    'App Usage Breakdown',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // App Usage List
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index >= _usageStats.length) return null;
              return _buildEnhancedAppCard(_usageStats[index]);
            }),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final totalMinutes = _getTotalUsage();
    final mostUsedApp = _usageStats.isNotEmpty ? _usageStats[0] : null;

    return Row(
      children: [
        Expanded(
          child: _buildStatsCard(
            icon: Icons.apps_rounded,
            title: 'Total Apps',
            value: '${_usageStats.length}',
            color: Colors.green.shade400,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatsCard(
            icon: Icons.star,
            title: 'Most Used',
            value: mostUsedApp?.appName ?? 'N/A',
            color: Colors.orange.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedAppCard(AppUsageInfo usage) {
    final duration = _parseUsageTime(usage.usageTime);
    final totalMinutes = _getTotalUsage();
    final percentage = totalMinutes > 0 ? (duration / totalMinutes * 100) : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Stack(
        children: [
          // Progress indicator with minimum width
          ClipRRect(
            // Add ClipRRect to ensure the progress stays within bounds
            borderRadius: BorderRadius.circular(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate width with minimum threshold
                final minWidth = 30.0; // Minimum width in pixels
                final calculatedWidth =
                    constraints.maxWidth * (percentage / 100);
                final width =
                    duration > 0 ? max(minWidth, calculatedWidth) : 0.0;

                return Container(
                  height: 80,
                  width: width,
                  decoration: BoxDecoration(
                    color: _getChartColor(
                      _usageStats.indexOf(usage),
                    ).withOpacity(0.2),
                  ),
                );
              },
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAppIcon(usage),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usage.appName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${percentage.toStringAsFixed(1)}% of total time',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getChartColor(
                      _usageStats.indexOf(usage),
                    ).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getChartColor(
                        _usageStats.indexOf(usage),
                      ).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    usage.usageTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppIcon(AppUsageInfo usage) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (usage.appInfo == null)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            if (usage.appInfo != null) usage.getIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading app usage stats...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          const Text(
            'Permission Required',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Please grant usage access permission in system settings to view app statistics.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _loadUsageStats(),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No usage data available',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }

  double _getTotalUsage() {
    double total = 0;
    for (var stat in _usageStats) {
      total += _parseUsageTime(stat.usageTime);
    }
    return total;
  }

  String _addUsageTimes(String time1, String time2) {
    final minutes1 = _parseUsageTime(time1);
    final minutes2 = _parseUsageTime(time2);
    final totalMinutes = minutes1 + minutes2;

    final hours = (totalMinutes / 60).floor();
    final minutes = (totalMinutes % 60).round();

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class AppUsageInfo {
  final String packageName;
  final String appName;
  final String usageTime;
  final String lastUsed;
  AppInfo? appInfo;

  AppUsageInfo({
    required this.packageName,
    required this.appName,
    required this.usageTime,
    required this.lastUsed,
    this.appInfo,
  });

  factory AppUsageInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppUsageInfo(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      usageTime: map['usageTime'] as String,
      lastUsed: map['lastUsed'] as String,
    );
  }

  Widget getIcon({double size = 48}) {
    if (appInfo?.icon != null) {
      return Image.memory(
        appInfo!.icon!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _fallbackIcon(size),
        cacheWidth: size.toInt() * 2,
        cacheHeight: size.toInt() * 2,
      );
    }
    return _fallbackIcon(size);
  }

  Widget _fallbackIcon(double size) {
    return Icon(Icons.android, size: size, color: Colors.white);
  }
}

class AppUsageData {
  final String appName;
  final double duration;
  final Color color;

  AppUsageData({
    required this.appName,
    required this.duration,
    required this.color,
  });
}

double _parseUsageTime(String usageTime) {
  final parts = usageTime.split(' ');
  double minutes = 0;
  for (var part in parts) {
    if (part.endsWith('h')) {
      minutes += double.parse(part.replaceAll('h', '')) * 60;
    } else if (part.endsWith('m')) {
      minutes += double.parse(part.replaceAll('m', ''));
    }
  }
  return minutes;
}

String _formatDuration(double minutes) {
  final hours = (minutes / 60).floor();
  final mins = (minutes % 60).round();
  if (hours > 0) {
    return '${hours}h ${mins}m';
  }
  return '${mins}m';
}

String _formatTotalTime(double minutes) {
  final hours = (minutes / 60).floor();
  final mins = (minutes % 60).round();
  return '$hours hr, $mins min';
}

Color _getChartColor(int index) {
  final colors = [
    Colors.blue.shade400,
    Colors.purple.shade400,
    Colors.green.shade400,
    Colors.orange.shade400,
    Colors.pink.shade400,
    Colors.teal.shade400,
    Colors.indigo.shade400,
  ];
  return colors[index % colors.length];
}
