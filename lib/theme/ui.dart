import 'package:flutter/material.dart';

import 'colors.dart';

/// Shared card decoration used across list screens for a consistent,
/// polished look (soft shadow instead of hard border, rounded corners).
BoxDecoration buikCardDecoration(BuildContext context, {Color? color}) {
  return BoxDecoration(
    color: color ?? context.colors.brandSoft,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

/// Fades + slides a child up on first build. Wrap list items with an
/// index-based [delay] to get a subtle staggered entrance.
class BuikFadeIn extends StatefulWidget {
  const BuikFadeIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<BuikFadeIn> createState() => _BuikFadeInState();
}

class _BuikFadeInState extends State<BuikFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - _controller.value)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Consistent empty-state layout: icon + message, replacing bare
/// centered text across list screens.
class BuikEmptyState extends StatelessWidget {
  const BuikEmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 40, color: colors.faint),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.mutedLight, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
