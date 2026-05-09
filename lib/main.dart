import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'core/services/config_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/search_service.dart';
import 'core/services/paper_service.dart';
import 'core/models/config.dart';
import 'core/utils/logger.dart';
import 'ui/pages/search_page.dart';
import 'ui/pages/library_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await initLogger();
  final configService = ConfigService();
  await configService.load();

  final cacheService = CacheService();
  await cacheService.init();

  final searchService = SearchService();
  final paperService = PaperService(
    cache: cacheService,
    search: searchService,
    config: configService,
  );
  await paperService.init();

  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitle('PaperWise');
    await windowManager.setMinimumSize(const Size(1024, 700));
    await windowManager.setSize(const Size(1280, 860));
    await windowManager.center();
    await windowManager.show();
  });

  runApp(PaperWiseApp(
    configService: configService,
    paperService: paperService,
    searchService: searchService,
  ));
}

class Dependencies extends InheritedWidget {
  final ConfigService configService;
  final PaperService paperService;
  final SearchService searchService;

  const Dependencies({
    super.key,
    required this.configService,
    required this.paperService,
    required this.searchService,
    required super.child,
  });

  static Dependencies of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<Dependencies>();
    assert(result != null, 'No Dependencies found');
    return result!;
  }

  @override
  bool updateShouldNotify(Dependencies oldWidget) => false;
}

class PaperWiseApp extends StatefulWidget {
  final ConfigService configService;
  final PaperService paperService;
  final SearchService searchService;

  const PaperWiseApp({
    super.key,
    required this.configService,
    required this.paperService,
    required this.searchService,
  });

  @override
  State<PaperWiseApp> createState() => _PaperWiseAppState();
}

class _PaperWiseAppState extends State<PaperWiseApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.configService.config.themeMode.toFlutterThemeMode();
  }

  @override
  Widget build(BuildContext context) {
    return Dependencies(
      configService: widget.configService,
      paperService: widget.paperService,
      searchService: widget.searchService,
      child: MaterialApp(
        title: 'PaperWise',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: _AppShell(
          onThemeChanged: (mode) {
            setState(() => _themeMode = mode);
          },
        ),
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  final void Function(ThemeMode) onThemeChanged;
  const _AppShell({required this.onThemeChanged});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _currentIndex = 0;

  final _pages = <Widget>[
    const SearchPage(),
    const LibraryPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.search),
                label: Text('搜索'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_books),
                label: Text('论文库'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _pages[_currentIndex]),
        ],
      ),
    );
  }
}
