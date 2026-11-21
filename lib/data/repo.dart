import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/models.dart';

class Repo {
  Repo._();
  static final instance = Repo._();

  final _db = FirebaseFirestore.instance;
  final _nameCache = <String, String>{};

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> _user(String id) => _db.collection('users').doc(id);
  DocumentReference<Map<String, dynamic>> group(String gid) => _db.collection('groups').doc(gid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> myProfile() => _user(uid).snapshots();

  Future<void> saveProfile({required String name, String vodafoneCash = '', String instapay = ''}) {
    final u = FirebaseAuth.instance.currentUser!;
    _nameCache[u.uid] = name;
    return _user(u.uid).set({
      'name': name,
      'phone': u.phoneNumber ?? '', // بصيغة +2010xxxxxxxx
      'vodafoneCash': vodafoneCash,
      'instapay': instapay,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> profile(String id) async {
    final d = await _user(id).get();
    return d.data() ?? {};
  }

  Future<({String uid, String name})?> findUserByPhone(String localPhone) async {
    final q = await _db.collection('users').where('phone', isEqualTo: '+2${localPhone.trim()}').limit(1).get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    final name = (d.data()['name'] ?? 'عضو') as String;
    _nameCache[d.id] = name;
    return (uid: d.id, name: name);
  }

  Future<Map<String, String>> names(Iterable<String> uids) async {
    final missing = uids.toSet().where((u) => !_nameCache.containsKey(u)).toList();
    for (var i = 0; i < missing.length; i += 10) {
      final chunk = missing.sublist(i, min(i + 10, missing.length));
      final q = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      for (final d in q.docs) {
        _nameCache[d.id] = (d.data()['name'] ?? 'عضو') as String;
      }
    }
    return {for (final u in uids) u: _nameCache[u] ?? 'عضو'};
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myGroups() =>
      _db.collection('groups').where('members', arrayContains: uid).snapshots();

  Future<String> createGroup({
    required String name, required String type, required List<String> members,
    List<String> guestNames = const [],
  }) async {
    final ref = await _db.collection('groups').add({
      'name': name,
      'type': type,
      'members': members,
      'guests': {for (final n in guestNames) _newGuestId(): n}, // id -> اسم
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> addMember(String gid, String memberUid) =>
      group(gid).update({'members': FieldValue.arrayUnion([memberUid])});

  String _newGuestId() => 'g_${_db.collection('guests').doc().id}';

  Future<void> addGuest(String gid, String name) =>
      group(gid).update({'guests.${_newGuestId()}': name});

  Stream<List<Expense>> expenses(String gid) => group(gid)
      .collection('expenses').orderBy('createdAt', descending: true).snapshots()
      .map((q) => q.docs.map((d) => Expense.fromMap(d.id, d.data())).toList());

  Stream<List<Settlement>> settlements(String gid) => group(gid)
      .collection('settlements').snapshots()
      .map((q) => q.docs.map((d) => Settlement.fromMap(d.data())).toList());

  Future<void> addExpense(String gid, Expense e) =>
      group(gid).collection('expenses').add({
        ...e.toMap(), 'createdBy': uid, 'createdAt': FieldValue.serverTimestamp()});

  Future<void> updateExpense(String gid, Expense e) =>
      group(gid).collection('expenses').doc(e.id).update(e.toMap());

  Future<void> deleteExpense(String gid, String expenseId) =>
      group(gid).collection('expenses').doc(expenseId).delete();

  Future<void> addSettlement(String gid, Settlement s) =>
      group(gid).collection('settlements').add({...s.toMap(), 'createdAt': FieldValue.serverTimestamp()});
}