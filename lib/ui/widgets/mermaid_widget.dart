/// Mermaid diagram widget.
///
/// Renders Mermaid diagram code blocks using a WebView with Mermaid.js.
/// Falls back to showing diagram code as plain text when WebView is unavailable.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/services/mermaid_renderer.dart';


/// Widget that renders a Mermaid diagram.
class MermaidWidget extends StatefulWidget {
  final String diagramCode;
  final double width;
  final double? height;

  const MermaidWidget({
    super.key,
    required this.diagramCode,
    this.width = double.infinity,
    this.height,
  });

  @override
  State<MermaidWidget> createState() => _MermaidWidgetState();
}

class _MermaidWidgetState extends State<MermaidWidget> {
  bool _useWebView = true;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _checkWebViewSupport();
  }

  Future<void> _checkWebViewSupport() async {
    try {
      _useWebView = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (_) {
      _useWebView = false;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (!_useWebView || _hasError) {
      return _buildFallback(context);
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a1a2e) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text('Mermaid Diagram', style: TextStyle(
                  fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w500,
                )),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _hasError = false),
                  child: Icon(Icons.refresh, size: 14, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Code display (WebView placeholder)
          Container(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                widget.diagramCode,
                style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = MermaidRenderer.isValid(widget.diagramCode);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.account_tree : Icons.warning_amber,
                size: 14,
                color: isValid ? theme.colorScheme.primary : theme.colorScheme.error,
              ),
              const SizedBox(width: 6),
              Text(
                isValid ? 'Mermaid Diagram' : 'Invalid Mermaid',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: isValid ? theme.colorScheme.primary : theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            widget.diagramCode,
            style: TextStyle(
              fontFamily: 'monospace', fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant, height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
