import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'core/services/config_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/search_service.dart';
import 'core/services/paper_service.dart';
import 'core/services/network_service.dart';
import 'core/models/config.dart';
import 'core/services/network_service.dart';
import 'core/services/note_service.dart';
import 'core/utils/logger.dart';
import 'ui/pages/search_page.dart';
import 'ui/pages/library_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/welcome_page.dart';
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

  final networkService = NetworkService();
  networkService.init();

  final noteService = NoteService();
  await noteService.init();

  await windowManager.waitUntilReadyToShow();
  await windowManager.setTitle('PaperWise');
  await windowManager.setMinimumSize(const Size(1024, 700));
  await windowManager.setSize(const Size(1280, 860));
  await windowManager.center();
  await windowManager.show();

  // System tray
  await trayManager.setToolTip('PaperWise');
  if (await File('resources/icon.ico').exists()) {
    await trayManager.setIcon('resources/icon.ico', iconSize: 32);
  }
  await trayManager.setContextMenu(Menu(items: [
    MenuItem(key: 'show', label: '显示'),
    MenuItem.separator(),
    MenuItem(key: 'quit', label: '退出'),
  ]));

  final showWelcome = !configService.hasLlmApiKey;
  runApp(PaperWiseApp(
    configService: configService,
    paperService: paperService,
    searchService: searchService,
    cacheService: cacheService,
    networkService: networkService,
    noteService: noteService,
    showWelcome: showWelcome,
  ));
}

class Dependencies extends InheritedWidget {
  final ConfigService configService;
  final PaperService paperService;
  final SearchService searchService;
  final CacheService cacheService;
  final NetworkService networkService;
  final NoteService noteService;

  const Dependencies({
    super.key,
    required this.configService,
    required this.paperService,
    required this.searchService,
    required this.cacheService,
    required this.networkService,
    required this.noteService,
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
  final CacheService cacheService;
  final NetworkService networkService;
  final NoteService noteService;
  final bool showWelcome;

  const PaperWiseApp({
    super.key,
    required this.configService,
    required this.paperService,
    required this.searchService,
    required this.cacheService,
    required this.networkService,
    required this.noteService,
    this.showWelcome = false,
  });

  @override
  State<PaperWiseApp> createState() => _PaperWiseAppState();
}

class _PaperWiseAppState extends State<PaperWiseApp> with TrayListener {
  ThemeMode _themeMode = ThemeMode.system;
  bool _welcomeShown = false;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.configService.config.themeMode.toFlutterThemeMode();
    _welcomeShown = !widget.showWelcome;
    trayManager.addListener(this);
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
      case 'quit':
        windowManager.close();
        break;
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  void _dismissWelcome() {
    setState(() => _welcomeShown = true);
  }

  @override
  Widget build(BuildContext context) {
    return Dependencies(
      configService: widget.configService,
      paperService: widget.paperService,
      searchService: widget.searchService,
      cacheService: widget.cacheService,
      networkService: widget.networkService,
      noteService: widget.noteService,
      child: MaterialApp(
        title: 'PaperWise',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: _welcomeShown
            ? _AppShell(
                onThemeChanged: (mode) => setState(() => _themeMode = mode),
              )
            : WelcomePage(onComplete: _dismissWelcome),
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

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final _pages = <Widget>[
    const SearchPage(),
    const LibraryPage(),
    const SettingsPage(),
  ];

  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      windowManager.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final network = Dependencies.of(context).networkService;
    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => setState(() => _currentIndex = 0),
          const SingleActivator(LogicalKeyboardKey.keyL, control: true): () => setState(() => _currentIndex = 1),
          const SingleActivator(LogicalKeyboardKey.keyP, control: true): () => setState(() => _currentIndex = 2),
          const SingleActivator(LogicalKeyboardKey.keyQ, control: true): () => windowManager.close(),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Row(
            children: [
              Column(
                children: [
                  Expanded(
                    child: NavigationRail(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (i) => setState(() => _currentIndex = i),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(icon: Icon(Icons.search), label: Text('搜索')),
                        NavigationRailDestination(icon: Icon(Icons.library_books), label: Text('论文库')),
                        NavigationRailDestination(icon: Icon(Icons.settings), label: Text('设置')),
                      ],
                    ),
                  ),
                  StreamBuilder<bool>(
                    stream: network.statusStream,
                    initialData: network.isOnline,
                    builder: (context, snapshot) {
                      final online = snapshot.data ?? true;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Icon(
                          online ? Icons.cloud_done : Icons.cloud_off,
                          size: 14,
                          color: online ? Colors.green : Colors.red,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _pages[_currentIndex]),
            ],
          ),
        ),
      ),
    );
  }
}
