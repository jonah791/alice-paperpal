import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'core/init.dart';
import 'core/di/service_locator.dart';
import 'core/di/dependencies.dart';
import 'core/interfaces/services.dart';

import 'ui/pages/search_page.dart';
import 'ui/pages/library_page.dart';
import 'ui/pages/read_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/template_page.dart';
import 'ui/pages/welcome_page.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/themes/theme_variant.dart';
import 'ui/widgets/avatar_helpers.dart';
import 'ui/widgets/app_sidebar.dart';

final _log = Logger('PaperPalApp');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final locator = await createLocator();
  final platform = locator.get<IConfigService>().platform;

  if (!platform.isAndroid) {
    await windowManager.ensureInitialized();
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
      MenuItem(key: 'show', label: '显示窗口'),
      MenuItem.separator(),
      MenuItem(key: 'search', label: '快速搜索...'),
      MenuItem(key: 'import', label: '导入 arXiv 链接...'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出'),
    ]));
  }

  final configService = locator.get<IConfigService>();
  final showWelcome = !configService.hasLlmApiKey;

  String? pdfFileArg;
  String? deepLinkUrl;
  if (!platform.isAndroid) {
    try {
      final pdfPath = Platform.environment['PAPERPAL_PDF_PATH'];
      if (pdfPath != null && pdfPath.isNotEmpty && File(pdfPath).existsSync()) {
        pdfFileArg = pdfPath;
      }
      deepLinkUrl = Platform.environment['PAPERPAL_DEEP_LINK'];
    } catch (_) {}
  }

  runApp(PaperPalApp(
    locator: locator,
    showWelcome: showWelcome,
    initialPdfPath: pdfFileArg,
    deepLinkUrl: deepLinkUrl,
  ));
}

class PaperPalApp extends StatefulWidget {
  final ServiceLocator locator;
  final bool showWelcome;
  final String? initialPdfPath;
  final String? deepLinkUrl;

  const PaperPalApp({
    super.key,
    required this.locator,
    this.showWelcome = false,
    this.initialPdfPath,
    this.deepLinkUrl,
  });

  @override
  State<PaperPalApp> createState() => _PaperPalAppState();
}

class _PaperPalAppState extends State<PaperPalApp> with TrayListener {
  ThemeMode _themeMode = ThemeMode.system;
  late ThemeVariant _themeVariant;
  bool _amoled = false;
  bool _welcomeShown = false;

