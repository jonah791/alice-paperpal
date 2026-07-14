import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import '../../core/models/search_result.dart';
import '../../core/models/paper.dart';
import '../../core/di/dependencies.dart';
import '../../core/tokens/design_tokens.dart';
import '../widgets/card_spinner.dart';
import 'read_page.dart';

final _log = Logger('SearchPage');

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _queryController = TextEditingController();
  final _urlController = TextEditingController();
  List<SearchResult> _results = [];
  bool _loading = false;
  bool _showUrlInput = false;
  String _statusMessage = '';
  final _importedIds = <String>{};

  @override
  void dispose() {
    _queryController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool _isImported(SearchResult r) {
    final papers = context.paperService.papers;
    return papers.any((p) => p.title == r.title);
  }

  Paper? _importedPaper(SearchResult r) {
    try {
      return context.paperService.papers.firstWhere((p) => p.title == r.title);
    } catch (_) {
      return null;
    }
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _statusMessage = '';
      _results = [];
    });

    try {

      if (!context.networkService.isOnline) {
        if (mounted) setState(() {
          _loading = false;
          _statusMessage = '网络不可用，请检查网络连接后重试';
        });
        return;
      }

      final (results, error) = await context.searchService.search(query);
      if (!mounted) return;

      if (error != null) {
        setState(() {
          _loading = false;
          _statusMessage = error;
        });
        return;
      }

      setState(() {
        _loading = false;
        _results = results;
        if (results.isEmpty) {
          _statusMessage = '未找到相关论文，试试其他关键词';
        }
      });
    } catch (e) {
      if (!mounted) return;
      _log.warning('search failed: $e');
      setState(() {
        _loading = false;
        _statusMessage = '搜索出错: $e';
      });
    }
  }

  Future<void> _importUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _loading = true;
      _statusMessage = '正在导入...';
    });

    String? pdfUrl = url;
    String? title;

    final arxivMatch = RegExp(r'arxiv\.org/abs/(\d+\.\d+)').firstMatch(url);
    if (arxivMatch != null) {
      pdfUrl = 'https://arxiv.org/pdf/${arxivMatch.group(1)}.pdf';
      title = 'arXiv ${arxivMatch.group(1)}';
      _log.info('importUrl: arXiv $pdfUrl');
    }

    try {

      final tempDir = await Directory.systemTemp.createTemp('paperwise_');
      final result = SearchResult(
        title: title ?? url,
        authors: [],
        pdfUrl: pdfUrl,
        source: 'url',
      );
      final file = await context.searchService.downloadPdf(result, tempDir.path,
        onProgress: (received, total) {
          if (total > 0) {
            final pct = (received / total * 100).toInt();
            _statusMessage = '下载中... $pct%';
            if (mounted) setState(() {});
          }
        },
      );
      if (file == null) {
        setState(() {
          _statusMessage = '下载失败';
          _loading = false;
        });
        return;
      }

      final paper = await context.paperService.importPdf(file, title: title);
      if (paper == null) {
        setState(() {
          _statusMessage = '导入失败：文件读取错误';
          _loading = false;
        });
      } else if (paper.status == PaperStatus.error) {
        setState(() {
          _statusMessage = '解析失败，请检查 MinerU API Key 是否已配置';
          _loading = false;
        });
      } else {
        setState(() {
          _statusMessage = '导入成功: ${paper.title}';
          _loading = false;
          _urlController.clear();
          _showUrlInput = false;
        });
      }
    } catch (e) {
      _log.warning('importUrl failed: $e');
      setState(() {
        _statusMessage = '导入失败: 无法下载或解析';
        _loading = false;
      });
    }
  }

  Future<void> _uploadPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (!mounted || result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      setState(() => _statusMessage = '正在导入...');
      _log.info('uploadPdf: ${file.name}');


      final paper = await context.paperService.importPdf(
        File(file.path!),
        title: file.name.replaceAll('.pdf', ''),
      );

      if (!mounted) return;

      if (paper == null) {
        setState(() => _statusMessage = '导入失败：请先在设置页配置 MinerU API Key');
      } else if (paper.status == PaperStatus.error) {
        setState(() => _statusMessage = '解析失败，请检查 MinerU API Key 是否已配置');
      } else {
        _log.info('uploadPdf: imported ${paper.id}');
        setState(() => _statusMessage = '导入成功: ${paper.title}');
      }
    } catch (e) {
      if (!mounted) return;
      _log.warning('uploadPdf failed: $e');
      setState(() => _statusMessage = '导入失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildSearchBar(theme),
        Expanded(child: _buildBody(theme)),
        if (_statusMessage.isNotEmpty)
          Padding(
            padding: padAll(DesignTokens.spGap),
            child: Text(_statusMessage, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: padOnly(l: Spacing.lg, t: Spacing.lg, r: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search input + primary action row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 520;
              final searchField = TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: '搜索论文标题或关键词...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: padSym(h: DesignTokens.sp4, v: DesignTokens.sp3),
                ),
                onSubmitted: (_) => _search(),
              );
              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: searchField),
                    SizedBox(width: Spacing.gap),
                    _searchButton(),
                    SizedBox(width: Spacing.gap),
                    _uploadButton(),
                    SizedBox(width: Spacing.gap),
                    _linkButton(),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  SizedBox(height: Spacing.gap),
                  Row(
                    children: [
                      Expanded(child: _searchButton()),
                      SizedBox(width: Spacing.gap),
                      _uploadButton(),
                      SizedBox(width: Spacing.gap),
                      _linkButton(),
                    ],
                  ),
                ],
              );
            },
          ),
          // URL import toggle
          if (_showUrlInput) ...[
            SizedBox(height: Spacing.gap),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: '粘贴 arXiv 链接或 PDF 直链...',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                    onSubmitted: (_) => _importUrl(),
                  ),
                ),
                SizedBox(width: Spacing.gap),
                FilledButton.tonalIcon(
                  onPressed: _importUrl,
                  icon: const Icon(Icons.download, size: DesignTokens.iconMd),
                  label: const Text('导入'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static final _fadeTween = Tween<double>(begin: 0.0, end: 1.0);

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CardSpinner());
    }

    if (_results.isEmpty) {
      return Center(
        child: TweenAnimationBuilder<double>(
          tween: _fadeTween,
          duration: const Duration(milliseconds: 500),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, DesignTokens.sp10 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: DesignTokens.sp12, color: theme.colorScheme.onSurfaceVariant),
              SizedBox(height: Spacing.lg),
              Text('输入关键词开始搜索论文', style: theme.textTheme.bodyLarge),
              SizedBox(height: Spacing.gap),
              Text('或点击"上传 PDF"导入本地论文', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: padSym(h: Spacing.lg),
      itemCount: _results.length,
      itemBuilder: (context, index) => TweenAnimationBuilder<double>(
        tween: _fadeTween,
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, DesignTokens.sp10 * (1 - value)),
              child: child,
            ),
          );
        },
        child: _buildResultCard(_results[index], theme),
      ),
    );
  }

  Widget _buildResultCard(SearchResult result, ThemeData theme) {
    final imported = _isImported(result);
    final existing = _importedPaper(result);

    return Card(
      margin: padOnly(b: DesignTokens.spGap),
      color: imported ? theme.colorScheme.secondaryContainer?.withValues(alpha: 0.15) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        onTap: () async {
          if (imported && existing != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ReadPage(paper: existing)));
            return;
          }
          try {
            if (result.pdfUrl.isEmpty) {
              setState(() => _statusMessage = '该论文无开放获取 PDF 链接');
              return;
            }
            setState(() => _statusMessage = '正在下载: ${result.title}');
      
            final paper = await context.paperService.importFromSearch(result,
              onProgress: (received, total) {
                if (total > 0 && mounted) {
                  setState(() => _statusMessage = '下载中... ${(received / total * 100).toInt()}%');
                }
              },
            );
            if (paper == null) {
              setState(() => _statusMessage = '下载失败，请检查网络或重试');
            } else if (paper.status == PaperStatus.error) {
              setState(() => _statusMessage = '解析失败，请检查 MinerU API Key 是否已配置');
            } else {
              _log.info('importFromSearch: ${paper.id}');
              setState(() => _statusMessage = '导入成功: ${paper.title}');
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('操作失败: $e')),
              );
            }
          }
        },
        child: Padding(
          padding: padAll(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(result.title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  if (imported)
                    Padding(
                      padding: padOnly(l: Spacing.sm),
                      child: Chip(
                        label: const Text('已导入', style: TextStyle(fontSize: 9)),
                        backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.15),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              SizedBox(height: DesignTokens.sp1),
              Text(
                result.authors.join(', '),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: DesignTokens.sp1),
              Row(
                children: [
                  Chip(label: Text(result.year.toString(), style: const TextStyle(fontSize: DesignTokens.fsXs))),
                  SizedBox(width: Spacing.gap),
                  Chip(label: Text(result.source, style: const TextStyle(fontSize: DesignTokens.fsXs))),
                  if (result.citationCount > 0) ...[
                    SizedBox(width: Spacing.gap),
                    Text('☆ ${result.citationCount}', style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
              if (result.abstract.isNotEmpty) ...[
                SizedBox(height: Spacing.gap),
                Text(result.abstract,
                    style: theme.textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchButton() {
    return FilledButton.icon(
      onPressed: _loading ? null : _search,
      icon: _loading
          ? SizedBox(width: DesignTokens.iconMd, height: DesignTokens.iconMd,
              child: const CircularProgressIndicator(strokeWidth: DesignTokens.borderXl))
          : const Icon(Icons.search),
      label: const Text('搜索'),
    );
  }

  Widget _uploadButton() {
    return OutlinedButton.icon(
      onPressed: _uploadPdf,
      icon: const Icon(Icons.upload_file),
      label: const Text('上传 PDF'),
    );
  }

  Widget _linkButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _showUrlInput = !_showUrlInput),
      icon: Icon(_showUrlInput ? Icons.expand_less : Icons.link),
      label: const Text('贴链接'),
    );
  }
}
