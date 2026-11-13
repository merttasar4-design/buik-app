import 'package:flutter/material.dart';

import '../config/brand.dart';
import '../config/orientation_config.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'mezun_shell.dart';
import 'orientation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
  );
  late final Animation<double> _logoScale = Tween<double>(begin: 0.86, end: 1.0)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
        ),
      );
  late final Animation<double> _taglineFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
  );
  late final Animation<Offset> _taglineSlide =
      Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
        ),
      );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1800), () async {
      final isLoggedIn = supabase.auth.currentSession != null;
      String? role;
      if (isLoggedIn) {
        try {
          role = await fetchMyRole();
        } catch (_) {
          role = null;
        }
      }
      if (!mounted) return;
      final Widget destination = !isLoggedIn
          ? const LoginScreen()
          : isMezunRole(role)
          ? const MezunShell()
          : const MainShell();
      final Widget nextScreen = isOrientationActive
          ? OrientationScreen(nextScreen: destination)
          : destination;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, _) => nextScreen,
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: const Alignment(0, -0.3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Image.asset(
                    Brand.logoAsset,
                    width: 168,
                    height: 168,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SlideTransition(
                position: _taglineSlide,
                child: FadeTransition(
                  opacity: _taglineFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: const Offset(0.25, 0),
                          child: Text(
                            Brand.fullName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.colors.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (Brand.slogan.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Transform.translate(
                              offset: const Offset(1.5, 0),
                              child: const Text(
                                Brand.slogan,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: buikBrand,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
