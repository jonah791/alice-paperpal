// Shared application initializer — used by both Flutter (main.dart)
// and CLI (tool/paperpal.dart) to create services consistently.
//
// Adding a new service? Register it in [createLocator] in one place.
// Both apps automatically pick it up.

import 'dart:io' show File;

import 'api/llm_provider.dart';
import 'api/markitdown_bridge.dart';
import 'api/mineru_api.dart';
import 'interfaces/services.dart';
import 'di/service_locator.dart';
import 'services/cache_service.dart';
import 'services/config_service.dart';
import 'services/doc_conversion_service.dart';
import 'services/memory_service.dart';
import 'services/network_service.dart';
import 'services/note_service.dart';
import 'services/paper_service.dart';
import 'services/portrait_service.dart';
import 'services/search_service.dart';
import 'services/soul_service.dart';
import 'services/avatar_service.dart';
import 'services/template_service.dart';
import 'services/mermaid_renderer.dart';
import 'services/zotero_service.dart';
import 'services/platform_service.dart';
import 'utils/logger.dart';

/// Creates and wires all application services.
Future<ServiceLocator> createLocator({PlatformService? platform}) async {
  final locator = ServiceLocator();
  final platformService = platform ?? createPlatformService();

  await initLogger();
  final configService = ConfigService(platformService);
  await configService.load();
  locator.registerInstance<IConfigService>(configService);

  final cacheService = CacheService();
  await cacheService.init();
  locator.registerInstance<ICacheService>(cacheService);

  final apiKey = await configService.readLlmApiKey();
  final llmProvider = LLMProvider(config: LLMConfig(
    type: LLMProviderType.deepseek,
    apiKey: apiKey ?? '',
    apiBase: configService.config.llmApiBase,
    model: configService.config.llmModel,
  ));
  locator.registerInstance<ILLMProvider>(llmProvider);

  final soulService = SoulService();
  await soulService.init();
  locator.registerInstance<ISoulService>(soulService);

  final memoryService = MemoryService();
  await memoryService.init();
  locator.registerInstance<IMemoryService>(memoryService);

  final portraitService = PortraitService();
  await portraitService.init();
  locator.registerInstance<IPortraitService>(portraitService);

  final avatarService = AvatarService();
  await avatarService.init();
  locator.registerInstance<IAvatarService>(avatarService);

  locator.registerInstance<ISearchService>(SearchService());

  final networkService = NetworkService();
  networkService.init();
  locator.registerInstance<INetworkService>(networkService);

  final noteService = NoteService();
  await noteService.init();
  locator.registerInstance<INoteService>(noteService);

  // ── MinerU API (used by PaperService for parsing) ──────────
  final mineruApiKey = await configService.readMineruApiKey();
  final mineruApi = MineruApi(
    apiKey: mineruApiKey ?? '',
    modelVersion: configService.config.mineruModelVersion,
    enableFormula: configService.config.enableFormula,
    enableTable: configService.config.enableTable,
  );
  locator.registerInstance<IMineruApi>(mineruApi);

  final paperService = PaperService(
    cache: cacheService,
    search: locator.get<ISearchService>(),
    config: configService,
    llmProvider: llmProvider,
    mineruApi: mineruApi,
    noteService: noteService,
    soulService: soulService,
    memoryService: memoryService,
    portraitService: portraitService,
  );
  await paperService.init();
  locator.registerInstance<IPaperService>(paperService);

  // ── Unified Document Conversion (MarkItDown) ──────────────────
  final bridgeScript = _findBridgeScript();
  final bridge = MarkitdownBridge(bridgeScript);
  final docConversion = DocConversionService(bridge);
  locator.registerInstance<IDocConversionService>(docConversion);

  // ── Note Templates (Kori) ────────────────────────────────────
  final templateService = TemplateService();
  await templateService.init();
  locator.registerInstance<ITemplateService>(templateService);

  // ── Mermaid Renderer (MD Preview) ────────────────────────────
  final mermaidRenderer = MermaidRenderer();
  locator.registerInstance<IMermaidRenderer>(mermaidRenderer);

  // ── Zotero Integration ───────────────────────────────────────
  final zoteroService = ZoteroService();
  locator.registerInstance<IZoteroService>(zoteroService);

  return locator;
}

/// Locate the MarkItDown Python bridge script.
String _findBridgeScript() {
  final candidates = [
    'tool/markitdown_bridge.py',
    '../tool/markitdown_bridge.py',
    'packages/paperpal/tool/markitdown_bridge.py',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  return 'tool/markitdown_bridge.py';
}
