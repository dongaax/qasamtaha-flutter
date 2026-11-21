import 'balances.dart';
import 'models.dart';

String buildSummary({
  required String groupName,
  required List<Expense> expenses,
  required List<Settlement> settlements,
  required String Function(String uid) name,
}) {
  final total = expenses.fold<int>(0, (s, e) => s + e.amount);
  final transfers = simplifyDebts(netBalances(expenses, settlements));
  final b = StringBuffer()
    ..writeln('📊 حسابات "$groupName"')
    ..writeln('إجمالي المصاريف: ${egp(total)} ج')
    ..writeln();
  if (transfers.isEmpty) {
    b.writeln('✅ كله متصفّي');
  } else {
    b.writeln('التسوية المقترحة:');
    for (final t in transfers) {
      b.writeln('• ${name(t.from)} ← ${name(t.to)}: ${egp(t.amount)} ج');
    }
  }
  b..writeln()..write('اتحسبت بتطبيق قسمتها');
  return b.toString();
}