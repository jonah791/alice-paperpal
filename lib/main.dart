import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'core/services/platform_service.dart';
import 'core/services/config_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/search_service.dart';
import 'core/services/paper_service.dart';
import 'core/services/network_service.dart';
import 'core/services/note_service.dart';
import 'core/services/soul_service.dart';
import 'core/services/memory_service.dart';
import 'core/services/portrait_service.dart';
import 'core/services/avatar_service.dart';
import 'core/di/dependencies.dart';
import 'core/api/llm_provider.dart';
import 'core/utils/logger.dart';
import 'ui/pages/search_page.dart';
import 'ui/pages/library_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/welcome_page.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/avatar_helpers.dart';
import 'ui/widgets/animated_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final platform = createPlatformService();

  if (!platform.isAndroid) {
    await windowManager.ensureInitialized();
  }

  await initLogger();
  final configService = ConfigService(platform);
  await configService.load();

  final cacheService = CacheService();
  await cacheService.init();

  final apiKey = await configService.readLlmApiKey();
  final llmProvider = LLMProvider(config: LLMConfig(
    type: LLMProviderType.deepseek,
    apiKey: apiKey ?? '',
    apiBase: configService.config.llmApiBase,
    model: configService.config.llmModel,
  ));

  final soulService = SoulService();
  await soulService.init();

  final memoryService = MemoryService();
  await memoryService.init();

  final portraitService = PortraitService();
  await portraitService.init();

  final avatarService = AvatarService();
  await avatarService.init();

  final searchService = SearchService();
  final paperService = PaperService(
    cache: cacheService,
    search: searchService,
    config: configService,
    llmProvider: llmProvider,
    soulService: soulService,
    memoryService: memoryService,
    portraitService: portraitService,
  );
  await paperService.init();

  final networkService = NetworkService();
  networkService.init();

  final noteService = NoteService();
  await noteService.init();
    await windowManager.waitUntilReadyToShow();
    await windowManager.setTitle('PaperPal');
    await windowManager.setMinimumSize(const Size(1024, 700));
    await windowManager.setSize(const Size(1280, 860));
    await windowManager.center();
    await windowManager.show();

    await trayManager.setToolTip('PaperPal');
    if (await File('resources/icon.ico').exists()) {
      await trayManager.setIcon('resources/icon.ico', iconSize: 32);
    }
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: '显示'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出'),
    ]));
  }

  final showWelcome = !configService.hasLlmApiKey;

  String? pdfFileArg;
  if (!platform.isAndroid) {
    try {
      final pdfPath = Platform.environment['PAPERPAL_PDF_PATH'];
      if (pdfPath != null && pdfPath.isNotEmpty && File(pdfPath).existsSync()) {
        pdfFileArg = pdfPath;
      }
    } catch (_) {}
  }

  runApp(PaperPalApp(
    configService: configService,
    paperService: paperService,
    searchService: searchService,
    cacheService: cacheService,
    networkService: networkService,
    noteService: noteService,
    soulService: soulService,
    memoryService: memoryService,
    portraitService: portraitService,
    avatarService: avatarService,
    llmProvider: llmProvider,
    showWelcome: showWelcome,
    initialPdfPath: pdfFileArg,
  ));
}

class PaperPalApp extends StatefulWidget {
  final ConfigService configService;
  final PaperService paperService;
  final SearchService searchService;
  final CacheService cacheService;
  final NetworkService networkService;
  final NoteService noteService;
  final SoulService soulService;
  final MemoryService memoryService;
  final PortraitService portraitService;
  final AvatarService avatarService;
  final LLMProvider llmProvider;
  final bool showWelcome;
  final String? initialPdfPath;

  const PaperPalApp({
    super.key,
    required this.configService,
    required this.paperService,
    required this.searchService,
    required this.cacheService,
    required this.networkService,
    required this.noteService,
    required this.soulService,
    required this.memoryService,
    required this.portraitService,
    required this.avatarService,
    required this.llmProvider,
    this.showWelcome = false,
    this.initialPdfPath,
  });

  @override
  State<PaperPalApp> createState() => _PaperPalAppState();
}

class _PaperPalAppState extends State<PaperPalApp> with TrayListener {
  ThemeMode _themeMode = ThemeMode.system;
  bool _welcomeShown = false;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.configService.config.themeMode.toFlutterThemeMode();
    _welcomeShown = !widget.showWelcome;
    if (!widget.configService.platform.isAndroid) {
      trayManager.addListener(this);
    }

    if (widget.initialPdfPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _importFromArg(widget.initialPdfPath!);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _startupGreeting());
  }

  Future<void> _importFromArg(String path) async {
    final file = File(path);
    if (!await file.exists()) return;
    await widget.paperService.importPdf(file);
    _welcomeShown = true;
    if (mounted) setState(() {});
  }

  Future<void> _startupGreeting() async {
    await Future.delayed(const Duration(milliseconds: 800));
    final memories = widget.memoryService.getRecent(limit: 1);
    if (memories.isEmpty) return;
    final soul = widget.soulService.getActiveOrDefault();
    final greeting = await widget.llmProvider.chat([
      {'role': 'system', 'content': '根据最近记忆和时间生成一句自然的问候。简短亲切，不要说"早上好/下午好"。'},
      {'role': 'user', 'content': '最近记忆：${memories.first.summary}'},
    ], maxTokens: 80);
    if (greeting.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              buildDefaultAvatar(soul.name, 20, widget.avatarService.colorForName(soul.name)),
              const SizedBox(width: 8),
              Expanded(child: Text(greeting, style: const TextStyle(fontSize: 13))),
            ],
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (!widget.configService.platform.isAndroid) {
      trayManager.removeListener(this);
    }
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
      soulService: widget.soulService,
      memoryService: widget.memoryService,
      portraitService: widget.portraitService,
      avatarService: widget.avatarService,
      llmProvider: widget.llmProvider,
      child: MaterialApp(
        title: 'PaperPal',
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
      final platform = Dependencies.of(context).configService.platform;
      if (!platform.isAndroid) {
        windowManager.show();
      }
    }
  }

  bool get _isMobile =>
      WidgetsBinding.instance.platformDispatcher.views.any(
        (v) => v.physicalSize.shortestSide < 600 * v.devicePixelRatio,
      );

  @override
  Widget build(BuildContext context) {
    final network = Dependencies.of(context).networkService;
    final platform = Dependencies.of(context).configService.platform;
    final isMobile = _isMobile;

    if (isMobile) {
      return Scaffold(
        body: AnimatedBackground(
          child: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
            NavigationDestination(icon: Icon(Icons.library_books), label: '论文库'),
            NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
          ],
        ),
      );
    }

    return Scaffold(
      body: AnimatedBackground(
        child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => setState(() => _currentIndex = 0),
          const SingleActivator(LogicalKeyboardKey.keyL, control: true): () => setState(() => _currentIndex = 1),
          const SingleActivator(LogicalKeyboardKey.keyP, control: true): () => setState(() => _currentIndex = 2),
          if (!platform.isAndroid)
            const SingleActivator(LogicalKeyboardKey.keyQ, control: true): () => windowManager.close(),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: !isMobile,
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
      ),
    );
  }
}
