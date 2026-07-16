/// Zotero service — wraps ZoteroApi behind an interface.
library;

import 'dart:io';
import '../api/zotero_api.dart';
import '../interfaces/services.dart';
import '../models/search_result.dart';

class ZoteroService implements IZoteroService {
  ZoteroApi? _api;

  @override
  bool get isConfigured {
    _lazyInit();
    return _api != null;
  }

  void _lazyInit() {
    if (_api != null) return;
    try {
      final key = Platform.environment['ZOTERO_API_KEY'] ?? '';
      final uid = Platform.environment['ZOTERO_USER_ID'] ?? '';
      if (key.isEmpty || uid.isEmpty) return;
      _api = ZoteroApi(apiKey: key, userId: uid);
    } catch (_) {}
  }

  @override
  Future<List<SearchResult>> importFromZotero({int limit = 50}) async {
    _lazyInit();
    if (_api == null) return [];
    return _api!.listItems(limit: limit);
  }
}
