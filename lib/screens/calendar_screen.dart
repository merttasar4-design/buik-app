import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/event_item.dart';
import '../services/supabase_service.dart';
import '../config/brand.dart';
import '../theme/colors.dart';
import '../theme/ui.dart';
import '../widgets/secondary_menu_drawer.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<List<EventItem>> _eventsFuture;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _canCreate = false;
  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _loadEvents();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await fetchMyRole();
    if (mounted) {
      setState(() {
        _canCreate = isCoordinatorRole(role);
        _canManage = isBoardRole(role);
      });
    }
  }

  Future<List<EventItem>> _loadEvents() async {
    final rows = await supabase.from('events').select();
    return rows.map((row) => EventItem.fromMap(row)).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _eventsFuture = _loadEvents();
    });
    await _eventsFuture;
  }

  List<EventItem> _eventsOn(List<EventItem> all, DateTime day) {
    return all.where((e) => e.occursOn(day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const SecondaryMenuDrawer(),
      appBar: AppBar(
        title: const Text(
          'TAKVİM',
          style: TextStyle(
            color: buikBrand,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              heroTag: 'calendarAdd',
              tooltip: 'Yeni Etkinlik',
              backgroundColor: buikBrand,
              foregroundColor: Colors.white,
              onPressed: () async {
                final saved = await _openEventDialog(context);
                if (saved) _refresh();
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: FutureBuilder<List<EventItem>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: buikBrand),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Etkinlikler yüklenemedi. Lütfen tekrar deneyin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.muted),
              ),
            );
          }
          final events = snapshot.data ?? [];
          final dayEvents = _eventsOn(events, _selectedDay);
          final colors = context.colors;
          return Column(
            children: [
              TableCalendar<EventItem>(
                firstDay: DateTime(2025, 1, 1),
                lastDay: DateTime(2027, 12, 31),
                focusedDay: _focusedDay,
                locale: 'tr_TR',
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                eventLoader: (day) => _eventsOn(events, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleTextStyle: TextStyle(color: colors.ink, fontSize: 16),
                  leftChevronIcon: const Icon(
                    Icons.chevron_left,
                    color: buikBrand,
                  ),
                  rightChevronIcon: const Icon(
                    Icons.chevron_right,
                    color: buikBrand,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: colors.muted),
                  weekendStyle: TextStyle(color: colors.muted),
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: TextStyle(color: colors.ink),
                  weekendTextStyle: TextStyle(color: colors.ink),
                  outsideTextStyle: TextStyle(color: colors.faint),
                  todayDecoration: BoxDecoration(
                    color: buikBrand.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: buikBrand,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(color: Colors.white),
                  markerDecoration: const BoxDecoration(
                    color: buikBrand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Divider(color: colors.faint, height: 1),
              Expanded(
                child: RefreshIndicator(
                  color: buikBrand,
                  onRefresh: _refresh,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: dayEvents.isEmpty
                        ? BuikEmptyState(
                            key: ValueKey(
                              'empty_${_selectedDay.toIso8601String()}',
                            ),
                            icon: Icons.event_busy_outlined,
                            message: 'Bu gün için etkinlik yok.',
                          )
                        : ListView.separated(
                            key: ValueKey(
                              'list_${_selectedDay.toIso8601String()}',
                            ),
                            padding: const EdgeInsets.all(16),
                            itemCount: dayEvents.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) => BuikFadeIn(
                              delay: Duration(milliseconds: 40 * index),
                              child: _DayEventCard(
                                item: dayEvents[index],
                                canManage: _canManage,
                                onChanged: _refresh,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayEventCard extends StatelessWidget {
  const _DayEventCard({
    required this.item,
    required this.canManage,
    required this.onChanged,
  });

  final EventItem item;
  final bool canManage;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showEventDetail(
        context,
        item,
        canManage: canManage,
        onChanged: onChanged,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: buikCardDecoration(
          context,
          color: context.colors.brandSoft,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: buikBrand.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: buikBrand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category.toUpperCase(),
                    style: const TextStyle(
                      color: buikBrand,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: TextStyle(
                      color: context.colors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.mutedLight),
          ],
        ),
      ),
    );
  }
}

void _showEventDetail(
  BuildContext context,
  EventItem item, {
  required bool canManage,
  required VoidCallback onChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _EventDetailSheet(
      item: item,
      canManage: canManage,
      onChanged: onChanged,
    ),
  );
}

Future<bool> _deleteEventAndReport(BuildContext context, EventItem item) async {
  final colors = context.colors;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: colors.background,
      title: Text('Etkinliği Sil', style: TextStyle(color: colors.ink)),
      content: Text(
        '"${item.title}" silinsin mi?',
        style: TextStyle(color: colors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('Vazgeç', style: TextStyle(color: colors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    await supabase.from('events').delete().eq('id', item.id);
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Silinemedi. Lütfen tekrar deneyin.')));
    return false;
  }
}

Future<bool> _openEventDialog(
  BuildContext context, {
  EventItem? existing,
}) async {
  final titleController = TextEditingController(text: existing?.title);
  final categoryController = TextEditingController(text: existing?.category);
  String iconName = existing?.iconName ?? eventIconsByName.keys.first;
  DateTime startDate = existing?.startDate ?? DateTime.now();
  DateTime? endDate = existing?.endDate;
  bool isSubmitting = false;
  String? errorText;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      InputDecoration decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.muted),
        filled: true,
        fillColor: colors.brandSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: buikBrand.withValues(alpha: 0.4)),
        ),
      );
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> pickDate({required bool isStart}) async {
            final picked = await showDatePicker(
              context: dialogContext,
              initialDate: isStart ? startDate : (endDate ?? startDate),
              firstDate: DateTime(2020, 1, 1),
              lastDate: DateTime(2035, 12, 31),
            );
            if (picked == null) return;
            setDialogState(() {
              if (isStart) {
                startDate = picked;
                if (endDate != null && endDate!.isBefore(startDate)) {
                  endDate = null;
                }
              } else {
                endDate = picked;
              }
            });
          }

          return AlertDialog(
            backgroundColor: colors.background,
            title: Text(
              existing == null ? 'Yeni Etkinlik' : 'Etkinliği Düzenle',
              style: TextStyle(color: colors.ink),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: colors.ink),
                    decoration: decoration('Başlık'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryController,
                    style: TextStyle(color: colors.ink),
                    decoration: decoration('Kategori'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: iconName,
                    dropdownColor: colors.background,
                    style: TextStyle(color: colors.ink),
                    decoration: decoration('İkon'),
                    items: eventIconsByName.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(e.value, color: buikBrand, size: 18),
                                const SizedBox(width: 8),
                                Text(e.key),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => iconName = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickDate(isStart: true),
                          child: Text(
                            'Başlangıç: ${DateFormat('d MMM y', 'tr_TR').format(startDate)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickDate(isStart: false),
                          child: Text(
                            endDate == null
                                ? 'Bitiş tarihi ekle (opsiyonel)'
                                : 'Bitiş: ${DateFormat('d MMM y', 'tr_TR').format(endDate!)}',
                          ),
                        ),
                      ),
                      if (endDate != null)
                        IconButton(
                          tooltip: 'Bitiş tarihini kaldır',
                          icon: Icon(Icons.close, color: colors.mutedLight),
                          onPressed: () => setDialogState(() => endDate = null),
                        ),
                    ],
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: Text('Vazgeç', style: TextStyle(color: colors.muted)),
              ),
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        final category = categoryController.text.trim();
                        if (title.isEmpty || category.isEmpty) {
                          setDialogState(
                            () => errorText = 'Başlık ve kategori zorunludur.',
                          );
                          return;
                        }
                        setDialogState(() {
                          errorText = null;
                          isSubmitting = true;
                        });
                        final dateLabel = endDate == null
                            ? DateFormat('d MMMM y', 'tr_TR').format(startDate)
                            : '${DateFormat('d MMMM', 'tr_TR').format(startDate)} - '
                                  '${DateFormat('d MMMM y', 'tr_TR').format(endDate!)}';
                        final payload = {
                          'title': title,
                          'category': category,
                          'icon': iconName,
                          'date_label': dateLabel,
                          'start_date': DateFormat('yyyy-MM-dd').format(startDate),
                          'end_date': endDate == null
                              ? null
                              : DateFormat('yyyy-MM-dd').format(endDate!),
                        };
                        try {
                          if (existing == null) {
                            await supabase.from('events').insert(payload);
                          } else {
                            await supabase
                                .from('events')
                                .update(payload)
                                .eq('id', existing.id);
                          }
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop(true);
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            isSubmitting = false;
                            errorText = 'Kaydedilemedi. Lütfen tekrar deneyin.';
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: buikBrand,
                        ),
                      )
                    : Text(
                        existing == null ? 'Oluştur' : 'Kaydet',
                        style: const TextStyle(color: buikBrand),
                      ),
              ),
            ],
          );
        },
      );
    },
  );

  return saved == true;
}

class _EventDetailSheet extends StatefulWidget {
  const _EventDetailSheet({
    required this.item,
    required this.canManage,
    required this.onChanged,
  });

  final EventItem item;
  final bool canManage;
  final VoidCallback onChanged;

  @override
  State<_EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends State<_EventDetailSheet> {
  final _guestNameController = TextEditingController();
  final _guestEmailController = TextEditingController();
  final _guestPhoneController = TextEditingController();
  bool _isSubmitting = false;
  String? _resultMessage;
  bool _resultIsError = false;

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestEmailController.dispose();
    _guestPhoneController.dispose();
    super.dispose();
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _apply() async {
    final user = supabase.auth.currentUser;
    final isGuest = user == null;

    if (isGuest) {
      if (_guestNameController.text.trim().isEmpty ||
          _guestEmailController.text.trim().isEmpty ||
          _guestPhoneController.text.trim().isEmpty) {
        setState(() {
          _resultMessage = 'Ad Soyad, e-posta ve telefon zorunludur.';
          _resultIsError = true;
        });
        return;
      }
      if (!_emailPattern.hasMatch(_guestEmailController.text.trim())) {
        setState(() {
          _resultMessage = 'Geçerli bir e-posta girin.';
          _resultIsError = true;
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _resultMessage = null;
      _resultIsError = false;
    });
    try {
      await supabase.from('event_applications').insert({
        'event_id': widget.item.id,
        if (isGuest) ...{
          'guest_name': _guestNameController.text.trim(),
          'guest_email': _guestEmailController.text.trim(),
          'guest_phone': _guestPhoneController.text.trim(),
        } else
          'user_id': user.id,
      });
      HapticFeedback.mediumImpact();
      setState(() => _resultMessage = 'Başvurunuz alındı.');
    } catch (e) {
      HapticFeedback.heavyImpact();
      final message = e.toString().contains('duplicate')
          ? 'Bu etkinliğe zaten başvurdunuz.'
          : 'Başvuru gönderilemedi. Lütfen tekrar deneyin.';
      setState(() {
        _resultMessage = message;
        _resultIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colors = context.colors;
    final isGuest = supabase.auth.currentUser == null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        32 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(item.icon, color: buikBrand, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: context.colors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.canManage) ...[
                  IconButton(
                    tooltip: 'Düzenle',
                    icon: Icon(
                      Icons.edit_outlined,
                      color: colors.mutedLight,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final onChanged = widget.onChanged;
                      final saved = await _openEventDialog(
                        context,
                        existing: item,
                      );
                      if (!saved) return;
                      navigator.pop();
                      onChanged();
                    },
                  ),
                  IconButton(
                    tooltip: 'Sil',
                    icon: Icon(
                      Icons.delete_outline,
                      color: colors.mutedLight,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final onChanged = widget.onChanged;
                      final deleted = await _deleteEventAndReport(context, item);
                      if (deleted) {
                        navigator.pop();
                        onChanged();
                      }
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${item.category} · ${item.dateLabel}',
              style: TextStyle(color: context.colors.muted),
            ),
            if (isGuest) ...[
              const SizedBox(height: 20),
              Text(
                '${Brand.university} öğrencisi değil misiniz? Aşağıdaki bilgilerle de başvurabilirsiniz.',
                style: TextStyle(color: colors.mutedLight, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _guestNameController,
                style: TextStyle(color: colors.ink),
                decoration: _guestFieldDecoration(colors, 'Ad Soyad'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _guestEmailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: colors.ink),
                decoration: _guestFieldDecoration(colors, 'E-posta'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _guestPhoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: colors.ink),
                decoration: _guestFieldDecoration(colors, 'Telefon'),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buikBrand,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSubmitting ? null : _apply,
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
                        'BAŞVUR',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _resultMessage!,
                style: TextStyle(
                  color: _resultIsError ? Colors.redAccent : buikBrand,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _guestFieldDecoration(BuikColors colors, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.muted),
      filled: true,
      fillColor: colors.brandSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: buikBrand.withValues(alpha: 0.4)),
      ),
    );
  }
}
