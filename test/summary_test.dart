import 'package:flutter_test/flutter_test.dart';
import 'package:qasamtaha/domain/models.dart';
import 'package:qasamtaha/domain/summary.dart';

void main() {
  String name(String u) => {'a': 'أحمد', 'b': 'بسمة'}[u] ?? u;

  test('summary lists the suggested transfers', () {
    const e = Expense(id: '1', description: 'عشاء', paidBy: 'a', amount: 10000,
        shares: {'a': 5000, 'b': 5000});
    final s = buildSummary(groupName: 'رحلة', expenses: [e], settlements: [], name: name);
    expect(s, contains('رحلة'));
    expect(s, contains('بسمة ← أحمد: 50 ج'));
    expect(s, contains('100 ج'));
  });

  test('summary says settled when nothing is owed', () {
    final s = buildSummary(groupName: 'رحلة', expenses: [], settlements: [], name: name);
    expect(s, contains('كله متصفّي'));
  });
}