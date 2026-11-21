import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/repo.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.editing = false});
  final bool editing;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController(), _vf = TextEditingController(), _insta = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.editing) {
      Repo.instance.profile(Repo.instance.uid).then((d) {
        if (!mounted) return;
        setState(() {
          _name.text = (d['name'] ?? '').toString();
          _vf.text = (d['vodafoneCash'] ?? '').toString();
          _insta.text = (d['instapay'] ?? '').toString();
        });
      });
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'اكتب اسمك');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await Repo.instance.saveProfile(
        name: _name.text.trim(), vodafoneCash: _vf.text.trim(), instapay: _insta.text.trim());
      if (widget.editing && mounted) Navigator.of(context).pop();
      // أول مرة: main.dart هيحوّلك لشاشة المجموعات تلقائي
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'مقدرناش نحفظ، جرّب تاني'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal, t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: widget.editing
        ? AppBar(backgroundColor: p.bg, elevation: 0, centerTitle: true,
            title: const Text('بياناتي', style: TextStyle(fontWeight: FontWeight.w800)))
        : null,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          if (!widget.editing) ...[
            const SizedBox(height: 30),
            Text('أهلاً بيك 👋', style: t.headlineMedium!.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('عرّفنا بيك عشان أصحابك يشوفوا اسمك.', style: t.bodyLarge!.copyWith(color: p.mute)),
            const SizedBox(height: 28),
          ] else ...[
            Text('أصحابك هيشوفوا الأرقام دي لما يدفعولك.', style: TextStyle(color: p.mute)),
            const SizedBox(height: 20),
          ],
          const Text('الاسم', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: InputDecoration(hintText: 'مثال: أحمد', errorText: _error)),
          const SizedBox(height: 18),
          const Text('فودافون كاش (اختياري)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _vf, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr,
            decoration: const InputDecoration(hintText: '01XXXXXXXXX')),
          const SizedBox(height: 18),
          const Text('إنستا باي (اختياري)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _insta, textDirection: TextDirection.ltr,
            decoration: const InputDecoration(hintText: 'name@instapay')),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.editing ? 'حفظ' : 'يلا نبدأ')),
          if (!widget.editing) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('تغيير الحساب')),
          ],
        ]),
      ),
    );
  }
}