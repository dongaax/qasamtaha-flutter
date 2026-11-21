import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/share.dart';
import '../../core/theme.dart';
import '../../domain/summary.dart';
import '../../data/repo.dart';
import '../../domain/balances.dart';
import '../../domain/models.dart';
import '../../widgets/group_data_loader.dart';
import '../expenses/add_expense_screen.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.gid});
  final String gid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: Repo.instance.group(gid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final g = snap.data!.data();
        if (g == null) return const Scaffold(body: Center(child: Text('المجموعة مش موجودة')));
        final members = List<String>.from(g['members'] ?? []);
        final guests = Map<String, String>.from(g['guests'] ?? {}); // id -> اسم (من غير تطبيق)
        final admin = (g['createdBy'] ?? '') as String;
        return FutureBuilder<Map<String, String>>(
          future: Repo.instance.names(members),
          builder: (context, ns) => _Body(
            gid: gid, title: g['name'] ?? '', members: members, guests: guests, admin: admin,
            names: {...(ns.data ?? {for (final m in members) m: 'عضو'}), ...guests}),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.gid, required this.title, required this.members, required this.names,
    required this.guests, required this.admin});
  final String gid, title, admin; 
  final List<String> members; 
  final Map<String, String> guests; 
  final Map<String, String> names; 

  String label(String uid) => uid == Repo.instance.uid ? 'إنت' : (names[uid] ?? 'عضو');

  Future<void> _addMemberDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    String? err;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('إضافة عضو'),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, textDirection: TextDirection.ltr,
          decoration: InputDecoration(hintText: '01XXXXXXXXX', errorText: err)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              final ph = ctrl.text.trim();
              if (!RegExp(r'^01[0125]\d{8}$').hasMatch(ph)) return setS(() => err = 'رقم موبايل مصري صحيح من فضلك');
              final u = await Repo.instance.findUserByPhone(ph);
              if (u == null) return setS(() => err = 'الرقم ده لسه مسجّلش في قسمتها');
              if (members.contains(u.uid)) return setS(() => err = 'العضو ده موجود بالفعل');
              await Repo.instance.addMember(gid, u.uid);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('إضافة')),
        ],
      )),
    );
  }

  Future<void> _record(Transfer t) =>
      Repo.instance.addSettlement(gid, Settlement(from: t.from, to: t.to, amount: t.amount));

  Future<void> _received(BuildContext context, Transfer t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الاستلام'),
        content: Text('استلمت ${egp(t.amount)} ج من ${label(t.from)}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لأ')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('أيوه، استلمت')),
        ]),
    );
    if (ok == true) await _record(t);
  }

  Future<void> _pay(BuildContext context, Transfer t) async {
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaySheet(to: t.to, name: label(t.to), amount: t.amount),
    );
    if (paid == true) await _record(t);
  }

  Map<String, String> get _everyone => {for (final m in members) m: names[m] ?? 'عضو', ...guests};

  bool _canEdit(Expense e) => Repo.instance.uid == admin || Repo.instance.uid == e.createdBy;

  Future<void> _addGuestDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    String? err;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('إضافة شخص بالاسم'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, decoration: InputDecoration(hintText: 'مثال: محمد', errorText: err)),
          const SizedBox(height: 8),
          Text('الشخص ده مش محتاج التطبيق، إنت اللي هتكتب مصاريفه.',
            style: TextStyle(color: context.pal.mute, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              final n = ctrl.text.trim();
              if (n.isEmpty) return setS(() => err = 'اكتب الاسم');
              if (names.values.contains(n)) return setS(() => err = 'الاسم ده موجود بالفعل');
              await Repo.instance.addGuest(gid, n);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('إضافة')),
        ],
      )),
    );
  }

  void _edit(BuildContext context, Expense e) => Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => AddExpenseScreen(
      gid: gid, names: _everyone, existing: e)));

  Future<void> _delete(BuildContext context, Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المصروف'),
        content: Text('تحذف "${e.description}" (${egp(e.amount)} ج)؟ الحسابات هتتحدّث تلقائي.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لأ')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('احذف')),
        ]),
    );
    if (ok != true) return;
    try {
      await Repo.instance.deleteExpense(gid, e.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مقدرناش نحذف المصروف، جرّب تاني')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: p.bg, elevation: 0, centerTitle: true,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onSelected: (v) => v == 'phone' ? _addMemberDialog(context) : _addGuestDialog(context),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'phone', child: Text('إضافة عضو برقم موبايل')),
                PopupMenuItem(value: 'guest', child: Text('إضافة شخص بالاسم')),
              ]),
          ],
          bottom: TabBar(
            labelColor: p.acc, indicatorColor: p.acc, unselectedLabelColor: p.mute,
            tabs: const [Tab(text: 'المصاريف'), Tab(text: 'الحسابات')]),
        ),
        body: GroupDataLoader(
          gid: gid,
          builder: (context, expenses, settlements) => TabBarView(children: [
            _ExpensesTab(
              expenses: expenses, settlements: settlements, label: label,
              onEdit: (e) => _edit(context, e),
              onDelete: (e) => _delete(context, e),
              canEdit: _canEdit),
            _BalancesTab(
              expenses: expenses, settlements: settlements, label: label,
              onPay: (t) => _pay(context, t),
              onReceived: (t) => _received(context, t),
              summary: () => buildSummary(
                groupName: title, expenses: expenses, settlements: settlements,
                name: (u) => names[u] ?? 'عضو')),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: p.acc, foregroundColor: Colors.white,
          icon: const Icon(Icons.add), label: const Text('مصروف'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AddExpenseScreen(gid: gid, names: _everyone))),
        ),
      ),
    );
  }
}

