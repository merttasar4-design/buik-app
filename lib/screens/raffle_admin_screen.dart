import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../theme/ui.dart';

class RaffleAdminScreen extends StatefulWidget {
  const RaffleAdminScreen({super.key});

  @override
  State<RaffleAdminScreen> createState() => _RaffleAdminScreenState();
}

class _RaffleAdminScreenState extends State<RaffleAdminScreen> {
  late Future<_RaffleAdminData> _dataFuture;
  bool _isDrawing = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_RaffleAdminData> _load() async {
    final entryCount = await supabase.rpc('raffle_entry_count') as int;
    final winnerRows = await supabase
        .from('raffle_winners')
        .select()
        .order('drawn_at', ascending: false);
    return _RaffleAdminData(
      entryCount: entryCount,
      winnerCount: winnerRows.length,
      winners: List<Map<String, dynamic>>.from(winnerRows),
    );
  }

  Future<void> _refresh() async {
    setState(() => _dataFuture = _load());
    await _dataFuture;
  }

  Future<void> _drawWinner() async {
    setState(() => _isDrawing = true);
    try {
      final result = await supabase.rpc('draw_raffle_winner');
      final row = (result as List).first as Map;
      final name = row['winner_name'] as String;
      await _refresh();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _WinnerDialog(name: name),
      );
    } catch (e) {
      final message = e.toString().contains('no_entries_left')
          ? 'Çekilecek yeni katılımcı kalmadı.'
          : 'Kazanan çekilemedi. Lütfen tekrar deneyin.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isDrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ÇEKİLİŞ YÖNETİMİ',
          style: TextStyle(
            color: buikBrand,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: buikBrand,
        onRefresh: _refresh,
        child: FutureBuilder<_RaffleAdminData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: buikBrand),
              );
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text(
                      'Yüklenemedi. Lütfen tekrar deneyin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.muted),
                    ),
                  ),
                ],
              );
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Katılımcı',
                        value: '${data.entryCount}',
                        icon: Icons.people_alt_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Kazanan',
                        value: '${data.winnerCount}',
                        icon: Icons.emoji_events_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buikBrand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        (_isDrawing || data.entryCount <= data.winnerCount)
                        ? null
                        : _drawWinner,
                    icon: _isDrawing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.casino_rounded),
                    label: Text(
                      _isDrawing ? 'ÇEKİLİYOR...' : 'KAZANAN ÇEK',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Kazanan Geçmişi',
                  style: TextStyle(color: colors.ink, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (data.winners.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 32,
                            color: colors.faint,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Henüz kazanan çekilmedi.',
                            style: TextStyle(
                              color: colors.mutedLight,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: data.winners.map((w) {
                      final drawnAt = DateTime.tryParse(
                        w['drawn_at'] as String? ?? '',
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: buikCardDecoration(context),
                        child: Row(
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                w['winner_name'] as String,
                                style: TextStyle(
                                  color: colors.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (drawnAt != null)
                              Text(
                                DateFormat(
                                  'd MMM, HH:mm',
                                  'tr_TR',
                                ).format(drawnAt.toLocal()),
                                style: TextStyle(
                                  color: colors.mutedLight,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: buikCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: buikBrand, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: colors.ink,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          Text(label, style: TextStyle(color: colors.mutedLight, fontSize: 12)),
        ],
      ),
    );
  }
}

class _WinnerDialog extends StatelessWidget {
  const _WinnerDialog({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: colors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'KAZANAN',
              style: TextStyle(
                color: colors.mutedLight,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: buikBrand,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buikBrand,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('TAMAM'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaffleAdminData {
  final int entryCount;
  final int winnerCount;
  final List<Map<String, dynamic>> winners;

  const _RaffleAdminData({
    required this.entryCount,
    required this.winnerCount,
    required this.winners,
  });
}
