import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../data/receipt_scanner.dart';
import '../../data/repo.dart';
import '../../domain/balances.dart';
import '../../domain/models.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key, required this.gid, required this.names});
  final String gid;
  final Map<String, String> names; // uid -> اسم

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final _picker = ImagePicker();
  final _desc = TextEditingController(text: 'فاتورة');
  final _total = TextEditingController();
  List<ScanItem>? _items;
  late String _paidBy = Repo.instance.uid;
  bool _scanning = false, _saving = false;
  String? _error;

  String _label(String uid) => uid == Repo.instance.uid ? 'إنت' : (widget.names[uid] ?? 'عضو');

  Future<void> _pick(ImageSource src) async {
    final f = await _picker.pickImage(source: src, maxWidth: 1600, imageQuality: 80);
    if (f == null) return;
    setState(() { _scanning = true; _error = null; });
    try {
      final r = await scanReceipt(f, widget.names.keys.toSet());
      if (!mounted) return;
      setState(() { _items = r.items; _total.text = egp(r.total); _scanning = false; });
    } on ReceiptScanException catch (e) {
      if (mounted) setState(() { _error = e.message; _scanning = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'حصلت مشكلة في قراءة الفاتورة، جرّب تاني'; _scanning = false; });
    }
  }

  /// نصيب كل واحد، أو null لو لسه فيه صنف من غير حد أو الإجمالي غلط
  Map<String, int>? _shares() {
    final items = _items, total = parseEgp(_total.text);
    if (items == null || total == null) return null;
    if (items.any((i) => i.assignees.isEmpty)) return null;
    final order = widget.names.keys.toList();
    return splitByItems([
      for (final i in items) (price: i.price, who: order.where(i.assignees.contains).toList()),
    ], total);
  }

  Future<void> _editItem(ScanItem it) async {
    final n = TextEditingController(text: it.name);
    final pr = TextEditingController(text: egp(it.price));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الصنف'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: const InputDecoration(hintText: 'الاسم')),
          const SizedBox(height: 10),
          TextField(controller: pr, textDirection: TextDirection.ltr,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'السعر')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    final v = parseEgp(pr.text);
    if (ok == true && v != null) setState(() { it.name = n.text.trim(); it.price = v; });
  }

  Future<void> _save() async {
    final total = parseEgp(_total.text), shares = _shares();
    if (total == null) return setState(() => _error = 'اكتب الإجمالي صح');
    if (shares == null) return setState(() => _error = 'كل صنف لازم يتحدد له شخص واحد على الأقل');
    setState(() { _saving = true; _error = null; });
    try {
      await Repo.instance.addExpense(widget.gid, Expense(
        id: '', description: _desc.text.trim().isEmpty ? 'فاتورة' : _desc.text.trim(),
        paidBy: _paidBy, amount: total, shares: shares));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'مقدرناش نحفظ المصروف، جرّب تاني'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(backgroundColor: p.bg, elevation: 0, centerTitle: true,
        title: const Text('مسح فاتورة', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _scanning
        ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('بقرا الفاتورة...'),
          ]))
        : (_items == null ? _pickStep(p) : _reviewStep(p)),
    );
  }

  Widget _pickStep(Palette p) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Icon(Icons.document_scanner_outlined, size: 80, color: p.acc),
      const SizedBox(height: 16),
      const Text('صوّر الفاتورة', textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
      const SizedBox(height: 6),
      Text('خلّي الفاتورة مفرودة وفي نور كويس، وبعدين وزّع الأصناف على أصحابك.',
        textAlign: TextAlign.center, style: TextStyle(color: p.mute, height: 1.7)),
      if (_error != null) ...[
        const SizedBox(height: 14),
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
      ],
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: () => _pick(ImageSource.camera),
        icon: const Icon(Icons.photo_camera_outlined), label: const Text('تصوير بالكاميرا')),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => _pick(ImageSource.gallery),
        icon: const Icon(Icons.photo_library_outlined), label: const Text('اختيار من المعرض'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), foregroundColor: p.acc,
          side: BorderSide(color: p.acc), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))),
    ]),
  );

  Widget _reviewStep(Palette p) {
    final items = _items!;
    final total = parseEgp(_total.text);
    final itemsSum = items.fold<int>(0, (s, i) => s + i.price);
    final shares = _shares();
    final diff = total == null ? 0 : total - itemsSum;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('الوصف', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextField(controller: _desc, decoration: const InputDecoration(hintText: 'مثال: عشاء')),
      const SizedBox(height: 18),
      const Text('مين دفع؟', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final u in widget.names.keys)
          ChoiceChip(label: Text(_label(u)), selected: _paidBy == u,
            selectedColor: p.accSoft, onSelected: (_) => setState(() => _paidBy = u)),
      ]),
      const SizedBox(height: 18),
      const Text('الأصناف (دوس على الصنف لتعديله)', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final it in items)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () => _editItem(it),
              child: Row(children: [
                Expanded(child: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                Text('${egp(it.price)} ج', style: TextStyle(fontWeight: FontWeight.w800, color: p.acc)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => setState(() => items.remove(it))),
              ]),
            ),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final u in widget.names.keys)
                FilterChip(
                  label: Text(_label(u)), selected: it.assignees.contains(u),
                  selectedColor: p.accSoft, showCheckmark: false,
                  onSelected: (v) => setState(() => v ? it.assignees.add(u) : it.assignees.remove(u))),
            ]),
          ]),
        ),
      const SizedBox(height: 8),
      const Text('الإجمالي بعد الضريبة والخدمة (جنيه)', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextField(controller: _total, textDirection: TextDirection.ltr, onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true)),
      if (total != null && diff != 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${diff > 0 ? 'ضريبة/خدمة' : 'خصم'} ${egp(diff.abs())} ج هتتوزع بنسبة اللي طلبه كل واحد',
            style: TextStyle(color: p.mute, fontSize: 12))),
      const SizedBox(height: 18),
      const Text('نصيب كل واحد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 8),
      if (shares == null)
        Text('وزّع كل الأصناف على حد على الأقل واتأكد من الإجمالي.', style: TextStyle(color: p.mute))
      else
        for (final e in shares.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text(_label(e.key))),
              Text('${egp(e.value)} ج', style: const TextStyle(fontWeight: FontWeight.w800)),
            ])),
      if (_error != null)
        Padding(padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text('حفظ المصروف')),
      TextButton(
        onPressed: () => setState(() { _items = null; _error = null; }),
        child: const Text('صوّر فاتورة تانية')),
    ]);
  }
}