  @override
  void initState() {
    super.initState();
    final configService = widget.locator.get<IConfigService>();
    _themeMode = configService.config.themeMode.toFlutterThemeMode();
    _themeVariant = ThemeVariant.values.firstWhere(
      (t) => t.name == configService.config.themeVariant,
      orElse: () => ThemeVariant.alice,
    );
    _amoled = configService.config.amoledMode;
    _welcomeShown = !widget.showWelcome;
    if (!configService.platform.isAndroid) {
      trayManager.addListener(this);
    }

    if (widget.initialPdfPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _importFromArg(widget.initialPdfPath!);
      });
    } else if (widget.deepLinkUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleDeepLink(widget.deepLinkUrl!);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _startupGreeting());
  }

  Future<void> _handleDeepLink(String url) async {
    final arxivMatch = RegExp(r'arxiv/(\d+\.\d+)').firstMatch(url);
    if (arxivMatch == null) return;
    final arxivId = arxivMatch.group(1)!;
    final ps = widget.locator.get<IPaperService>();
    final (results, _) = await ps.search(arxivId);
    if (results.isEmpty) return;
    final result = results.first;
    final paper = await ps.importFromSearch(result);
    if (paper == null) return;
    _log.info('deep link: imported arXiv $arxivId');
    paperToView.value = paper.id;
  }

  Future<void> _importFromArg(String path) async {
    final file = File(path);
    if (!await file.exists()) return;
    await widget.locator.get<IPaperService>().importPdf(file);
    _welcomeShown = true;
    if (mounted) setState(() {});
  }

  Future<void> _startupGreeting() async {
    await Future.delayed(const Duration(milliseconds: 800));
    final memoryService = widget.locator.get<IMemoryService>();
    final llmProvider = widget.locator.get<ILLMProvider>();
    final soulService = widget.locator.get<ISoulService>();
    final avatarService = widget.locator.get<IAvatarService>();

    final memories = memoryService.getRecent(limit: 1);
    if (memories.isEmpty) return;
    final soul = soulService.getActiveOrDefault();
    final greeting = await llmProvider.chat([
      {'role': 'system', 'content': '根据最近记忆和时间生成一句自然的问候。简短亲切，不要说"早上好/下午好"。'},
      {'role': 'user', 'content': '最近记忆：${memories.first.summary}'},
    ], maxTokens: 100);
    if (greeting.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              buildDefaultAvatar(soul.name, 20, avatarService.colorForName(soul.name)),
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
    final configService = widget.locator.get<IConfigService>();
    if (!configService.platform.isAndroid) {
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show': windowManager.show(); windowManager.focus();
      case 'search': windowManager.show(); windowManager.focus(); searchPageAction.value = SearchPageAction.search;
      case 'import': windowManager.show(); windowManager.focus(); searchPageAction.value = SearchPageAction.importUrl;
      case 'quit': windowManager.close(); break;
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  void _dismissWelcome() => setState(() => _welcomeShown = true);

  @override
  Widget build(BuildContext context) {
    return Dependencies(
      locator: widget.locator,
      child: MaterialApp(
        title: 'PaperPal',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: AppTheme.fromVariant(_themeVariant, Brightness.light, amoled: _amoled),
        darkTheme: AppTheme.fromVariant(_themeVariant, Brightness.dark, amoled: _amoled),
        home: _welcomeShown
            ? _AppShell(
                locator: widget.locator,
                onThemeChanged: (mode) => setState(() => _themeMode = mode),
                onVariantChanged: (v) {
                  setState(() => _themeVariant = v);
                  widget.locator.get<IConfigService>().updateConfig(
                    widget.locator.get<IConfigService>().config.copyWith(themeVariant: v.name));
                },
              )
            : WelcomePage(onComplete: _dismissWelcome),
      ),
    );
  }
}

/// Kori 风格应用外壳 — 自适应侧边栏 + 内容区
class _AppShell extends StatefulWidget {
  final ServiceLocator locator;
  final void Function(ThemeMode) onThemeChanged;
  final void Function(ThemeVariant) onVariantChanged;

  const _AppShell({
    required this.locator,
    required this.onThemeChanged,
    required this.onVariantChanged,
  });

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  NavItem _selectedNav = NavItem.search;

  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    searchPageAction.addListener(_onSearchPageAction);
    paperToView.addListener(_onPaperToView);
  }

  void _onSearchPageAction() {
    final action = searchPageAction.value;
    if (action != null) setState(() => _selectedNav = NavItem.search);
  }

  void _onPaperToView() {
    final paperId = paperToView.value;
    if (paperId == null) return;
    paperToView.value = null;
    final ps = widget.locator.get<IPaperService>();
    final paper = ps.getPaper(paperId);
    if (paper == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReadPage(paper: paper)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    searchPageAction.removeListener(_onSearchPageAction);
    paperToView.removeListener(_onPaperToView);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!widget.locator.get<IConfigService>().platform.isAndroid) {
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
    final isMobile = _isMobile;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ps = widget.locator.get<IPaperService>();

    final sidebar = AppSidebar(
      selectedItem: _selectedNav,
      paperCount: ps.papers.length,
      starredCount: ps.papers.where((p) => p.starred).length,
      onItemSelected: (item) => setState(() => _selectedNav = item),
      onThemeToggle: () {
        final next = isDark ? ThemeMode.light : ThemeMode.dark;
        widget.onThemeChanged(next);
      },
      isDark: isDark,
    );

    Widget pageContent;
    switch (_selectedNav) {
      case NavItem.search:
        pageContent = const SearchPage();
      case NavItem.library:
        pageContent = const LibraryPage();
      case NavItem.templates:
        pageContent = const TemplatePage();
      case NavItem.settings:
        pageContent = const SettingsPage();
    }

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(title: Text(_selectedNav.label)),
        drawer: Drawer(child: SafeArea(child: sidebar)),
        body: pageContent,
      );
    }

    // Desktop: Kori 风格 permanent drawer
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => setState(() => _selectedNav = NavItem.search),
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () => setState(() => _selectedNav = NavItem.library),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () => setState(() => _selectedNav = NavItem.settings),
        if (!widget.locator.get<IConfigService>().platform.isAndroid)
          const SingleActivator(LogicalKeyboardKey.keyQ, control: true): () => windowManager.close(),
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Row(
          children: [
            SizedBox(
              width: 280,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: SafeArea(child: sidebar),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pageContent),
          ],
        ),
      ),
    );
  }
}
