class Expense {
  final String id, description, paidBy, createdBy;
  final int amount;
  final Map<String, int> shares; 
  const Expense({required this.id, required this.description, required this.paidBy,
    required this.amount, required this.shares, this.createdBy = ''});

  factory Expense.fromMap(String id, Map<String, dynamic> m) => Expense(
    id: id, description: m['description'] ?? '', paidBy: m['paidBy'], amount: m['amount'],
    shares: Map<String, int>.from(m['shares'] ?? {}),
    createdBy: (m['createdBy'] ?? m['paidBy'] ?? '') as String);

  Map<String, dynamic> toMap() =>
    {'description': description, 'paidBy': paidBy, 'amount': amount, 'shares': shares};
}

class Settlement {
  final String from, to;
  final int amount;
  const Settlement({required this.from, required this.to, required this.amount});

  factory Settlement.fromMap(Map<String, dynamic> m) =>
    Settlement(from: m['from'], to: m['to'], amount: m['amount']);

  Map<String, dynamic> toMap() => {'from': from, 'to': to, 'amount': amount};
}

class Transfer {
  final String from, to;
  final int amount;
  const Transfer(this.from, this.to, this.amount);
  @override
  String toString() => '$from -> $to : $amount';
}