import 'package:flutter/material.dart';
import '../api/llm_provider.dart';
import '../services/avatar_service.dart';
import '../services/cache_service.dart';
import '../services/config_service.dart';
import '../services/memory_service.dart';
import '../services/network_service.dart';
import '../services/note_service.dart';
import '../services/paper_service.dart';
import '../services/portrait_service.dart';
import '../services/search_service.dart';
import '../services/soul_service.dart';

class Dependencies extends InheritedWidget {
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

  const Dependencies({
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
