/// Kori 风格头像选择器
import 'package:flutter/material.dart';
import '../../core/di/dependencies.dart';
import '../../core/interfaces/services.dart';
import 'avatar_helpers.dart';

class AvatarPicker extends StatefulWidget {
  const AvatarPicker({super.key});

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  String? _currentPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentPath = context.avatarService.currentPath;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final avatar = context.avatarService;
    final soul = context.soulService.activeSoul;
    final name = soul?.name ?? 'Alice';

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: colors.primaryContainer,
          child: buildDefaultAvatar(name, 28, avatar.colorForName(name)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              FilledButton.tonalIcon(
                onPressed: () async {
                  // TODO: image_picker integration with Kori style
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('头像功能待完善'), behavior: SnackBarBehavior.floating),
                  );
                },
                icon: const Icon(Icons.camera_alt, size: 16),
                label: const Text('更换头像', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
