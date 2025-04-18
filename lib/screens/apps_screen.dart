import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  List<AppInfo> _userApps = [];
  List<AppInfo> _systemApps = [];
  List<AppInfo> _filteredUserApps = [];
  List<AppInfo> _filteredSystemApps = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  late TabController _tabController;
  double _loadingProgress = 0.01;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      _filterAppsByType();
    }
  }

  Future<void> _loadApps() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Increase chunk size for better performance
      const chunkSize = 20;

      // Get apps with system flag to avoid separate system app checks
      final apps = await InstalledApps.getInstalledApps(false, true);
      final totalApps = apps.length;

      final userApps = <AppInfo>[];
      final systemApps = <AppInfo>[];

      // Process in larger chunks with progress updates
      for (var i = 0; i < apps.length; i += chunkSize) {
        final chunk = apps.skip(i).take(chunkSize);
        await Future.wait(
          chunk.map((app) async {
            try {
              final isSystem = await InstalledApps.isSystemApp(app.packageName);
              if (isSystem != null) {
                if (isSystem) {
                  systemApps.add(app);
                } else {
                  userApps.add(app);
                }
              }
            } catch (e) {
              // Skip failed checks
            }
          }),
        );

        // Update progress
        setState(() {
          _loadingProgress = (i + chunkSize) / totalApps;

          // Sort only the new additions to avoid full resort
          userApps.sort(
            (a, b) => (a.name).toLowerCase().compareTo((b.name).toLowerCase()),
          );
          systemApps.sort(
            (a, b) => (a.name).toLowerCase().compareTo((b.name).toLowerCase()),
          );

          _userApps = userApps;
          _systemApps = systemApps;
          _filteredUserApps = userApps;
          _filteredSystemApps = systemApps;
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterAppsByType() {
    final query = _searchController.text.toLowerCase();

    // Filter user apps
    var userApps = _userApps;
    if (query.isNotEmpty && _tabController.index == 0) {
      userApps =
          userApps
              .where(
                (app) =>
                    (app.name.toLowerCase()).contains(query) ||
                    (app.packageName.toLowerCase()).contains(query),
              )
              .toList();
    }
    userApps.sort(
      (a, b) => (a.name).toLowerCase().compareTo((b.name).toLowerCase()),
    );

    // Filter system apps
    var systemApps = _systemApps;
    if (query.isNotEmpty && _tabController.index == 1) {
      systemApps =
          systemApps
              .where(
                (app) =>
                    (app.name.toLowerCase()).contains(query) ||
                    (app.packageName.toLowerCase()).contains(query),
              )
              .toList();
    }
    systemApps.sort(
      (a, b) => (a.name).toLowerCase().compareTo((b.name).toLowerCase()),
    );

    setState(() {
      _filteredUserApps = userApps;
      _filteredSystemApps = systemApps;
    });
  }

  void _filterApps(String query) {
    _filterAppsByType();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900.withOpacity(0.8),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search apps...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    border: InputBorder.none,
                  ),
                  onChanged: _filterApps,
                  autofocus: true,
                )
                : const Text(
                  'Package Viewer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            color: Colors.white,
            onPressed: _toggleSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          tabs: const [Tab(text: 'User Apps'), Tab(text: 'System Apps')],
        ),
      ),
      body:
          _isLoading
              ? _buildLoadingState()
              : TabBarView(
                controller: _tabController,
                children: [_buildAppList(true), _buildAppList(false)],
              ),
    );
  }

  Widget _buildAppList(bool isUserApps) {
    final apps = isUserApps ? _filteredUserApps : _filteredSystemApps;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 116),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 48,
                child: Builder(
                  builder: (context) {
                    if (app.icon != null) {
                      try {
                        return Image.memory(
                          app.icon!,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.android, color: Colors.white);
                          },
                          frameBuilder: (
                            context,
                            child,
                            frame,
                            wasSynchronouslyLoaded,
                          ) {
                            if (frame == null) {
                              return Icon(Icons.android, color: Colors.white);
                            }
                            return child;
                          },
                        );
                      } catch (e) {
                        return Icon(Icons.android, color: Colors.white);
                      }
                    }
                    return Icon(Icons.android, color: Colors.white);
                  },
                ),
              ),
            ),
            title: Text(
              app.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              app.packageName,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.copy, color: Colors.white.withOpacity(0.7)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: app.packageName));
              },
            ),
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.blue.shade900.withOpacity(0.5),
                builder: (BuildContext context) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),

                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: Icon(Icons.launch, color: Colors.white),
                              title: Text(
                                'Open App',
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                InstalledApps.startApp(app.packageName);
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.settings,
                                color: Colors.white,
                              ),
                              title: Text(
                                'Open Settings',
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                InstalledApps.openSettings(app.packageName);
                                Navigator.pop(context);
                              },
                            ),
                            if (isUserApps)
                              ListTile(
                                leading: Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                                title: Text(
                                  'Uninstall',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                onTap: () async {
                                  await InstalledApps.uninstallApp(
                                    app.packageName,
                                  );
                                  Navigator.pop(context);

                                  await Future.delayed(
                                    const Duration(seconds: 10),
                                  );
                                  final isInstalled =
                                      await InstalledApps.isAppInstalled(
                                        app.packageName,
                                      );
                                  if (!isInstalled!) {
                                    setState(() {
                                      _userApps.removeWhere(
                                        (a) => a.packageName == app.packageName,
                                      );
                                      _systemApps.removeWhere(
                                        (a) => a.packageName == app.packageName,
                                      );
                                      _filteredUserApps.removeWhere(
                                        (a) => a.packageName == app.packageName,
                                      );
                                      _filteredSystemApps.removeWhere(
                                        (a) => a.packageName == app.packageName,
                                      );
                                    });
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 50, color: Colors.white.withOpacity(0.9)),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                builder: (context, double value, child) {
                  return Transform.rotate(
                    angle: value * 2 * 3.14159,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                      value: _loadingProgress,
                    ),
                  );
                },
              ),
              Text(
                '${(_loadingProgress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Apps (${_userApps.length + _systemApps.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filterAppsByType();
      }
    });
  }
}