class BalanceText extends StatelessWidget {
  const BalanceText(this.net, {super.key});
  final int net;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    if (net == 0) return Text('متصفّي', style: TextStyle(color: p.mute, fontWeight: FontWeight.w700));
    return Text(net > 0 ? 'ليك ${egp(net)} ج' : 'عليك ${egp(-net)} ج',
      style: TextStyle(color: net > 0 ? Colors.green.shade600 : p.acc, fontWeight: FontWeight.w800));
  }
}

class _ExpensesTab extends StatelessWidget {
  const _ExpensesTab({
    required this.expenses, required this.settlements, required this.label,
    required this.onEdit, required this.onDelete, required this.canEdit});
  final List<Expense> expenses;
  final List<Settlement> settlements;
  final String Function(String) label;
  final void Function(Expense) onEdit;
  final Future<void> Function(Expense) onDelete;
  final bool Function(Expense) canEdit; 

  @override
  Widget build(BuildContext context) {
    final p = context.pal, me = Repo.instance.uid;
    final myNet = netBalances(expenses, settlements)[me] ?? 0;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 90), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: p.accSoft, borderRadius: BorderRadius.circular(22)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('رصيدك في المجموعة', style: TextStyle(fontWeight: FontWeight.w700)),
          BalanceText(myNet),
        ]),
      ),
      const SizedBox(height: 14),
      if (expenses.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(child: Text('لسه مفيش مصاريف.\nدوس "مصروف" وابدأ.',
            textAlign: TextAlign.center, style: TextStyle(color: p.mute, height: 1.8)))),
      if (expenses.any(canEdit))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('دوس على المصروف لتعديله، واسحبه لحذفه',
            style: TextStyle(color: p.mute, fontSize: 12))),
      for (final e in expenses)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: ValueKey(e.id),
            direction: canEdit(e) ? DismissDirection.horizontal : DismissDirection.none,
            confirmDismiss: (_) async {
              await onDelete(e);
              return false; 
            },
            background: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.delete_outline, color: Colors.white)),
            child: GestureDetector(
              onTap: () {
                if (canEdit(e)) {
                  onEdit(e);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('اللي ضاف المصروف أو صاحب المجموعة بس يقدر يعدّله')));
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.description, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('${label(e.paidBy)} دفع', style: TextStyle(color: p.mute, fontSize: 13)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${egp(e.amount)} ج', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    if (e.shares.containsKey(me))
                      Text('نصيبك ${egp(e.shares[me]!)}', style: TextStyle(color: p.mute, fontSize: 12)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _BalancesTab extends StatelessWidget {
  const _BalancesTab({
    required this.expenses, required this.settlements, required this.label,
    required this.onPay, required this.onReceived, required this.summary});
  final List<Expense> expenses;
  final List<Settlement> settlements;
  final String Function(String) label;
  final void Function(Transfer) onPay, onReceived;
  final String Function() summary; 

  @override
  Widget build(BuildContext context) {
    final p = context.pal, me = Repo.instance.uid;
    final transfers = simplifyDebts(netBalances(expenses, settlements));
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('التسوية المقترحة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 4),
      Text('أقل عدد تحويلات عشان الكل يتصفّى.', style: TextStyle(color: p.mute, fontSize: 13)),
      const SizedBox(height: 12),
      if (transfers.isEmpty)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: p.sand, borderRadius: BorderRadius.circular(20)),
          child: const Center(child: Text('كله متصفّي ✅', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)))),
      for (final t in transfers)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
          child: Row(children: [
            Expanded(child: Text('${label(t.from)}  ←  ${label(t.to)}', style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('${egp(t.amount)} ج', style: TextStyle(fontWeight: FontWeight.w800, color: p.acc)),
            const SizedBox(width: 8),
            if (t.from == me)
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(72, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
                onPressed: () => onPay(t),
                child: const Text('ادفع'))
            else if (t.to == me)
              TextButton(onPressed: () => onReceived(t), child: const Text('استلمت')),
          ]),
        ),
      if (expenses.isNotEmpty) ...[
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => shareText(summary()),
          icon: const Icon(Icons.share_outlined),
          label: const Text('شارك الملخص')),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: summary()));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('اتنسخ الملخص')));
            }
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('نسخ الملخص')),
      ],
    ]);
  }
}

