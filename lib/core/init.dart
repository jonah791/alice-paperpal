/// Shared application initializer — used by both Flutter (main.dart)
/// and CLI (tool/paperpal.dart) to create services consistently.
///
/// Adding a new service? Register it in [createLocator] in one place.
/// Both apps automatically pick it up.

import 'api/llm_provider.dart';
import 'interfaces/services.dart';
import 'di/service_locator.dart';
import 'services/cache_service.dart';
import 'services/config_service.dart';
import 'services/memory_service.dart';
import 'services/network_service.dart';
import 'services/note_service.dart';
import 'services/paper_service.dart';
import 'services/portrait_service.dart';
import 'services/search_service.dart';
import 'services/soul_service.dart';
import 'services/avatar_service.dart';
import 'services/platform_service.dart';
import 'utils/logger.dart';

/// Creates and wires all application services.
/// Call once at startup, then pass [locator] to [Dependencies] (Flutter)
/// or use [locator.get] directly (CLI/server).
/// Pass [platform] to override the platform service (e.g. for headless server).
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

  final paperService = PaperService(
    cache: cacheService,
    search: locator.get<ISearchService>(),
    config: configService,
    llmProvider: llmProvider,
    noteService: noteService,
    soulService: soulService,
    memoryService: memoryService,
    portraitService: portraitService,
  );
  await paperService.init();
  locator.registerInstance<IPaperService>(paperService);

  return locator;
}
