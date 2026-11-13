import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/committee.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';

const _raffleJoinedPrefKey = 'orientation_raffle_joined';

const List<IconData> _committeeIcons = [
  Icons.business_center_rounded,
  Icons.trending_up_rounded,
  Icons.campaign_rounded,
  Icons.brush_rounded,
  Icons.dynamic_feed_rounded,
  Icons.auto_awesome_rounded,
];

class OrientationScreen extends StatefulWidget {
  const OrientationScreen({super.key, required this.nextScreen});

  /// Uygulama açılışında bir kere gösterilir; "Devam Et" / "Atla" bu ekrana
  /// gider (normalde splash'ın yönlendireceği Login/MainShell/MezunShell).
  final Widget nextScreen;

  @override
  State<OrientationScreen> createState() => _OrientationScreenState();
}

class _OrientationScreenState extends State<OrientationScreen> {
  late Future<List<Committee>> _committeesFuture;
  RealtimeChannel? _winnerChannel;

  bool _hasJoined = false;
  bool _isSubmitting = false;
  bool _isLoadingJoinFlag = true;
  String? _bannerWinner;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _committeesFuture = _loadCommittees();
    _loadWinnerAndJoinFlag();
    _subscribeToWinners();
  }

  @override
  void dispose() {
    final channel = _winnerChannel;
    if (channel != null) supabase.removeChannel(channel);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<List<Committee>> _loadCommittees() async {
    final rows = await supabase
        .from('committees')
        .select()
        .order('sort_order', ascending: true);
    return rows.map((r) => Committee.fromMap(r)).toList();
  }

  Future<void> _loadWinnerAndJoinFlag() async {
    final prefs = await SharedPreferences.getInstance();
    String? winnerName;
    try {
      final row = await supabase
          .from('raffle_winners')
          .select('winner_name')
          .order('drawn_at', ascending: false)
          .limit(1)
          .maybeSingle();
      winnerName = row?['winner_name'] as String?;
    } catch (_) {
      winnerName = null;
    }
    if (mounted) {
      setState(() {
        _bannerWinner = winnerName;
        _hasJoined = prefs.getBool(_raffleJoinedPrefKey) ?? false;
        _isLoadingJoinFlag = false;
      });
    }
  }

  void _subscribeToWinners() {
    _winnerChannel = supabase
        .channel('orientation_raffle_winners')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'raffle_winners',
          callback: (payload) {
            final name = payload.newRecord['winner_name'] as String?;
            if (name == null || !mounted) return;
            setState(() => _bannerWinner = name);
          },
        )
        .subscribe();
  }

  Future<void> _openWhatsapp(String? link) async {
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _joinRaffle() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.length < 10) {
      _showMessage('Lütfen ad soyad ve geçerli bir telefon numarası gir.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await supabase.from('raffle_entries').insert({
        'full_name': name,
        'phone': phone,
        'user_id': supabase.auth.currentUser?.id,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_raffleJoinedPrefKey, true);
      if (!mounted) return;
      setState(() => _hasJoined = true);
      _showMessage('Çekilişe katıldın, bol şans! 🎉');
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_raffleJoinedPrefKey, true);
        if (mounted) setState(() => _hasJoined = true);
        _showMessage('Bu telefon numarasıyla zaten katıldın.');
      } else {
        _showMessage('Bir hata oluştu, tekrar dene.');
      }
    } catch (_) {
      _showMessage('Bir hata oluştu, tekrar dene.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _continue() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => widget.nextScreen));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            children: [
              _TopBar(onSkip: _continue),
              const SizedBox(height: 10),
              if (_bannerWinner != null) ...[
                _WinnerBanner(name: _bannerWinner!),
                const SizedBox(height: 10),
              ],
              Expanded(
                flex: 3,
                child: FutureBuilder<List<Committee>>(
                  future: _committeesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(color: buikBrand),
                      );
                    }
                    final committees = snapshot.data ?? [];
                    return _CommitteeGrid(
                      committees: committees,
                      onJoin: _openWhatsapp,
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                flex: 4,
                child: _isLoadingJoinFlag
                    ? const SizedBox.shrink()
                    : _RaffleCard(
                        hasJoined: _hasJoined,
                        isSubmitting: _isSubmitting,
                        nameController: _nameController,
                        phoneController: _phoneController,
                        onSubmit: _joinRaffle,
                        onContinue: _continue,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Oryantasyona Hoş Geldin! 🎉',
            style: TextStyle(
              color: colors.ink,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: onSkip,
          child: const Text(
            'Atla ›',
            style: TextStyle(color: buikBrand, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5B921), width: 1.2),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Çekiliş kazananı: $name',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF3D2900),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommitteeGrid extends StatelessWidget {
  const _CommitteeGrid({required this.committees, required this.onJoin});

  final List<Committee> committees;
  final void Function(String? link) onJoin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ALT KURULUNU SEÇ · WHATSAPP GRUBUNA KATIL',
          style: TextStyle(
            color: colors.mutedLight,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.4,
            ),
            itemCount: committees.length,
            itemBuilder: (context, index) {
              final committee = committees[index];
              return _CommitteeCell(
                committee: committee,
                icon: _committeeIcons[index % _committeeIcons.length],
                onTap: () => onJoin(committee.whatsappLink),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CommitteeCell extends StatelessWidget {
  const _CommitteeCell({
    required this.committee,
    required this.icon,
    required this.onTap,
  });

  final Committee committee;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasLink =
        committee.whatsappLink != null && committee.whatsappLink!.isNotEmpty;
    return Material(
      color: colors.brandSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: hasLink ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Stack(
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: buikBrand.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: buikBrand, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      committee.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasLink
                            ? colors.ink
                            : colors.ink.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasLink)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF25D366),
                    size: 15,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaffleCard extends StatelessWidget {
  const _RaffleCard({
    required this.hasJoined,
    required this.isSubmitting,
    required this.nameController,
    required this.phoneController,
    required this.onSubmit,
    required this.onContinue,
  });

  final bool hasJoined;
  final bool isSubmitting;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final VoidCallback onSubmit;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [buikBrand.withValues(alpha: 0.12), colors.brandSoft],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: buikBrand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Özel Çekilişe Katıl',
                  style: TextStyle(
                    color: colors.ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasJoined) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Katıldın, bol şans!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: colors.ink),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: colors.background,
                labelText: 'Ad Soyad',
                labelStyle: TextStyle(color: colors.muted),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: colors.ink),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: colors.background,
                labelText: 'Telefon',
                labelStyle: TextStyle(color: colors.muted),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buikBrand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSubmitting ? null : onSubmit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'ÇEKİLİŞE KATIL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: buikBrand),
              ),
              onPressed: onContinue,
              child: const Text(
                'UYGULAMAYA DEVAM ET',
                style: TextStyle(color: buikBrand, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
