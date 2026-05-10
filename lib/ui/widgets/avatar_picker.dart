import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/services/avatar_service.dart';
import '../../main.dart';

class AvatarPicker extends StatelessWidget {
  const AvatarPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deps = Dependencies.of(context);
    final soul = deps.soulService.getActiveOrDefault();
    final hasCustom = deps.avatarService.hasCustomAvatar;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('头像', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasCustom)
                  ClipOval(
                    child: Image.file(
                      File(deps.avatarService.currentPath!),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  deps.avatarService.buildDefaultAvatar(soul.name, 64),
                const SizedBox(width: 16),
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
                    await deps.avatarService.pickFromGallery();
                    (context as Element).markNeedsBuild();
                  },
                  icon: const Icon(Icons.photo_library, size: 16),
                  label: const Text('从相册选择'),
                ),
                if (hasCustom) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      await deps.avatarService.setBuiltin(0);
                      (context as Element).markNeedsBuild();
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
