import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/committee.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../theme/ui.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Future<String?> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = fetchMyRole();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'YOKLAMA',
          style: TextStyle(
            color: buikBrand,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: FutureBuilder<String?>(
        future: _roleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: buikBrand),
            );
          }
          final role = snapshot.data;
          if (supabase.auth.currentUser == null) {
            return Center(
              child: Text(
                'Yoklama için giriş yapmalısınız.',
                style: TextStyle(color: context.colors.muted),
              ),
            );
          }
          return isCoordinatorRole(role)
              ? const _CoordinatorCodePanel()
              : const _MemberCheckInPanel();
        },
      ),
    );
  }
}

class _CoordinatorCodePanel extends StatefulWidget {
  const _CoordinatorCodePanel();

  @override
  State<_CoordinatorCodePanel> createState() => _CoordinatorCodePanelState();
}

class _CoordinatorCodePanelState extends State<_CoordinatorCodePanel> {
  late Future<List<Committee>> _committeesFuture;
  final _meetingNumberController = TextEditingController();
  Committee? _selectedCommittee;
  String? _generatedCode;
  int? _confirmedMeetingNumber;
  bool _isGenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _committeesFuture = _loadCommittees();
  }

  @override
  void dispose() {
    _meetingNumberController.dispose();
    super.dispose();
  }

  Future<List<Committee>> _loadCommittees() async {
    final rows = await supabase
        .from('committees')
        .select()
        .order('sort_order', ascending: true);
    return rows.map((row) => Committee.fromMap(row)).toList();
  }

  Future<void> _generateCode() async {
    final committee = _selectedCommittee;
    final meetingNumber = int.tryParse(_meetingNumberController.text.trim());
    if (committee == null) {
      setState(() => _error = 'Önce bir alt kurul seçin.');
      return;
    }
    if (meetingNumber == null || meetingNumber <= 0) {
      setState(() => _error = 'Geçerli bir toplantı numarası girin.');
      return;
    }
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final result = await supabase.rpc(
        'start_meeting_and_generate_code',
        params: {
          'p_committee_id': committee.id,
          'p_meeting_number': meetingNumber,
        },
      );
      final row = (result as List).first;
      setState(() {
        _generatedCode = row['out_code'] as String;
        _confirmedMeetingNumber = row['out_meeting_number'] as int;
      });
    } catch (e) {
      setState(() => _error = 'Kod oluşturulamadı. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Committee>>(
      future: _committeesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: buikBrand),
          );
        }
        final colors = context.colors;
        final committees = snapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alt Kurul Seç',
                style: TextStyle(color: colors.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Committee>(
                initialValue: _selectedCommittee,
                dropdownColor: colors.background,
                style: TextStyle(color: colors.ink),
                decoration: _decoration(context, hint: 'Seçiniz'),
                items: committees
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedCommittee = value;
                  _generatedCode = null;
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Kaçıncı Toplantı?',
                style: TextStyle(color: colors.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _meetingNumberController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colors.ink),
                decoration: _decoration(context, hint: 'Örn. 3'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buikBrand,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isGenerating ? null : _generateCode,
                  child: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'YENİ KOD OLUŞTUR',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        key: ValueKey(_error),
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                    ),
                    child: child,
                  ),
                ),
                child: _generatedCode == null
                    ? const SizedBox.shrink()
                    : Padding(
                        key: ValueKey(_generatedCode),
                        padding: const EdgeInsets.only(top: 32),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: buikCardDecoration(
                            context,
                            color: colors.brandSoft,
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${_selectedCommittee?.name} · $_confirmedMeetingNumber. Toplantı',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: colors.muted),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _generatedCode!,
                                style: const TextStyle(
                                  color: buikBrand,
                                  fontSize: 44,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _generatedCode!),
                                  );
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Kod kopyalandı'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: buikBrand,
                                ),
                                label: const Text(
                                  'Kopyala',
                                  style: TextStyle(color: buikBrand),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _decoration(BuildContext context, {String? hint}) {
    final colors = context.colors;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.mutedLight),
      filled: true,
      fillColor: colors.brandSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: buikBrand.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _MemberCheckInPanel extends StatefulWidget {
  const _MemberCheckInPanel();

  @override
  State<_MemberCheckInPanel> createState() => _MemberCheckInPanelState();
}

class _MemberCheckInPanelState extends State<_MemberCheckInPanel> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _message = 'Kod alanı boş olamaz.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _message = null;
    });
    try {
      final result = await supabase.rpc(
        'check_in_with_code',
        params: {'input_code': code},
      );
      final row = (result as List).isNotEmpty ? result.first : null;
      HapticFeedback.mediumImpact();
      setState(() {
        _message = row != null
            ? '"${row['checked_committee_name']}" · ${row['checked_meeting_number']}. Toplantı için yoklamanız alındı.'
            : 'Yoklamanız alındı.';
        _messageIsError = false;
      });
      _codeController.clear();
    } catch (e) {
      HapticFeedback.heavyImpact();
      final isRateLimited = e.toString().contains('too_many_attempts');
      setState(() {
        _message = isRateLimited
            ? 'Çok fazla hatalı deneme yaptınız. Lütfen bir dakika bekleyip tekrar deneyin.'
            : 'Kod geçersiz veya süresi dolmuş.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toplantı Kodu',
            style: TextStyle(color: colors.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: colors.ink,
              fontSize: 24,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.brandSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: buikBrand.withValues(alpha: 0.4)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buikBrand,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSubmitting ? null : _submitCode,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'YOKLAMAYA KATIL',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: _message == null
                ? const SizedBox.shrink()
                : Container(
                    key: ValueKey(_message),
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: buikCardDecoration(
                      context,
                      color: colors.brandSoft,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _messageIsError
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          color: _messageIsError ? Colors.redAccent : buikBrand,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _message!,
                            style: TextStyle(color: colors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
