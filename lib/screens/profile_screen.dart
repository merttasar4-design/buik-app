import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../theme/theme_controller.dart';
import '../theme/ui.dart';
import '../widgets/secondary_menu_drawer.dart';
import 'edit_profile_screen.dart';
import 'event_applications_screen.dart';
import 'login_screen.dart';
import 'raffle_admin_screen.dart';
import 'statistics_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_ProfileData> _profileFuture;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _loadProfile();
    });
    await _profileFuture;
  }

  Future<_ProfileData> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return const _ProfileData(profile: {}, attendance: []);
    }

    final profile = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    final rows = await supabase
        .from('attendance_records')
        .select('checked_in_at, meetings(meeting_number, committees(name))')
        .eq('user_id', user.id)
        .order('checked_in_at', ascending: false);

    final attendance = rows.map((row) {
      final meeting = row['meetings'] as Map?;
      final committeeName =
          (meeting?['committees'] as Map?)?['name'] as String? ?? '-';
      final meetingNumber = meeting?['meeting_number'];
      return _AttendanceEntry(
        label: '$committeeName · $meetingNumber. Toplantı',
        checkedInAt: DateTime.parse(row['checked_in_at'] as String),
      );
    }).toList();

    return _ProfileData(profile: profile ?? {}, attendance: attendance);
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          backgroundColor: colors.background,
          title: Text(
            'Hesabı Sil',
            style: TextStyle(color: colors.ink),
          ),
          content: Text(
            'Hesabınızı silmek istediğinize emin misiniz? Bu işlem geri alınamaz; profil bilgileriniz ve yoklama geçmişiniz tamamen silinir.',
            style: TextStyle(color: colors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Vazgeç',
                style: TextStyle(color: colors.muted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Hesabı Sil',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _isDeletingAccount = true);
    try {
      await supabase.rpc('delete_my_account');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hesap silinemedi. Lütfen tekrar deneyin.')));
      return;
    }

    try {
      await supabase.auth.signOut();
    } catch (_) {
      // Hesap zaten silindiği için oturum sonlandırma hatası göz ardı edilebilir.
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openAvatar(String avatarUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => _AvatarViewerScreen(avatarUrl: avatarUrl),
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'board':
        return 'Yönetim Kurulu';
      case 'coordinator':
        return 'Koordinatör';
      case 'mezun':
        return 'Mezun';
      default:
        return 'Üye';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final colors = context.colors;
    return Scaffold(
      drawer: const SecondaryMenuDrawer(),
      appBar: AppBar(
        title: const Text(
          'PROFİL',
          style: TextStyle(
            color: buikBrand,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: user == null
            ? null
            : [
                FutureBuilder<_ProfileData>(
                  future: _profileFuture,
                  builder: (context, snapshot) {
                    return IconButton(
                      tooltip: 'Profili Düzenle',
                      icon: const Icon(Icons.edit, color: buikBrand),
                      onPressed: snapshot.data == null
                          ? null
                          : () async {
                              final saved = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => EditProfileScreen(
                                    initialData: snapshot.data!.profile,
                                  ),
                                ),
                              );
                              if (saved == true) _refresh();
                            },
                    );
                  },
                ),
              ],
      ),
      body: user == null
          ? _GuestView(
              onLoginPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            )
          : FutureBuilder<_ProfileData>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: buikBrand),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Profil yüklenemedi. Lütfen tekrar deneyin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.muted),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text(
                              'Tekrar Dene',
                              style: TextStyle(color: buikBrand),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final data =
                    snapshot.data ?? const _ProfileData(profile: {}, attendance: []);
                final profile = data.profile;
                final avatarUrl = profile['avatar_url'] as String?;
                final fullName = (profile['full_name'] as String?)?.trim();
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const _ThemeModeSelector(),
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: avatarUrl != null && avatarUrl.isNotEmpty
                            ? () => _openAvatar(avatarUrl)
                            : null,
                        child: Hero(
                          tag: 'profile_avatar',
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: buikBrand.withValues(alpha: 0.2),
                            backgroundImage:
                                avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 44,
                                    color: buikBrand,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    if (fullName != null && fullName.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          fullName,
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _infoRow('E-posta', user.email ?? '-'),
                    _infoRow('Telefon', _orDash(profile['phone'])),
                    _infoRow('Bölüm', _orDash(profile['department'])),
                    if (profile['role'] != 'mezun')
                      _infoRow('Sınıf', _orDash(profile['class_year'])),
                    const SizedBox(height: 8),
                    Text(
                      'Rol',
                      style: TextStyle(color: colors.mutedLight, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _roleLabel(profile['role'] as String?),
                      style: const TextStyle(
                        color: buikBrand,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (profile['role'] == 'board') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buikBrand,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StatisticsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.bar_chart),
                          label: const Text(
                            'İSTATİSTİKLER',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: buikBrand),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EventApplicationsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.inbox_outlined, color: buikBrand),
                          label: const Text(
                            'ETKİNLİK BAŞVURULARI',
                            style: TextStyle(
                              color: buikBrand,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: buikBrand),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RaffleAdminScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.casino_outlined, color: buikBrand),
                          label: const Text(
                            'ÇEKİLİŞ YÖNETİMİ',
                            style: TextStyle(
                              color: buikBrand,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: buikBrand),
                        ),
                        onPressed: _signOut,
                        child: const Text(
                          'ÇIKIŞ YAP',
                          style: TextStyle(
                            color: buikBrand,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: _isDeletingAccount ? null : _deleteAccount,
                        child: _isDeletingAccount
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.redAccent,
                                ),
                              )
                            : const Text(
                                'HESABI SİL',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (profile['role'] == 'member' || profile['role'] == null) ...[
                      const SizedBox(height: 32),
                      Text(
                        'Katıldığım Toplantılar',
                        style: TextStyle(
                          color: colors.ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (data.attendance.isEmpty)
                        Row(
                          children: [
                            Icon(Icons.event_busy_outlined, size: 18, color: colors.faint),
                            const SizedBox(width: 8),
                            Text(
                              'Henüz katıldığınız bir toplantı yok.',
                              style: TextStyle(color: colors.mutedLight, fontSize: 13),
                            ),
                          ],
                        )
                      else
                        ...data.attendance.asMap().entries.map(
                          (e) => BuikFadeIn(
                            delay: Duration(milliseconds: 40 * e.key),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: buikCardDecoration(
                                context,
                                color: colors.brandSoft,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: buikBrand,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      e.value.label,
                                      style: TextStyle(color: colors.ink),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  String _orDash(dynamic value) {
    final text = (value as String?)?.trim();
    return (text == null || text.isEmpty) ? '-' : text;
  }

  Widget _infoRow(String label, String value) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.mutedLight, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: colors.ink, fontSize: 16)),
        ],
      ),
    );
  }
}

class _AvatarViewerScreen extends StatelessWidget {
  const _AvatarViewerScreen({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Hero(
            tag: 'profile_avatar',
            child: InteractiveViewer(
              child: Image.network(avatarUrl),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  static const _options = [
    (mode: ThemeMode.light, icon: Icons.light_mode_outlined, label: 'Açık'),
    (mode: ThemeMode.dark, icon: Icons.dark_mode_outlined, label: 'Koyu'),
    (
      mode: ThemeMode.system,
      icon: Icons.smartphone_outlined,
      label: 'Sistem',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        final current = themeController.themeMode;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.brandSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: _options.map((option) {
              final selected = option.mode == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () => themeController.setThemeMode(option.mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? buikBrand : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          option.icon,
                          size: 20,
                          color: selected ? Colors.white : colors.mutedLight,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected ? Colors.white : colors.mutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _ThemeModeSelector(),
        const SizedBox(height: 24),
        BuikFadeIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_outline, color: colors.mutedLight, size: 40),
              const SizedBox(height: 12),
              Text(
                'Misafir olarak geziniyorsunuz.',
                style: TextStyle(color: colors.muted),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buikBrand,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onLoginPressed,
                  child: const Text(
                    'GİRİŞ YAP',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileData {
  final Map<String, dynamic> profile;
  final List<_AttendanceEntry> attendance;

  const _ProfileData({required this.profile, required this.attendance});
}

class _AttendanceEntry {
  final String label;
  final DateTime checkedInAt;

  const _AttendanceEntry({required this.label, required this.checkedInAt});
}
