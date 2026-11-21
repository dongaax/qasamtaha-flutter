import 'package:flutter_test/flutter_test.dart';
import 'package:qasamtaha/domain/balances.dart';

void main() {
  test('splitByPercent gives the remainder to the first person', () {
    final s = splitByPercent(10001, {'a': 50, 'b': 30, 'c': 20});
    expect(s.values.fold(0, (x, y) => x + y), 10001);
    expect(s['a'], 5001);
    expect(s['b'], 3000);
    expect(s['c'], 2000);
  });

  test('splitByPercent with exact numbers has no remainder', () {
    final s = splitByPercent(20000, {'a': 70, 'b': 30});
    expect(s['a'], 14000);
    expect(s['b'], 6000);
  });
}