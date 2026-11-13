import 'package:flutter/material.dart';

const Map<String, IconData> eventIconsByName = {
  'campaign': Icons.campaign,
  'account_balance': Icons.account_balance,
  'ondemand_video': Icons.ondemand_video,
  'rocket_launch': Icons.rocket_launch,
  'groups': Icons.groups,
  'emoji_events': Icons.emoji_events,
  'school': Icons.school,
  'trending_up': Icons.trending_up,
  'work': Icons.work,
  'lightbulb': Icons.lightbulb,
  'stars': Icons.stars,
  'theaters': Icons.theaters,
  'language': Icons.language,
};

class EventItem {
  final int id;
  final String title;
  final String dateLabel;
  final String category;
  final String iconName;
  final IconData icon;
  final DateTime? startDate;
  final DateTime? endDate;

  const EventItem({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.category,
    required this.iconName,
    required this.icon,
    this.startDate,
    this.endDate,
  });

  bool occursOn(DateTime day) {
    if (startDate == null) return false;
    final end = endDate ?? startDate!;
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(startDate!) && !d.isAfter(end);
  }

  factory EventItem.fromMap(Map<String, dynamic> map) {
    final iconName = map['icon'] as String? ?? 'event';
    return EventItem(
      id: map['id'] as int,
      title: map['title'] as String,
      dateLabel: map['date_label'] as String,
      category: map['category'] as String,
      iconName: iconName,
      icon: eventIconsByName[iconName] ?? Icons.event,
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'] as String)
          : null,
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
    );
  }
}
