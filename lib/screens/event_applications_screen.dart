import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../theme/ui.dart';

class EventApplicationsScreen extends StatefulWidget {
  const EventApplicationsScreen({super.key});

  @override
  State<EventApplicationsScreen> createState() =>
      _EventApplicationsScreenState();
}

class _EventApplicationsScreenState extends State<EventApplicationsScreen> {
  late Future<List<_EventApplicationGroup>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _load();
  }

  Future<void> _refresh() async {
    setState(() {
      _groupsFuture = _load();
    });
    await _groupsFuture;
  }

  Future<List<_EventApplicationGroup>> _load() async {
    final rows = await supabase
        .from('event_applications')
        .select(
          'applied_at, event_id, events(title), '
          'profiles(full_name, email, phone), '
          'guest_name, guest_email, guest_phone',
        )
        .order('applied_at', ascending: false);

    final groups = <int, _EventApplicationGroup>{};
    for (final row in rows) {
      final eventId = row['event_id'] as int;
      final eventTitle =
          (row['events'] as Map?)?['title'] as String? ?? 'Bilinmeyen Etkinlik';
      final profile = row['profiles'] as Map?;
      final isGuest = profile == null;
      final name = isGuest
          ? (row['guest_name'] as String? ?? 'Bilinmiyor')
          : (profile['full_name'] as String?)?.trim().isNotEmpty == true
          ? profile['full_name'] as String
          : (profile['email'] as String? ?? 'Bilinmiyor');
      final email = isGuest
          ? row['guest_email'] as String?
          : profile['email'] as String?;
      final phone = isGuest
          ? row['guest_phone'] as String?
          : profile['phone'] as String?;

      final group = groups.putIfAbsent(
        eventId,
        () => _EventApplicationGroup(title: eventTitle, applicants: []),
      );
      group.applicants.add(
        _Applicant(
          name: name,
          email: email,
          phone: phone,
          isGuest: isGuest,
          appliedAt: DateTime.parse(row['applied_at'] as String),
        ),
      );
    }
    final list = groups.values.toList()
      ..sort((a, b) => b.applicants.length.compareTo(a.applicants.length));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ETKİNLİK BAŞVURULARI',
          style: TextStyle(
            color: buikBrand,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontSize: 15,
          ),
        ),
        iconTheme: const IconThemeData(color: buikBrand),
      ),
      body: RefreshIndicator(
        color: buikBrand,
        onRefresh: _refresh,
        child: FutureBuilder<List<_EventApplicationGroup>>(
          future: _groupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: buikBrand),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Başvurular yüklenemedi. Lütfen tekrar deneyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.muted),
                ),
              );
            }
            final groups = snapshot.data ?? [];
            if (groups.isEmpty) {
              return const BuikEmptyState(
                icon: Icons.inbox_outlined,
                message: 'Henüz hiçbir etkinliğe başvuru yapılmadı.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => BuikFadeIn(
                delay: Duration(milliseconds: 40 * index),
                child: _EventGroupCard(group: groups[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EventGroupCard extends StatelessWidget {
  const _EventGroupCard({required this.group});

  final _EventApplicationGroup group;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: buikCardDecoration(context, color: colors.brandSoft),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: buikBrand,
          collapsedIconColor: colors.mutedLight,
          title: Text(
            group.title,
            style: TextStyle(
              color: colors.ink,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            '${group.applicants.length} başvuru',
            style: const TextStyle(color: buikBrand, fontSize: 12),
          ),
          children: group.applicants
              .map(
                (a) => ListTile(
                  dense: true,
                  leading: Icon(
                    a.isGuest ? Icons.person_off_outlined : Icons.person_outline,
                    color: a.isGuest ? buikBrand : colors.mutedLight,
                    size: 20,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          a.name,
                          style: TextStyle(color: colors.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (a.isGuest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: buikBrand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'MİSAFİR',
                            style: TextStyle(
                              color: buikBrand,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: (a.email != null || a.phone != null)
                      ? Text(
                          [
                            a.email,
                            a.phone,
                          ].whereType<String>().join(' · '),
                          style: TextStyle(
                            color: colors.mutedLight,
                            fontSize: 11,
                          ),
                        )
                      : null,
                  trailing: Text(
                    DateFormat('d MMM, HH:mm', 'tr_TR').format(a.appliedAt),
                    style: TextStyle(
                      color: colors.mutedLight,
                      fontSize: 11,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _EventApplicationGroup {
  final String title;
  final List<_Applicant> applicants;

  _EventApplicationGroup({required this.title, required this.applicants});
}

class _Applicant {
  final String name;
  final String? email;
  final String? phone;
  final bool isGuest;
  final DateTime appliedAt;

  const _Applicant({
    required this.name,
    this.email,
    this.phone,
    required this.isGuest,
    required this.appliedAt,
  });
}
