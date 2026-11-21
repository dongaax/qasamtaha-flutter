import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(), _code = TextEditingController();
  String? _verificationId, _error;
  bool _busy = false;

  final _auth = FirebaseAuth.instance;

  String get _e164 => '+2${_phone.text.trim()}';

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!RegExp(r'^01[0125]\d{8}$').hasMatch(_phone.text.trim())) {
      setState(() => _error = 'اكتب رقم موبايل مصري صحيح');
      return;
    }
    setState(() { _busy = true; _error = null; });
    await _auth.verifyPhoneNumber(
      phoneNumber: _e164,
      verificationCompleted: (cred) => _auth.signInWithCredential(cred),
      verificationFailed: (e) {
        debugPrint('PHONE AUTH ERROR: ${e.code} | ${e.message}');
        if (!mounted) return;
        setState(() { _busy = false; _error = 'مقدرناش نبعت الكود، جرّب تاني'; });
      },
      codeSent: (id, _) {
        if (!mounted) return;
        setState(() { _verificationId = id; _busy = false; });
      },
      codeAutoRetrievalTimeout: (id) => _verificationId = id,
    );
  }

  Future<void> _verify() async {
    setState(() { _busy = true; _error = null; });
    try {
      await _auth.signInWithCredential(PhoneAuthProvider.credential(
        verificationId: _verificationId!, smsCode: _code.text.trim()));
    } on FirebaseAuthException {
      if (!mounted) return;
      setState(() { _busy = false; _error = 'الكود غلط'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal, t = Theme.of(context).textTheme;
    final codeStep = _verificationId != null;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 74, height: 74,
              decoration: BoxDecoration(color: p.acc, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.attach_money, color: Colors.white, size: 38))),
            const SizedBox(height: 20),
            Text('قسمتها', textAlign: TextAlign.center, style: t.displaySmall!.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('قسّم المصاريف مع أصحابك\nمن غير لخبطة ولا حرج',
              textAlign: TextAlign.center, style: t.bodyLarge!.copyWith(color: p.mute, height: 1.7)),
            const SizedBox(height: 40),
            Text(codeStep ? 'كود التأكيد' : 'رقم الموبايل', style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: codeStep ? _code : _phone,
              keyboardType: TextInputType.number, textDirection: TextDirection.ltr,
              decoration: InputDecoration(hintText: codeStep ? '••••••' : '01XXXXXXXXX', errorText: _error),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : (codeStep ? _verify : _sendCode),
              child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(codeStep ? 'تأكيد' : 'تسجيل الدخول')),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _auth.signInAnonymously(),
              child: Text('متابعة كضيف بدون حساب', style: TextStyle(color: p.acc, fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}