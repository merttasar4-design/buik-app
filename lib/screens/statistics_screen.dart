import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../theme/ui.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<_StatsData> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_StatsData> _loadStats() async {
    final meetingRows = await supabase
        .from('meetings')
        .select('id, committees(name)');

    final committeeCounts = <String, int>{};
    for (final row in meetingRows) {
      final committeeName =
          (row['committees'] as Map?)?['name'] as String? ?? '-';
      committeeCounts[committeeName] = (committeeCounts[committeeName] ?? 0) + 1;
    }
    final committeeStats = committeeCounts.entries
        .map((e) => _CommitteeStat(name: e.key, meetingCount: e.value))
        .toList()
      ..sort((a, b) => b.meetingCount.compareTo(a.meetingCount));

    final attendanceRows = await supabase
        .from('attendance_records')
        .select('user_id, profiles(full_name, email)');

    final memberCounts = <String, _MemberStat>{};
    for (final row in attendanceRows) {
      final userId = row['user_id'] as String;
      final profile = row['profiles'] as Map?;
      final name =
          (profile?['full_name'] as String?)?.trim().isNotEmpty == true
          ? profile!['full_name'] as String
          : (profile?['email'] as String? ?? 'Bilinmiyor');
      final existing = memberCounts[userId];
      memberCounts[userId] = _MemberStat(
        name: name,
        count: (existing?.count ?? 0) + 1,
      );
    }
    final memberStats = memberCounts.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return _StatsData(committees: committeeStats, members: memberStats);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'İSTATİSTİKLER',
          style: TextStyle(
            color: buikBrand,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        iconTheme: const IconThemeData(color: buikBrand),
      ),
      body: FutureBuilder<_StatsData>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: buikBrand),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'İstatistikler yüklenemedi. Lütfen tekrar deneyin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.muted),
              ),
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Alt Kurul Bazında Toplantı Sayısı',
                style: TextStyle(
                  color: context.colors.ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              if (data.committees.isEmpty)
                Row(
                  children: [
                    Icon(Icons.groups_outlined, size: 18, color: context.colors.faint),
                    const SizedBox(width: 8),
                    Text(
                      'Henüz toplantı kaydı yok.',
                      style: TextStyle(color: context.colors.mutedLight, fontSize: 13),
                    ),
                  ],
                )
              else
                ...() {
                  final maxCount = data.committees
                      .map((c) => c.meetingCount)
                      .reduce((a, b) => a > b ? a : b);
                  return data.committees.asMap().entries.map(
                    (entry) => BuikFadeIn(
                      delay: Duration(milliseconds: 40 * entry.key),
                      child: _StatRow(
                        label: entry.value.name,
                        value: '${entry.value.meetingCount}',
                        progress: entry.value.meetingCount / maxCount,
                      ),
                    ),
                  );
                }(),
              const SizedBox(height: 32),
              Text(
                'Üye Katılım Sıralaması',
                style: TextStyle(
                  color: context.colors.ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              if (data.members.isEmpty)
                Row(
                  children: [
                    Icon(Icons.checklist_outlined, size: 18, color: context.colors.faint),
                    const SizedBox(width: 8),
                    Text(
                      'Henüz yoklama kaydı yok.',
                      style: TextStyle(color: context.colors.mutedLight, fontSize: 13),
                    ),
                  ],
                )
              else
                ...() {
                  final maxCount = data.members
                      .map((m) => m.count)
                      .reduce((a, b) => a > b ? a : b);
                  return data.members.asMap().entries.map(
                    (entry) => BuikFadeIn(
                      delay: Duration(milliseconds: 40 * entry.key),
                      child: _StatRow(
                        label: entry.value.name,
                        value: '${entry.value.count} toplantı',
                        progress: entry.value.count / maxCount,
                        rank: entry.key + 1,
                      ),
                    ),
                  );
                }(),
            ],
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.progress,
    this.rank,
  });

  final String label;
  final String value;
  final double progress;
  final int? rank;

  Color? _rankColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFF5B301);
      case 2:
        return const Color(0xFFA8B2BD);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: buikCardDecoration(context, color: context.colors.brandSoft),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(color: buikBrand.withValues(alpha: 0.12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (rank != null) ...[
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _rankColor() ?? context.colors.faint,
                    ),
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: context.colors.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: buikBrand,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsData {
  final List<_CommitteeStat> committees;
  final List<_MemberStat> members;

  const _StatsData({required this.committees, required this.members});
}

class _CommitteeStat {
  final String name;
  final int meetingCount;

  const _CommitteeStat({required this.name, required this.meetingCount});
}

class _MemberStat {
  final String name;
  final int count;

  const _MemberStat({required this.name, required this.count});
}
