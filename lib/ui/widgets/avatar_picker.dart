import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/di/dependencies.dart';
import '../../core/tokens/design_tokens.dart';
import 'avatar_helpers.dart';

class AvatarPicker extends StatelessWidget {
  const AvatarPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final soul = context.soulService.getActiveOrDefault();
    final hasCustom = context.avatarService.hasCustomAvatar;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('头像', style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                if (hasCustom)
                  ClipOval(
                    child: Image.file(
                      File(context.avatarService.currentPath!),
                      width: DesignTokens.sp16,
                      height: DesignTokens.sp16,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  buildDefaultAvatar(soul.name, DesignTokens.sp16, context.avatarService.colorForName(soul.name)),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hasCustom ? '自定义头像' : '默认头像',
                          style: theme.textTheme.bodySmall),
                      Text(soul.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                  
                      final result = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (result != null) {
                        await context.avatarService.setAvatarFromPath(result.path);
                        if (context.mounted) (context as Element).markNeedsBuild();
                      }
                    } catch (e) {
                      // Silently fail — avatar is non-critical
                    }
                  },
                  icon: const Icon(Icons.photo_library, size: 16),
                  label: const Text('从相册选择'),
                ),
                  if (hasCustom) ...[
                  const SizedBox(width: Spacing.gap),
                  TextButton(
                    onPressed: () async {
                      try {
                    
                        await context.avatarService.deleteBuiltin();
                        if (context.mounted) (context as Element).markNeedsBuild();
                      } catch (e) {
                        // Silently fail
                      }
                    },
                    child: const Text('恢复默认'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
