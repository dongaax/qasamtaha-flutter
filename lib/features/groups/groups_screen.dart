import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/repo.dart';
import '../../domain/balances.dart';
import '../../widgets/group_data_loader.dart';
import 'group_detail_screen.dart';
import 'new_group_screen.dart';
import '../profile/profile_screen.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  void _newGroup(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewGroupScreen()));

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('متأكد إنك عايز تخرج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لأ')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج')),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.bg, elevation: 0, centerTitle: true,
        title: const Text('مجموعاتي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'بياناتي',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen(editing: true))),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: Repo.instance.myGroups(),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('حصلت مشكلة في تحميل المجموعات'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return _EmptyGroups(onNew: () => _newGroup(context));
          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final gid = docs[i].id, g = docs[i].data();
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupDetailScreen(gid: gid))),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.line)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text('${(g['members'] as List).length + ((g['guests'] as Map?)?.length ?? 0)} أعضاء',
                        style: TextStyle(color: p.mute)),
                    ])),
                    GroupDataLoader(
                      gid: gid,
                      placeholder: const SizedBox.shrink(),
                      builder: (_, ex, st) => BalanceText(netBalances(ex, st)[Repo.instance.uid] ?? 0),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: p.acc, foregroundColor: Colors.white,
        onPressed: () => _newGroup(context), child: const Icon(Icons.add)),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.onNew});
  final VoidCallback onNew;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 150, height: 150,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.sand),
            child: Icon(Icons.groups_2_outlined, size: 60, color: p.ok)),
          const SizedBox(height: 28),
          const Text('لسه مفيش مجموعات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
          const SizedBox(height: 8),
          Text('اعمل مجموعة لرحلة أو شقة أو خروجة،\nوضيف أصحابك وابدأ قسّم من غير لخبطة.',
            textAlign: TextAlign.center, style: TextStyle(color: p.mute, height: 1.8)),
          const SizedBox(height: 20),
          FilledButton(onPressed: onNew, child: const Text('+ مجموعة جديدة')),
        ]),
      ),
    );
  }
}