import 'package:flutter/material.dart';

import '../widgets/floating_nav_bar.dart';
import 'announcements_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';

class MezunShell extends StatefulWidget {
  const MezunShell({super.key});

  @override
  State<MezunShell> createState() => _MezunShellState();
}

class _MezunShellState extends State<MezunShell> {
  int _currentIndex = 0;

  // Destek sekmesi iyzico entegrasyonu tamamlanana kadar geçici olarak kaldırıldı.
  static const _tabs = [
    ShellTab(
      screen: CalendarScreen(),
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
      label: 'Takvim',
    ),
    ShellTab(
      screen: AnnouncementsScreen(),
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign,
      label: 'Duyurular',
    ),
    ShellTab(
      screen: ProfileScreen(),
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profil',
    ),
  ];

  void _onTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: FloatingNavBar(
        tabs: _tabs,
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}
