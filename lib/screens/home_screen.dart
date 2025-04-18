import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<AppInfo> _installedApps = [];
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
              final isSystem = await InstalledApps.isSystemApp(
                app.packageName ?? '',
              );
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
            (a, b) => (a.name ?? '').toLowerCase().compareTo(
              (b.name ?? '').toLowerCase(),
            ),
          );
          systemApps.sort(
            (a, b) => (a.name ?? '').toLowerCase().compareTo(
              (b.name ?? '').toLowerCase(),
            ),
          );

          _userApps = userApps;
          _systemApps = systemApps;
          _filteredUserApps = userApps;
          _filteredSystemApps = systemApps;
        });
      }

      setState(() {
        _installedApps = apps;
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
                    (app.name?.toLowerCase() ?? '').contains(query) ||
                    (app.packageName?.toLowerCase() ?? '').contains(query),
              )
              .toList();
    }
    userApps.sort(
      (a, b) =>
          (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()),
    );

    // Filter system apps
    var systemApps = _systemApps;
    if (query.isNotEmpty && _tabController.index == 1) {
      systemApps =
          systemApps
              .where(
                (app) =>
                    (app.name?.toLowerCase() ?? '').contains(query) ||
                    (app.packageName?.toLowerCase() ?? '').contains(query),
              )
              .toList();
    }
    systemApps.sort(
      (a, b) =>
          (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()),
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search apps...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                  onChanged: _filterApps,
                  autofocus: true,
                )
                : const Text(
                  'Package Viewer',
                  style: TextStyle(color: Colors.white),
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
          tabs: const [Tab(text: 'User Apps'), Tab(text: 'System Apps')],
        ),
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.settings, size: 50, color: Colors.white70),
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
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Apps (${_userApps.length + _systemApps.length})',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [_buildAppList(true), _buildAppList(false)],
              ),
    );
  }

  Widget _buildAppList(bool isUserApps) {
    final apps = isUserApps ? _filteredUserApps : _filteredSystemApps;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return Card(
          color: const Color(0xFF2D2D2D),
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  app.icon != null
                      ? Image.memory(app.icon!)
                      : const Icon(Icons.android, color: Colors.white70),
            ),
            title: Text(
              app.name ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              app.packageName ?? 'Unknown package',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy, color: Colors.white70),
              onPressed: () {
                if (app.packageName != null) {
                  Clipboard.setData(ClipboardData(text: app.packageName!));
                }
              },
            ),
            onTap: () {
              if (app.packageName != null) {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF2D2D2D),
                  builder: (BuildContext context) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.launch,
                              color: Colors.white70,
                            ),
                            title: const Text(
                              'Open App',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              InstalledApps.startApp(app.packageName!);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.settings,
                              color: Colors.white70,
                            ),
                            title: const Text(
                              'Open Settings',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              InstalledApps.openSettings(app.packageName!);
                              Navigator.pop(context);
                            },
                          ),
                          if (isUserApps)
                            ListTile(
                              leading: const Icon(
                                Icons.delete,
                                color: Colors.white70,
                              ),
                              title: const Text(
                                'Uninstall',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () async {
                                await InstalledApps.uninstallApp(
                                  app.packageName!,
                                );
                                Navigator.pop(context);

                                await Future.delayed(
                                  const Duration(seconds: 10),
                                );
                                final isInstalled =
                                    await InstalledApps.isAppInstalled(
                                      app.packageName!,
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
                    );
                  },
                );
              }
            },
          ),
        );
      },
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
