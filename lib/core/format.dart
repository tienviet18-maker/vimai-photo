import 'package:intl/intl.dart';

/// Short date in the UI language: 15/11/2026, 11/15/2026, 2026/11/15.
String formatDate(DateTime d, String languageCode) =>
    DateFormat.yMd(languageCode).format(d);
