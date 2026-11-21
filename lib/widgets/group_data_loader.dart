import 'package:flutter/material.dart';
import '../data/repo.dart';
import '../domain/models.dart';

class GroupDataLoader extends StatelessWidget {
  const GroupDataLoader({super.key, required this.gid, required this.builder, this.placeholder});
  final String gid;
  final Widget Function(BuildContext, List<Expense>, List<Settlement>) builder;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final wait = placeholder ?? const Center(child: CircularProgressIndicator());
    return StreamBuilder<List<Expense>>(
      stream: Repo.instance.expenses(gid),
      builder: (context, e) => StreamBuilder<List<Settlement>>(
        stream: Repo.instance.settlements(gid),
        builder: (context, s) {
          if (e.hasError || s.hasError) return const Center(child: Text('حصلت مشكلة في تحميل البيانات'));
          if (!e.hasData || !s.hasData) return wait;
          return builder(context, e.data!, s.data!);
        },
      ),
    );
  }
}