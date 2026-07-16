/// Kori 风格论文卡片 — 从 NoteItem.kt 移植
/// padding 12dp、圆角 12dp、标题 titleMedium Bold、间距 4dp
import 'package:flutter/material.dart';
import '../../core/models/paper.dart';
import '../../core/tokens/design_tokens.dart';

class PaperCard extends StatelessWidget {
  final Paper paper;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PaperCard({
    super.key,
    required this.paper,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onTap,
    this.onLongPress,
  });

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${(diff.inDays / 30).floor()} 个月前';
  }

  Color _statusColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (paper.status) {
      PaperStatus.importing || PaperStatus.downloading => cs.tertiary,
      PaperStatus.parsing => cs.primary,
      PaperStatus.parsed => cs.secondary,
      PaperStatus.translating => cs.primary,
      PaperStatus.translated => Colors.green,
      PaperStatus.error => cs.error,
    };
  }

  String get _statusLabel => switch (paper.status) {
    PaperStatus.importing => '导入中',
    PaperStatus.downloading => '下载中',
    PaperStatus.parsing => '解析中',
    PaperStatus.parsed => '已解析',
    PaperStatus.translating => '翻译中',
    PaperStatus.translated => '已翻译',
    PaperStatus.error => '错误',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColor = _statusColor(context);

    return Card(
      elevation: isSelected ? 0 : 1,
      color: isSelected ? colors.primaryContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: colors.primary.withValues(alpha: 0.4))
            : BorderSide.none,
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12), // Kori: 12dp
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      paper.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (paper.starred)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.star, size: 16, color: Colors.amber),
                    ),
                ],
              ),
              const SizedBox(height: 4), // Kori: 4dp spacing
              // 作者
              if (paper.authors.isNotEmpty)
                Text(
                  paper.authors.join(', '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (paper.authors.isNotEmpty) const SizedBox(height: 4),
              // 底部行 — Kori: labelSmall 字体
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _timeAgo(paper.lastReadAt ?? paper.importedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  if (paper.pageCount > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${paper.pageCount} 页',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
