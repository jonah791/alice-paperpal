/// Find-in-Page — MD Preview inspired search bar.
///
/// Floating search bar that searches rendered text in the reading page.
/// Cmd/Ctrl+F to open, Esc to close, Enter to navigate results.
library;

import 'package:flutter/material.dart';
import '../../core/tokens/design_tokens.dart';

/// Result of a find-in-page search.
class FindResult {
  final List<int> matchPositions;
  final int currentIndex;

  const FindResult({
    required this.matchPositions,
    this.currentIndex = 0,
  });

  bool get hasMatches => matchPositions.isNotEmpty;
  int get count => matchPositions.length;
}

/// A floating search bar overlaid on the reading page.
///
/// Features:
/// - Real-time text search as you type
/// - Match count display
/// - Previous/Next navigation
/// - Case-sensitive toggle
class FindBar extends StatefulWidget {
  /// Called when the search query changes. Should return match positions.
  final FindResult Function(String query, {bool caseSensitive}) onSearch;

  /// Called to scroll to a specific match position.
  final void Function(int position) onNavigate;

  /// Called when the find bar is dismissed.
  final VoidCallback? onDismiss;

  const FindBar({
    super.key,
    required this.onSearch,
    required this.onNavigate,
    this.onDismiss,
  });

  @override
  State<FindBar> createState() => FindBarState();
}

class FindBarState extends State<FindBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _caseSensitive = false;
  FindResult _result = const FindResult(matchPositions: []);
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Show the find bar and focus the search input.
  void show() {
    setState(() => _visible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  /// Hide the find bar.
  void hide() {
    setState(() {
      _visible = false;
      _controller.clear();
    });
    widget.onDismiss?.call();
  }

  void _onQueryChanged() {
    if (!_visible) return;
    final query = _controller.text;
    if (query.isEmpty) {
      setState(() => _result = const FindResult(matchPositions: []));
      return;
    }
    setState(() {
      _result = widget.onSearch(query, caseSensitive: _caseSensitive);
    });
  }

  void _navigate(int delta) {
    if (!_result.hasMatches) return;
    final current = _result.currentIndex;
    final next = (current + delta + _result.count) % _result.count;
    widget.onNavigate(_result.matchPositions[next]);
    setState(() {
      _result = FindResult(
        matchPositions: _result.matchPositions,
        currentIndex: next,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: DesignTokens.iconMd,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(fontSize: DesignTokens.fsMd),
              decoration: InputDecoration(
                hintText: '在页面中搜索...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  fontSize: DesignTokens.fsMd,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
              onSubmitted: (_) => _navigate(1),
            ),
          ),
          if (_result.hasMatches)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${_result.currentIndex + 1}/${_result.count}',
                style: TextStyle(
                  fontSize: DesignTokens.fsSm,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          // Case-sensitive toggle
          IconButton(
            icon: Icon(
              Icons.text_fields,
              size: DesignTokens.iconMd,
              color: _caseSensitive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: '区分大小写',
            onPressed: () {
              setState(() => _caseSensitive = !_caseSensitive);
              _onQueryChanged();
            },
            visualDensity: VisualDensity.compact,
          ),
          // Previous
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: DesignTokens.iconMd),
            tooltip: '上一个匹配',
            onPressed: _result.hasMatches ? () => _navigate(-1) : null,
            visualDensity: VisualDensity.compact,
          ),
          // Next
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: DesignTokens.iconMd),
            tooltip: '下一个匹配',
            onPressed: _result.hasMatches ? () => _navigate(1) : null,
            visualDensity: VisualDensity.compact,
          ),
          // Close
          IconButton(
            icon: const Icon(Icons.close, size: DesignTokens.iconMd),
            tooltip: '关闭搜索',
            onPressed: hide,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
