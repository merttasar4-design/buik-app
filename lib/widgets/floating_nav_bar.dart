import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';

/// Alt sekme barındaki tek bir sekmenin tanımı.
class ShellTab {
  const ShellTab({
    required this.screen,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final Widget screen;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Bulanık (blur) arka planlı alt sekme barı. Seçili sekmenin ikonu barın
/// üstüne taşan, parlak bir baloncuk içinde gösterilir ve sekme değişince
/// bu baloncuk yumuşak bir sıçramayla yeni konuma kayar. `MainShell` ve
/// `MezunShell` arasında paylaşılır.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<ShellTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _barHeight = 66;
  static const double _bubbleSize = 44;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.background.withValues(alpha: 0.86),
            border: Border(
              top: BorderSide(color: context.colors.faint.withValues(alpha: 0.6)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: _barHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = constraints.maxWidth / tabs.length;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Row(
                          children: List.generate(tabs.length, (index) {
                            return Expanded(
                              child: _NavButton(
                                tab: tabs[index],
                                selected: index == currentIndex,
                                onTap: () => onTap(index),
                              ),
                            );
                          }),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        left: tabWidth * currentIndex,
                        top: 0,
                        width: tabWidth,
                        child: IgnorePointer(
                          child: Center(
                            child: _Bubble(icon: tabs[currentIndex].activeIcon),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Seçili sekmenin barın üstüne taşan parlak ikon baloncuğu.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: FloatingNavBar._bubbleSize,
      height: FloatingNavBar._bubbleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [buikBrandLight, buikBrand],
        ),
        boxShadow: [
          BoxShadow(
            color: buikBrand.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.tab, required this.selected, required this.onTap});

  final ShellTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? buikBrand : context.colors.mutedLight;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!selected) HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Seçiliyken ikon baloncukta gösterildiği için burada sadece
          // yer kaplayıp görünmez oluyor — sekmeler arası zıplama olmasın diye.
          AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: selected ? 0 : 1,
            child: Icon(tab.icon, color: color, size: 22),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
            child: Text(tab.label),
          ),
        ],
      ),
    );
  }
}
