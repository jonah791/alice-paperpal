import 'package:flutter/material.dart';
import '../interfaces/services.dart';
import 'service_locator.dart';

/// InheritedWidget that exposes registered services to the widget tree.
///
/// Retrieve any service with:
///   final paperService = context.service();
class Dependencies extends InheritedWidget {
  final ServiceLocator locator;

  const Dependencies({
    super.key,
    required this.locator,
    required super.child,
  });

  static ServiceLocator of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<Dependencies>();
    assert(result != null, 'No Dependencies found');
    return result!.locator;
  }

  @override
  bool updateShouldNotify(Dependencies oldWidget) => false;
}

/// Convenience extensions on BuildContext for service resolution.
extension ServiceX on BuildContext {
  IConfigService get configService => Dependencies.of(this).get<IConfigService>();
  IPaperService get paperService => Dependencies.of(this).get<IPaperService>();
  ISearchService get searchService => Dependencies.of(this).get<ISearchService>();
  ICacheService get cacheService => Dependencies.of(this).get<ICacheService>();
  INetworkService get networkService => Dependencies.of(this).get<INetworkService>();
  INoteService get noteService => Dependencies.of(this).get<INoteService>();
  ISoulService get soulService => Dependencies.of(this).get<ISoulService>();
  IMemoryService get memoryService => Dependencies.of(this).get<IMemoryService>();
  IPortraitService get portraitService => Dependencies.of(this).get<IPortraitService>();
  IAvatarService get avatarService => Dependencies.of(this).get<IAvatarService>();
  ILLMProvider get llmProvider => Dependencies.of(this).get<ILLMProvider>();
  IDocConversionService get docConversion => Dependencies.of(this).get<IDocConversionService>();
  ITemplateService get templateService => Dependencies.of(this).get<ITemplateService>();
  IZoteroService get zoteroService => Dependencies.of(this).get<IZoteroService>();
  IMermaidRenderer get mermaidRenderer => Dependencies.of(this).get<IMermaidRenderer>();
}
