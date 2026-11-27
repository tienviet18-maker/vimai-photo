import 'package:intl/intl.dart';

/// Short date in the UI language: 15/11/2026, 11/15/2026, 2026/11/15.
String formatDate(DateTime d, String lang) {
  final locale = switch (lang) { 'zh-Hant' => 'zh_TW', 'pt' => 'pt_BR', _ => lang };
  try {
    return DateFormat.yMd(locale).format(d);
  } catch (_) {
    // Date symbols for this language were not loaded.
    return DateFormat.yMd('en').format(d);
  }
}
