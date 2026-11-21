import 'package:flutter_test/flutter_test.dart';
import 'package:qasamtaha/domain/balances.dart';
import 'package:qasamtaha/domain/models.dart';

void main() {
  parseTests();
  test('equal split distributes remainder', () {
    final s = splitEqually(100000, ['a', 'b', 'c']);
    expect(s.values.fold(0, (a, b) => a + b), 100000);
    expect(s['a'], 33334);
  });
  test('pairwise: I paid 600 split 4 equally', () {
    final e = Expense(id: '1', description: 'عشاء', paidBy: 'me', amount: 60000,
      shares: splitEqually(60000, ['me', 'm', 's', 'y']));
    final p = pairwise('me', [e]);
    expect(p['m'], 15000);
    expect(p['s'], 15000);
  });
  test('settlement clears debt', () {
  const e = Expense(id: '1', description: 'x', paidBy: 's', amount: 30000,
    shares: {'me': 15000, 's': 15000});
  final p = pairwise('me', [e], [const Settlement(from: 'me', to: 's', amount: 15000)]);
  expect(p.isEmpty, true);
});
  test('simplifyDebts nets to zero', () {
    final t = simplifyDebts({'a': 300, 'b': -100, 'c': -200});
    expect(t.length, 2);
    expect(t.fold(0, (s, x) => s + x.amount), 300);
  });
}

void parseTests() {
  test('parseEgp', () {
    expect(parseEgp('450'), 45000);
    expect(parseEgp('112.5'), 11250);
    expect(parseEgp('١١٢٫٥'), 11250);
    expect(parseEgp('abc'), null);
    expect(parseEgp('0'), null);
    expect(parseEgp('-5'), null);
  });

  test('splitByItems spreads service on top of items', () {
    final s = splitByItems([
      (price: 6000, who: ['a', 'b']),
      (price: 4000, who: ['a']),
    ], 11000); // أصناف 100 + خدمة 10
    expect(s['a'], 7700);
    expect(s['b'], 3300);
    expect(s.values.fold(0, (x, y) => x + y), 11000);
  });
}