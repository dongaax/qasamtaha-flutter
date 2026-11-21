import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/repo.dart';
import 'group_detail_screen.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});
  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  static const _types = {'trip': 'رحلة', 'flat': 'شقة', 'outing': 'خروجة', 'other': 'تانية'};
  final _name = TextEditingController(), _phone = TextEditingController();
  String _type = 'trip';
  final _members = <String, String>{}; 
  String? _nameErr, _phoneErr;
  final _guestName = TextEditingController();
  final _guests = <String>[]; 
  String? _guestErr;
  bool _busy = false, _searching = false;

  Future<void> _addMember() async {
    final ph = _phone.text.trim();
    if (!RegExp(r'^01[0125]\d{8}$').hasMatch(ph)) {
      setState(() => _phoneErr = 'اكتب رقم موبايل مصري صحيح');
      return;
    }
    setState(() { _searching = true; _phoneErr = null; });
    try {
      final u = await Repo.instance.findUserByPhone(ph);
      if (!mounted) return;
      if (u == null) {
        setState(() => _phoneErr = 'الرقم ده لسه مسجّلش في قسمتها');
      } else if (u.uid == Repo.instance.uid) {
        setState(() => _phoneErr = 'ده رقمك إنت 😄');
      } else {
        setState(() { _members[u.uid] = u.name; _phone.clear(); });
      }
    } catch (_) {
      if (mounted) setState(() => _phoneErr = 'حصلت مشكلة، جرّب تاني');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _addGuest() {
    final n = _guestName.text.trim();
    if (n.isEmpty) {
      setState(() => _guestErr = 'اكتب الاسم');
      return;
    }
    if (_guests.contains(n) || _members.values.contains(n)) {
      setState(() => _guestErr = 'الاسم ده موجود بالفعل');
      return;
    }
    setState(() { _guests.add(n); _guestName.clear(); _guestErr = null; });
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameErr = 'اكتب اسم المجموعة');
      return;
    }
    setState(() { _busy = true; _nameErr = null; });
    try {
      final gid = await Repo.instance.createGroup(
        name: _name.text.trim(), type: _type, members: [Repo.instance.uid, ..._members.keys],
        guestNames: _guests);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GroupDetailScreen(gid: gid)));
    } catch (_) {
      if (mounted) setState(() { _busy = false; _nameErr = 'مقدرناش نعمل المجموعة، جرّب تاني'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(backgroundColor: p.bg, elevation: 0, centerTitle: true,
        title: const Text('مجموعة جديدة', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('اسم المجموعة', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _name, decoration: InputDecoration(hintText: 'مثال: رحلة الساحل', errorText: _nameErr)),
        const SizedBox(height: 20),
        const Text('النوع', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final e in _types.entries)
            ChoiceChip(
              label: Text(e.value), selected: _type == e.key,
              selectedColor: p.accSoft, onSelected: (_) => setState(() => _type = e.key)),
        ]),
        const SizedBox(height: 24),
        const Text('ضيف أصحابك برقم موبايلهم', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('لازم يكونوا سجّلوا في قسمتها الأول.', style: TextStyle(color: p.mute, fontSize: 12)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.number, textDirection: TextDirection.ltr,
            decoration: InputDecoration(hintText: '01XXXXXXXXX', errorText: _phoneErr))),
          const SizedBox(width: 10),
          SizedBox(height: 56, child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
            onPressed: _searching ? null : _addMember,
            child: _searching
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.add))),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(label: const Text('إنت'), backgroundColor: p.accSoft),
          for (final e in _members.entries)
            Chip(label: Text(e.value), onDeleted: () => setState(() => _members.remove(e.key))),
        ]),
        const SizedBox(height: 24),
        const Text('ضيف ناس من غير تطبيق (بالاسم)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('إنت اللي هتكتب مصاريفهم، ومش لازم يسجلوا.', style: TextStyle(color: p.mute, fontSize: 12)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: TextField(controller: _guestName,
            decoration: InputDecoration(hintText: 'مثال: محمد', errorText: _guestErr))),
          const SizedBox(width: 10),
          SizedBox(height: 56, child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
            onPressed: _addGuest,
            child: const Icon(Icons.add))),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in _guests)
            Chip(label: Text(n), onDeleted: () => setState(() => _guests.remove(n))),
        ]),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: _busy
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('إنشاء المجموعة')),
      ]),
    );
  }
}