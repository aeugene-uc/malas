import 'package:flutter/material.dart';

import 'tokens.dart';

/// Maps the tokens onto Material, so plain Material widgets (fields, sheets,
/// snackbars, pickers) already match. Buttons, chips and tiles use
/// [LipButton] and friends for the lip (DESIGN.md §2).
ThemeData buildMalasTheme() {
  const colorScheme = ColorScheme.light(
    primary: MalasColors.bgBrand,
    onPrimary: MalasColors.textOnBrand,
    primaryContainer: MalasColors.bgSelected,
    onPrimaryContainer: MalasColors.textBrandDark,
    secondary: MalasColors.bgBrandPressed,
    onSecondary: MalasColors.textOnBrand,
    secondaryContainer: MalasColors.bgSelected,
    onSecondaryContainer: MalasColors.textBrandDark,
    surface: MalasColors.bgSurface,
    onSurface: MalasColors.textPrimary,
    onSurfaceVariant: MalasColors.textSecondary,
    surfaceContainerHighest: MalasColors.bgSecondary,
    error: MalasColors.textError,
    errorContainer: MalasColors.bgErrorSoft,
    outline: MalasColors.borderCard,
    outlineVariant: MalasColors.borderCard,
    inverseSurface: MalasColors.bgInk,
    onInverseSurface: MalasColors.textOnInk,
    inversePrimary: MalasColors.decoTerang,
  );
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(MalasRadius.lg),
    side: const BorderSide(
      color: MalasColors.borderCard,
      width: MalasSize.cardStroke,
    ),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(MalasRadius.md),
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(MalasRadius.md),
    borderSide: const BorderSide(
      color: MalasColors.borderCard,
      width: MalasSize.cardStroke,
    ),
  );
  return ThemeData(
    colorScheme: colorScheme,
    fontFamily: MalasText.family,
    scaffoldBackgroundColor: MalasColors.bgGround,
    textTheme: TextTheme(
      headlineSmall: MalasText.moneyLarge,
      titleLarge: MalasText.titleScreen,
      titleMedium: MalasText.titleSection,
      titleSmall: MalasText.titleItem,
      bodyLarge: MalasText.body,
      bodyMedium: MalasText.body,
      bodySmall: MalasText.bodySecondary,
      labelLarge: MalasText.labelButton,
      labelMedium: MalasText.labelChip,
      labelSmall: MalasText.labelTag,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: MalasColors.bgBrand,
      foregroundColor: MalasColors.textOnBrand,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: MalasText.titleScreen.copyWith(
        color: MalasColors.textOnBrand,
      ),
    ),
    cardTheme: CardThemeData(
      color: MalasColors.bgSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    dividerTheme: const DividerThemeData(
      color: MalasColors.borderCard,
      thickness: MalasSize.cardStroke,
      space: MalasSize.cardStroke,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, MalasSize.buttonBesar),
        shape: buttonShape,
        textStyle: MalasText.labelButton,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, MalasSize.touch),
        backgroundColor: MalasColors.bgSecondary,
        foregroundColor: MalasColors.textPrimary,
        side: BorderSide.none,
        shape: buttonShape,
        textStyle: MalasText.labelButton,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, MalasSize.touch),
        foregroundColor: MalasColors.textBrandDark,
        textStyle: MalasText.labelButton,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MalasColors.bgSurface,
      labelStyle: MalasText.bodySecondary,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(
          color: MalasColors.bgBrand,
          width: MalasSize.cardStroke,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: MalasColors.bgSecondary,
      selectedColor: MalasColors.bgSelected,
      labelStyle: MalasText.labelChip,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MalasRadius.chip),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MalasColors.bgSurface,
      modalBarrierColor: MalasColors.scrim,
      showDragHandle: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MalasRadius.xl),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: MalasColors.bgSurface,
      barrierColor: MalasColors.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MalasRadius.xl),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: MalasColors.bgInk,
      contentTextStyle: MalasText.body.copyWith(color: MalasColors.textOnInk),
      actionTextColor: MalasColors.decoTerang,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MalasRadius.md),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: MalasSpace.s12,
      titleTextStyle: MalasText.titleItem,
      subtitleTextStyle: MalasText.bodySecondary,
    ),
  );
}