class _PaySheet extends StatefulWidget {
  const _PaySheet({required this.to, required this.name, required this.amount});
  final String to, name;
  final int amount;
  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  String? _copied;
  late final Future<Map<String, dynamic>> _profile = Repo.instance.profile(widget.to);

  Future<void> _copy(String v) async {
    await Clipboard.setData(ClipboardData(text: v));
    if (mounted) setState(() => _copied = v);
  }

  Widget _method(String title, String value) {
    final p = context.pal;
    final done = _copied == value;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: p.mute, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ])),
        TextButton.icon(
          onPressed: () => _copy(value),
          icon: Icon(done ? Icons.check : Icons.copy, size: 18),
          label: Text(done ? 'اتنسخ' : 'نسخ')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('ادفع لـ ${widget.name}', textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 6),
          Text('${egp(widget.amount)} ج', textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: p.acc)),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _profile,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
              }
              final data = snap.data ?? {};
              final vf = (data['vodafoneCash'] ?? '').toString().trim();
              final insta = (data['instapay'] ?? '').toString().trim();
              return Column(children: [
                if (vf.isNotEmpty) _method('فودافون كاش', vf),
                if (insta.isNotEmpty) _method('إنستا باي', insta),
                if (vf.isEmpty && insta.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('${widget.name} لسه ما ضافش فودافون كاش أو إنستا باي.\nادفعله كاش أو بأي طريقة بينكم.',
                      textAlign: TextAlign.center, style: TextStyle(color: p.mute, height: 1.7))),
              ]);
            },
          ),
          const SizedBox(height: 4),
          Text('بعد ما تحوّل، دوس "تم الدفع" عشان يتسجل.',
            textAlign: TextAlign.center, style: TextStyle(color: p.mute, fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تم الدفع')),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        ]),
      ),
    );
  }
}