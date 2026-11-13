/// 可选维吾尔语字体目录（字体文件随包内置，切换即时生效、无需联网）。
///
/// 说明：这些字体只含阿拉伯字母（维吾尔语）与拉丁字形，不含中日韩；
/// 中文会自动回落到系统字体，所以中维混排不会出方块。
library;

class AppFont {
  const AppFont(this.id, this.label, this.note);

  /// Flutter fontFamily（与 pubspec.yaml 中声明一致）
  final String id;

  /// 展示名
  final String label;

  /// 风格说明
  final String note;
}

/// 第一款为默认字体（既有正文可读性，也兼顾小字号清晰度）。
const List<AppFont> kFonts = [
  AppFont('ALKATIPAsliya', 'ALKATIP Asliya', '经典正文体 · 默认'),
  AppFont('ALKATIPBasma', 'ALKATIP Basma', '报刊印刷体 · 阅读舒适'),
  AppFont('ALKATIPKitab', 'ALKATIP Kitab', '书籍排版体 · 字面偏大'),
  AppFont('ALKATIPKufi', 'ALKATIP Kufi', '库法体 · 几何感强'),
  AppFont('ALKATIPTalik', 'ALKATIP Talik', '塔利格体 · 手写韵味'),
  AppFont('AlpsoftBasmaB', 'Alpsoft Basma B', '现代印刷 · 屏幕锐利'),
  AppFont('AlpsoftNesq', 'Alpsoft Nesq', '纳斯赫体 · 端正传统'),
  AppFont('AlpsoftKufi', 'Alpsoft Kufi', '库法体 · 标题醒目'),
  AppFont('UKIJTuz', 'UKIJ Tuz', 'UKIJ 标准正体'),
  AppFont('UUSUNAsliya', 'UUS UN Asliya', '方正结构 · 最省体积'),
];

const String kDefaultFont = 'ALKATIPAsliya';

/// 系统兜底字体（拉丁 / 中文 / 表情），用于没有内置字形时的回落。
const String kFallbackFont = 'NotoSansArabic';

String fontLabelOf(String id) {
  for (final f in kFonts) {
    if (f.id == id) return f.label;
  }
  return kFonts.first.label;
}
