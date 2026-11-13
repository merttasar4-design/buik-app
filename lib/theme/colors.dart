import 'package:flutter/material.dart';

import '../config/brand.dart';

/// Brand accent — stays constant across light/dark, so it can still be used
/// directly as a top-level const wherever it appears (buttons, icons, links).
const Color buikBrand = Brand.primary;
const Color buikBrandLight = Brand.primaryLight;

/// Theme-dependent surface/text colors. Access via `context.colors` — do not
/// reference [light]/[dark] directly outside this file or MaterialApp setup.
@immutable
class BuikColors extends ThemeExtension<BuikColors> {
  final Color background;
  final Color brandSoft;
  final Color ink;
  final Color muted;
  final Color mutedLight;
  final Color faint;

  const BuikColors({
    required this.background,
    required this.brandSoft,
    required this.ink,
    required this.muted,
    required this.mutedLight,
    required this.faint,
  });

  static const light = BuikColors(
    background: Color(0xFFFFFFFF),
    brandSoft: Brand.lightBrandSoft,
    ink: Color(0xFF0F172A),
    muted: Color(0xFF64748B),
    mutedLight: Color(0xFF94A3B8),
    faint: Color(0xFFCBD5E1),
  );

  static const dark = BuikColors(
    background: Color(0xFF000000),
    brandSoft: Brand.darkBrandSoft,
    ink: Color(0xFFF1F5F9),
    muted: Color(0xFF94A3B8),
    mutedLight: Color(0xFF6B7280),
    faint: Color(0xFF334155),
  );

  @override
  BuikColors copyWith({
    Color? background,
    Color? brandSoft,
    Color? ink,
    Color? muted,
    Color? mutedLight,
    Color? faint,
  }) {
    return BuikColors(
      background: background ?? this.background,
      brandSoft: brandSoft ?? this.brandSoft,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      mutedLight: mutedLight ?? this.mutedLight,
      faint: faint ?? this.faint,
    );
  }

  @override
  BuikColors lerp(ThemeExtension<BuikColors>? other, double t) {
    if (other is! BuikColors) return this;
    return BuikColors(
      background: Color.lerp(background, other.background, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedLight: Color.lerp(mutedLight, other.mutedLight, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
    );
  }
}

extension BuikColorsContext on BuildContext {
  /// Falls back to the light palette if no BuikColors extension is present
  /// (e.g. a widget test that pumps a bare MaterialApp without our theme).
  BuikColors get colors =>
      Theme.of(this).extension<BuikColors>() ?? BuikColors.light;
}
