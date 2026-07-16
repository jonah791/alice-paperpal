/// 主题变体枚举
enum ThemeVariant {
  blue('蓝色', 'Blue'),
  cyan('青色', 'Cyan'),
  green('绿色', 'Green'),
  orange('橙色', 'Orange'),
  red('红色', 'Red'),
  black('黑色', 'Black'),
  alice('爱丽丝', 'Alice');

  final String labelCn;
  final String labelEn;
  const ThemeVariant(this.labelCn, this.labelEn);
}
