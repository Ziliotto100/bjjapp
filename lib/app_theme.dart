// lib/app_theme.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'auth_gate.dart'; // Import corrigido

// Constantes de Cor Globais para o App
const Color darkScaffoldBackground = Color(0xFF0A0F14);
const Color darkSurface = Color(0xFF10181F);
const Color primaryAccent = Color(0xFFD4AF37);
const Color primaryAccentForeground = Colors.black;
const Color textPrimary = Colors.white;
const Color textSecondary = Color(0xFFE0E0E0);
const Color textHint = Color(0xFFB0B0B0);
const Color borderNormal = Color(0xFF37474F);
const Color borderFocused = primaryAccent;
const Color successColor = Color(0xFF2ECC71);
const Color warningColor = Color(0xFFFFA726);
const Color errorColor = Color(0xFFE74C3C);
const Color infoColor = Color(0xFF54A0FF);

class BjjApp extends StatelessWidget {
  const BjjApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Match BJJ',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: darkSurface,
          scaffoldBackgroundColor: Colors.transparent,
          // dialogBackgroundColor: darkSurface, // Deprecated
          cardColor: darkSurface.withOpacity(0.85),
          canvasColor: darkScaffoldBackground,
          colorScheme: const ColorScheme.dark(
            primary: primaryAccent,
            secondary: primaryAccent,
            surface: darkSurface,
            // background: darkScaffoldBackground, // Deprecated
            error: errorColor,
            onPrimary: primaryAccentForeground,
            onSecondary: primaryAccentForeground,
            onSurface: textPrimary,
            // onBackground: textPrimary, // Deprecated
            onError: Colors.white,
          ),
          hintColor: textHint,
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
            bodyLarge: TextStyle(color: textSecondary, fontSize: 16),
            bodySmall: TextStyle(color: textSecondary, fontSize: 12),
            headlineSmall: TextStyle(
                color: textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
            titleLarge: TextStyle(
                color: textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
            titleMedium: TextStyle(
                color: textPrimary, fontWeight: FontWeight.w500, fontSize: 18),
            titleSmall: TextStyle(color: textPrimary, fontSize: 16),
            labelLarge: TextStyle(
                color: primaryAccentForeground,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ).apply(fontFamily: 'Roboto'),
          appBarTheme: const AppBarTheme(
            backgroundColor: darkSurface,
            elevation: 2.0,
            titleTextStyle: TextStyle(
                color: textPrimary,
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto'),
            iconTheme: IconThemeData(color: textPrimary),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: darkSurface,
            selectedItemColor: primaryAccent,
            unselectedItemColor: textHint,
            elevation: 4.0,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryAccent,
              foregroundColor: primaryAccentForeground,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              elevation: 2,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: primaryAccent,
            foregroundColor: primaryAccentForeground,
            elevation: 4.0,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: darkSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            titleTextStyle: const TextStyle(
                color: textPrimary,
                fontSize: 19.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto'),
            contentTextStyle: const TextStyle(
                color: textSecondary, fontSize: 15, fontFamily: 'Roboto'),
          ),
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: const TextStyle(color: textHint),
            hintStyle: TextStyle(color: textHint.withOpacity(0.7)),
            filled: true,
            fillColor: darkScaffoldBackground.withOpacity(0.5),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: borderNormal)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: borderNormal)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: borderFocused, width: 2.0)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: errorColor, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: errorColor, width: 2.0)),
            errorStyle:
                const TextStyle(color: errorColor, fontWeight: FontWeight.w500),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: const TextStyle(color: textHint),
              hintStyle: TextStyle(color: textHint.withOpacity(0.7)),
              filled: true,
              fillColor: darkScaffoldBackground.withOpacity(0.5),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: borderNormal)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: borderNormal)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide:
                      const BorderSide(color: borderFocused, width: 2.0)),
            ),
            menuStyle: MenuStyle(
              backgroundColor: const WidgetStatePropertyAll(darkSurface),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0))),
              elevation: const WidgetStatePropertyAll(3.0),
            ),
            textStyle:
                const TextStyle(color: textSecondary, fontFamily: 'Roboto'),
          ),
          popupMenuTheme: PopupMenuThemeData(
            color: darkSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0)),
            textStyle:
                const TextStyle(color: textSecondary, fontFamily: 'Roboto'),
            elevation: 4.0,
          ),
          checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? primaryAccent
                    : textHint.withOpacity(0.2)),
            checkColor: WidgetStateProperty.all(primaryAccentForeground),
            side: WidgetStateBorderSide.resolveWith(
                (states) => BorderSide(color: textHint.withOpacity(0.5))),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0)),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: primaryAccent,
                textStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontFamily: 'Roboto')),
          ),
          cardTheme: CardThemeData(
            color: darkSurface.withOpacity(0.85),
            elevation: 2.0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: SegmentedButton.styleFrom(
              backgroundColor: darkSurface,
              foregroundColor: textSecondary,
              selectedForegroundColor: primaryAccentForeground,
              selectedBackgroundColor: primaryAccent,
            ),
          )),
      home: const AuthGate(),
    );
  }
}
