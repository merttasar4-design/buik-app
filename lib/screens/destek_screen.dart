import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/supabase_service.dart';
import '../theme/colors.dart';
import 'payment_webview_screen.dart';

class DestekScreen extends StatefulWidget {
  const DestekScreen({super.key});

  @override
  State<DestekScreen> createState() => _DestekScreenState();
}

class _DestekScreenState extends State<DestekScreen> {
  late Future<List<Map<String, dynamic>>> _donationsFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _donationsFuture = _loadDonations();
  }

  Future<List<Map<String, dynamic>>> _loadDonations() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];
    final rows = await supabase
        .from('donations')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    setState(() {
      _donationsFuture = _loadDonations();
    });
    await _donationsFuture;
  }

  Future<void> _startPayment(String type) async {
    final amountController = TextEditingController();
    final identityController = TextEditingController();
    final addressController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          backgroundColor: colors.background,
          title: Text(
            type == 'aidat' ? 'Aidat Öde' : 'Bağış Yap',
            style: TextStyle(color: colors.ink),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: colors.ink),
                  decoration: InputDecoration(
                    labelText: 'Tutar (TL)',
                    labelStyle: TextStyle(color: colors.muted),
                  ),
                ),
                TextField(
                  controller: identityController,
                  keyboardType: TextInputType.number,
                  maxLength: 11,
                  style: TextStyle(color: colors.ink),
                  decoration: InputDecoration(
                    labelText: 'TC Kimlik No',
                    labelStyle: TextStyle(color: colors.muted),
                  ),
                ),
                TextField(
                  controller: addressController,
                  style: TextStyle(color: colors.ink),
                  decoration: InputDecoration(
                    labelText: 'Adres (fatura için)',
                    labelStyle: TextStyle(color: colors.muted),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ödeme iyzico güvenli ödeme sayfası üzerinden alınır, kart bilgileriniz uygulamaya kaydedilmez.',
                  style: TextStyle(color: colors.mutedLight, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Vazgeç', style: TextStyle(color: colors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Devam Et', style: TextStyle(color: buikBrand)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final amount = double.tryParse(
      amountController.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      _showMessage('Geçerli bir tutar girin.');
      return;
    }
    if (identityController.text.trim().length != 11) {
      _showMessage('TC kimlik numarası 11 haneli olmalı.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await supabase.functions.invoke(
        'create-payment',
        body: {
          'amount': amount,
          'type': type,
          'identityNumber': identityController.text.trim(),
          'address': addressController.text.trim(),
        },
      );

      final data = response.data as Map?;
      final paymentPageUrl = data?['paymentPageUrl'] as String?;
      if (paymentPageUrl == null) {
        _showMessage((data?['error'] as String?) ?? 'Ödeme başlatılamadı.');
        return;
      }

      if (!mounted) return;
      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(paymentPageUrl: paymentPageUrl),
        ),
      );

      if (!mounted) return;
      _showMessage(
        success == true
            ? 'Ödeme başarıyla tamamlandı, teşekkür ederiz!'
            : 'Ödeme tamamlanamadı.',
      );
      await _refresh();
    } catch (e) {
      _showMessage('Bir hata oluştu. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'success':
        return 'Tamamlandı';
      case 'failed':
        return 'Başarısız';
      default:
        return 'Beklemede';
    }
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'failed':
        return Colors.redAccent;
      default:
        return context.colors.mutedLight;
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
          'DESTEK',
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
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buikBrand,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSubmitting ? null : () => _startPayment('aidat'),
                      child: const Text(
                        'AİDAT ÖDE',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: buikBrand),
                      ),
                      onPressed: _isSubmitting ? null : () => _startPayment('bagis'),
                      child: const Text(
                        'BAĞIŞ YAP',
                        style: TextStyle(
                          color: buikBrand,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Geçmiş İşlemler',
              style: TextStyle(color: colors.ink, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _donationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: buikBrand),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Geçmiş işlemler yüklenemedi. Lütfen tekrar deneyin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.muted),
                      ),
                    ),
                  );
                }
                final donations = snapshot.data ?? [];
                if (donations.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 32,
                            color: colors.faint,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Henüz bir işlem yapmadınız.',
                            style: TextStyle(color: colors.mutedLight, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: donations.map((d) {
                    final amount = (d['amount'] as num).toDouble();
                    final type = d['type'] == 'aidat' ? 'Aidat' : 'Bağış';
                    final status = d['status'] as String;
                    final createdAt = DateTime.tryParse(
                      d['created_at'] as String? ?? '',
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.brandSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: buikBrand.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$type · ${amount.toStringAsFixed(2)} TL',
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (createdAt != null)
                                  Text(
                                    DateFormat('d MMM y, HH:mm', 'tr_TR')
                                        .format(createdAt.toLocal()),
                                    style: TextStyle(
                                      color: colors.mutedLight,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            _statusLabel(status),
                            style: TextStyle(
                              color: _statusColor(context, status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
