import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/repo.dart';
import '../../domain/balances.dart';
import '../../domain/models.dart';
import 'scan_receipt_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, required this.gid, required this.names, this.existing});
  final String gid;
  final Map<String, String> names; 
  final Expense? existing; 

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _desc = TextEditingController(), _amount = TextEditingController();
  final _pct = <String, TextEditingController>{}; // uid -> نسبته (للقسمة بالنسبة)
  late String _paidBy = Repo.instance.uid;
  final Set<String> _selected = {}; 
  bool _byPercent = false;
  bool _customShares = false; 
  String? _error;
  bool _busy = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    for (final u in widget.names.keys) {
      _pct[u] = TextEditingController();
    }
    _selected.addAll(widget.names.keys);
    final e = widget.existing;
    if (e != null) {
      _desc.text = e.description;
      _amount.text = egp(e.amount);
      _paidBy = e.paidBy;
      _selected
        ..clear()
        ..addAll(e.shares.keys.where(widget.names.containsKey));
      final v = e.shares.values;
      if (v.isNotEmpty) {
        final hi = v.reduce((a, b) => a > b ? a : b);
        final lo = v.reduce((a, b) => a < b ? a : b);
        _customShares = hi - lo > 1; 
      }
    }
    _resetPercents();
  }

  @override
  void dispose() {
    _desc.dispose();
    _amount.dispose();
    for (final c in _pct.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _label(String uid) => uid == Repo.instance.uid ? 'إنت' : (widget.names[uid] ?? 'عضو');

  void _resetPercents() {
    final ids = widget.names.keys.where(_selected.contains).toList();
    for (final c in _pct.values) {
      c.clear();
    }
    if (ids.isEmpty) return;
    final base = 100 ~/ ids.length, rem = 100 % ids.length;
    for (var i = 0; i < ids.length; i++) {
      _pct[ids[i]]!.text = '${base + (i < rem ? 1 : 0)}';
    }
  }

  void _toggle(String uid, bool on) {
    setState(() {
      if (on) {
        _selected.add(uid);
      } else {
        _selected.remove(uid);
      }
      if (_byPercent) _resetPercents();
    });
  }

  Map<String, int>? _percents() {
    final out = <String, int>{};
    for (final u in widget.names.keys.where(_selected.contains)) {
      final v = int.tryParse(_pct[u]!.text.trim());
      if (v == null || v < 0) return null;
      out[u] = v;
    }
    return out;
  }

  Future<void> _save() async {
    final amount = parseEgp(_amount.text);
    if (_desc.text.trim().isEmpty) return setState(() => _error = 'اكتب وصف المصروف');
    if (amount == null) return setState(() => _error = 'اكتب مبلغ صحيح');
    if (_selected.isEmpty) return setState(() => _error = 'اختار شخص واحد على الأقل');

    final ids = widget.names.keys.where(_selected.contains).toList();
    final Map<String, int> shares;
    if (_byPercent) {
      final pcts = _percents();
      if (pcts == null || pcts.values.fold<int>(0, (a, b) => a + b) != 100) {
        return setState(() => _error = 'مجموع النسب لازم يبقى 100');
      }
      pcts.removeWhere((_, v) => v == 0);
      shares = splitByPercent(amount, pcts);
    } else {
      shares = splitEqually(amount, ids);
    }

    setState(() { _busy = true; _error = null; });
    try {
      final exp = Expense(
        id: widget.existing?.id ?? '', description: _desc.text.trim(), paidBy: _paidBy,
        amount: amount, shares: shares);
      if (_editing) {
        await Repo.instance.updateExpense(widget.gid, exp);
      } else {
        await Repo.instance.addExpense(widget.gid, exp);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'مقدرناش نحفظ المصروف، جرّب تاني'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final amount = parseEgp(_amount.text);
    final perHead = (!_byPercent && amount != null && _selected.isNotEmpty)
        ? egp(amount ~/ _selected.length) : null;
    final pcts = _byPercent ? _percents() : null;
    final pctSum = pcts?.values.fold<int>(0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(backgroundColor: p.bg, elevation: 0, centerTitle: true,
        title: Text(_editing ? 'تعديل المصروف' : 'مصروف جديد',
          style: const TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (!_editing) ...[
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => ScanReceiptScreen(gid: widget.gid, names: widget.names))),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('مسح فاتورة ورقية'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52), foregroundColor: p.acc,
              side: BorderSide(color: p.acc),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          ),
          const SizedBox(height: 18),
        ],
        if (_editing && _customShares) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.accSoft, borderRadius: BorderRadius.circular(14)),
            child: Text('المصروف ده متقسم صنف صنف. لو حفظت هتتبدّل القسمة بالطريقة اللي تختارها تحت.',
              style: TextStyle(color: p.ink, height: 1.6, fontSize: 13)),
          ),
          const SizedBox(height: 18),
        ],
        const Text('الوصف', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _desc, decoration: const InputDecoration(hintText: 'مثال: عشاء')),
        const SizedBox(height: 18),
        const Text('المبلغ (جنيه)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr, onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '0')),
        const SizedBox(height: 18),
        const Text('مين دفع؟', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final u in widget.names.keys)
            ChoiceChip(label: Text(_label(u)), selected: _paidBy == u,
              selectedColor: p.accSoft, onSelected: (_) => setState(() => _paidBy = u)),
        ]),
        const SizedBox(height: 18),
        const Text('طريقة القسمة', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('بالتساوي'), selected: !_byPercent, selectedColor: p.accSoft,
            onSelected: (_) => setState(() => _byPercent = false)),
          ChoiceChip(label: const Text('بالنسبة %'), selected: _byPercent, selectedColor: p.accSoft,
            onSelected: (_) => setState(() { _byPercent = true; _resetPercents(); })),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          const Expanded(child: Text('على مين؟', style: TextStyle(fontWeight: FontWeight.w700))),
          if (perHead != null) Text('$perHead ج للواحد', style: TextStyle(color: p.mute)),
          if (pctSum != null)
            Text('المجموع $pctSum%',
              style: TextStyle(color: pctSum == 100 ? p.mute : Colors.redAccent, fontWeight: FontWeight.w700)),
        ]),
        for (final u in widget.names.keys)
          _byPercent
            ? Row(children: [
                Checkbox(value: _selected.contains(u), activeColor: p.acc,
                  onChanged: (v) => _toggle(u, v == true)),
                Expanded(child: Text(_label(u))),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _pct[u], enabled: _selected.contains(u),
                    keyboardType: TextInputType.number, textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr, onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      suffixText: '%',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                  ),
                ),
              ])
            : CheckboxListTile(
                contentPadding: EdgeInsets.zero, activeColor: p.acc,
                title: Text(_label(u)), value: _selected.contains(u),
                onChanged: (v) => _toggle(u, v == true)),
        if (_error != null)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(_editing ? 'حفظ التعديلات' : 'حفظ المصروف')),
      ]),
    );
  }
}