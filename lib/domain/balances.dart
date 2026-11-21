import 'models.dart';

Map<String, int> splitEqually(int amount, List<String> memberIds) {
  final n = memberIds.length, base = amount ~/ n, rem = amount % n;
  return {for (var i = 0; i < n; i++) memberIds[i]: base + (i < rem ? 1 : 0)};
}

Map<String, int> splitByPercent(int amount, Map<String, int> percents) {
  final out = {for (final e in percents.entries) e.key: amount * e.value ~/ 100};
  final diff = amount - out.values.fold<int>(0, (a, b) => a + b);
  final first = out.keys.first;
  out[first] = out[first]! + diff;
  return out;
}

Map<String, int> netBalances(List<Expense> expenses, [List<Settlement> settlements = const []]) {
  final net = <String, int>{};
  void add(String u, int v) => net[u] = (net[u] ?? 0) + v;
  for (final e in expenses) {
    add(e.paidBy, e.amount);
    e.shares.forEach((u, s) => add(u, -s));
  }
  for (final s in settlements) {
    add(s.from, s.amount);
    add(s.to, -s.amount);
  }
  return net;
}

Map<String, int> pairwise(String me, List<Expense> expenses, [List<Settlement> settlements = const []]) {
  final p = <String, int>{};
  void add(String u, int v) => p[u] = (p[u] ?? 0) + v;
  for (final e in expenses) {
    if (e.paidBy == me) {
      e.shares.forEach((u, s) { if (u != me) add(u, s); });
    } else if (e.shares.containsKey(me)) {
      add(e.paidBy, -e.shares[me]!);
    }
  }
  for (final s in settlements) {
    if (s.from == me) add(s.to, s.amount);
    if (s.to == me) add(s.from, -s.amount);
  }
  p.removeWhere((_, v) => v == 0);
  return p;
}

List<Transfer> simplifyDebts(Map<String, int> net) {
  final cred = net.entries.where((e) => e.value > 0).map((e) => [e.key, e.value]).toList();
  final debt = net.entries.where((e) => e.value < 0).map((e) => [e.key, -e.value]).toList();
  cred.sort((a, b) => (b[1] as int).compareTo(a[1] as int));
  debt.sort((a, b) => (b[1] as int).compareTo(a[1] as int));
  final out = <Transfer>[];
  var i = 0, j = 0;
  while (i < cred.length && j < debt.length) {
    final amt = (cred[i][1] as int) < (debt[j][1] as int) ? cred[i][1] as int : debt[j][1] as int;
    out.add(Transfer(debt[j][0] as String, cred[i][0] as String, amt));
    cred[i][1] = (cred[i][1] as int) - amt;
    debt[j][1] = (debt[j][1] as int) - amt;
    if (cred[i][1] == 0) i++;
    if (debt[j][1] == 0) j++;
  }
  return out;
}

String egp(int piasters) {
  final v = piasters / 100;
  return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

int? parseEgp(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  var s = input.trim().replaceAll('٫', '.').replaceAll(',', '.').replaceAll('،', '.');
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(arabic[i], '$i');
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)) return null;
  final v = (double.parse(s) * 100).round();
  return v > 0 ? v : null;
}
Map<String, int> splitByItems(List<({int price, List<String> who})> items, int total) {
  final base = <String, int>{};
  for (final it in items) {
    splitEqually(it.price, it.who).forEach((u, v) => base[u] = (base[u] ?? 0) + v);
  }
  final itemsSum = base.values.fold<int>(0, (a, b) => a + b);
  if (itemsSum == 0) return base;
  final extra = total - itemsSum;
  if (extra == 0) return base;
  final out = <String, int>{};
  var given = 0;
  base.forEach((u, v) {
    final x = extra * v ~/ itemsSum;
    out[u] = v + x;
    given += x;
  });
  final biggest = base.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  out[biggest] = out[biggest]! + (extra - given);
  return out;
}