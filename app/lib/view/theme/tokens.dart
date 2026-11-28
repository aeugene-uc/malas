import 'dart:math' as math;

import 'package:flutter/material.dart';

/// DESIGN.md §1.1, Terong mode. The only place colours are written.
abstract final class MalasColors {
  static const bgGround = Color(0xFFFFFFFF);
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgSecondary = Color(0xFFECEEF4);
  static const bgSecondaryPressed = Color(0xFFD9DCE6);
  static const bgBrand = Color(0xFF6A4DE8);
  static const bgBrandPressed = Color(0xFF5A3CD6);
  static const bgBrandSoft = Color(0xFFF3F0FE);
  static const bgSelected = Color(0xFFE6DFFD);
  static const bgOnBrandAction = Color(0xFFFFFFFF);
  static const bgMasukSoft = Color(0xFFE4F5EB);
  static const bgErrorSoft = Color(0xFFFDECEA);
  static const bgHighlight = Color(0xFFFFF3C4);
  static const bgInk = Color(0xFF1B1F3B);
  static const bgSkeleton = Color(0xFFECEEF4);

  static const textPrimary = Color(0xFF1B1F3B);
  static const textSecondary = Color(0xFF4A5072);
  static const textMeta = Color(0xFF646A88);
  static const textDisabled = Color(0xFF9095AD);
  static const textOnBrand = Color(0xFFFFFFFF);
  static const textOnBrandSecondary = Color(0xFFF3F0FE);
  static const textOnBrandAction = Color(0xFF4A2EB8);
  static const textBrandDark = Color(0xFF4A2EB8);
  static const textMasuk = Color(0xFF0B7A45);
  static const textError = Color(0xFFC42B1C);
  static const textOnInk = Color(0xFFFFFFFF);

  static const iconBrand = Color(0xFF5A3CD6);
  static const iconOnInk = Color(0xFFFFFFFF);

  static const borderCard = Color(0xFFD9DCE6);
  static const borderLip = Color(0xFF33207F);
  static const borderLipSekunder = Color(0xFFC3C7D6);
  static const borderAttention = Color(0xFFFFDC6B);
  static const borderAttentionLip = Color(0xFFF0A800);

  static const decoTerang = Color(0xFFB6A5F7);
  static const decoGelap1 = Color(0xFF5A3CD6);
  static const decoGelap2 = Color(0xFF4A2EB8);

  static const jeruk = Color(0xFFD9660A);
  static const jerukLip = Color(0xFFA84D04);
  static const masuk = Color(0xFF18A15F);

  /// §4.2: the one colour with alpha.
  static const scrim = Color(0x80120D33);
}

/// §1.1 category tones: base fills the tile, lip sits under it, soft fills
/// sheet bands.
enum CategoryTone {
  minuman(Color(0xFF3B6FD6), Color(0xFF2A52A8), Color(0xFFE4EBF9)),
  merah(Color(0xFFE0485A), Color(0xFFB02A3B), Color(0xFFFBE5E8)),
  bahan(Color(0xFF2A9D8F), Color(0xFF1D756A), Color(0xFFE1F1EF)),
  penjualan(Color(0xFF7A4CC8), Color(0xFF5A33A0), Color(0xFFECE6F7)),
  makanan(Color(0xFFA26A2E), Color(0xFF78491B), Color(0xFFF2EAE2)),
  lainnya(Color(0xFF6F7787), Color(0xFF4E5566), Color(0xFFEBECEE)),
  jeruk(MalasColors.jeruk, MalasColors.jerukLip, Color(0xFFFBEADB));

  const CategoryTone(this.base, this.lip, this.soft);

  final Color base;
  final Color lip;
  final Color soft;
}

/// §1.2. Every style is Plus Jakarta Sans; money styles use tabular figures.
abstract final class MalasText {
  static const family = 'PlusJakartaSans';
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _style(
    double size,
    double line,
    FontWeight weight, {
    double tracking = 0,
    bool isMoney = false,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: line / size,
    fontWeight: weight,
    letterSpacing: size * tracking,
    fontFeatures: isMoney ? _tabular : null,
    color: MalasColors.textPrimary,
  );

  static final moneyHero = _style(
    44,
    48,
    FontWeight.w800,
    tracking: -0.015,
    isMoney: true,
  );
  static final moneyLarge = _style(
    28,
    34,
    FontWeight.w700,
    tracking: -0.01,
    isMoney: true,
  );
  static final moneyRow = _style(
    18,
    24,
    FontWeight.w700,
    tracking: -0.005,
    isMoney: true,
  );
  static final rpHero = _style(
    26,
    48,
    FontWeight.w600,
    tracking: -0.005,
    isMoney: true,
  );
  static final rpLarge = _style(17, 34, FontWeight.w600, isMoney: true);
  static final rpRow = _style(14, 24, FontWeight.w500, isMoney: true);
  static final titleScreen = _style(24, 30, FontWeight.w800, tracking: -0.01);
  static final titleSection = _style(20, 26, FontWeight.w800, tracking: -0.005);
  static final titleItem = _style(17, 24, FontWeight.w600);
  static final body = _style(16, 24, FontWeight.w400);
  static final bodyStrong = _style(16, 24, FontWeight.w600);
  static final bodySecondary = _style(
    14,
    20,
    FontWeight.w500,
  ).copyWith(color: MalasColors.textSecondary);
  static final labelButton = _style(16, 20, FontWeight.w800);
  static final labelChip = _style(14, 18, FontWeight.w600);
  static final labelTag = _style(14, 16, FontWeight.w600);
  static final labelNav = _style(14, 16, FontWeight.w600);
  static final transcript = _style(22, 30, FontWeight.w500, tracking: -0.005);
}

/// §1.3 space scale, radius and sizes.
abstract final class MalasSpace {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
  static const s56 = 56.0;

  /// Left and right padding of every screen.
  static const screen = 20.0;
}

abstract final class MalasRadius {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const chip = 12.0;
  static const shortcut = 18.0;
  static const largeTile = 22.0;
}

abstract final class MalasSize {
  static const touch = 48.0;
  static const buttonBesar = 56.0;
  static const buttonKecil = 44.0;
  static const row = 72.0;
  static const categoryTile = 40.0;
  static const navBar = 76.0;
  static const navMic = 64.0;

  /// How far the curve around the mic rises above the nav bar, so a bar
  /// fixed at the bottom of a tab can keep clear of it.
  static const navBumpRise = 26.0;
  static const lip = 4.0;
  static const cardStroke = 2.0;
  static const headerHeight = 262.0;

  /// The widest a column of text and cards grows on a tablet.
  static const readingColumn = 640.0;
}

/// Side padding for content [width] wide: the usual 20 on a phone, wider on
/// a tablet so text and cards stay in a column one can read across.
double sidePaddingFor(double width) =>
    math.max(MalasSpace.screen, (width - MalasSize.readingColumn) / 2);
