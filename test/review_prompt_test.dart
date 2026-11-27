import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimai_photo/core/review/review_prompt.dart';

void main() {
  test('asks on the 1st, 3rd and 8th save only', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2027, 1, 1);
    final prompt = ReviewPrompt(prefs, clock: () => now);
    final asked = <int>[];
    for (var i = 1; i <= 10; i++) {
      now = now.add(const Duration(days: 30));
      if (await prompt.recordSave()) asked.add(i);
    }
    expect(asked, [1, 3, 8]);
  });

  test('never asks twice within 60 days', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2027, 1, 1);
    final prompt = ReviewPrompt(prefs, clock: () => now);
    expect(await prompt.recordSave(), isTrue);
    expect(await prompt.recordSave(), isFalse);
    expect(await prompt.recordSave(), isFalse); // 3rd save, same day
    expect(prompt.saves, 3);
  });
}
