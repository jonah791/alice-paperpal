/// PaperPal 主题变体 — 融合 Kori + Alice
///
/// 前 6 个来自 Kori，Alice 是 PaperPal 原有的奇幻主题
library;

enum ThemeVariant {
  blue('Blue', '沉稳蓝'),
  cyan('Cyan', '清新青'),
  green('Green', '自然绿'),
  orange('Orange', '温暖橙'),
  red('Red', '赤陶红'),
  black('Black', '极简黑'),
  alice('Alice', 'Alice 奇幻');

  final String label;
  final String labelCn;
  const ThemeVariant(this.label, this.labelCn);
}
