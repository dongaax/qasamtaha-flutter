import 'package:flutter_test/flutter_test.dart';
import 'package:qasamtaha/domain/models.dart';

void main() {
  test('createdBy falls back to paidBy for old expenses', () {
    final e = Expense.fromMap('1', {
      'description': 'x', 'paidBy': 'a', 'amount': 100, 'shares': {'a': 100},
    });
    expect(e.createdBy, 'a');
  });

  test('createdBy is read when present', () {
    final e = Expense.fromMap('1', {
      'description': 'x', 'paidBy': 'a', 'createdBy': 'b', 'amount': 100, 'shares': {'a': 100},
    });
    expect(e.createdBy, 'b');
  });

  test('toMap does not include createdBy, so editing keeps the original', () {
    const e = Expense(id: '1', description: 'x', paidBy: 'a', amount: 100, shares: {'a': 100});
    expect(e.toMap().containsKey('createdBy'), false);
  });
}