import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/bootstrap/app_bootstrap.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'screens/auth/splash_screen.dart';

void main() async {
  await bootstrapApp();

  runApp(
    ChangeNotifierProvider(
      create: (context) => PigioAppState(),
      child: const PigioApp(),
    ),
  );
}

class PigioApp extends StatelessWidget {
  const PigioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PigioAppState>(
      builder: (context, state, child) {
        final pt = state.currentTheme;

        return MaterialApp(
          title: 'Pigio',
          theme: ThemeData(
            colorScheme: pt.isDark
                ? ColorScheme.dark(
                    primary: pt.primary,
                    surface: pt.card,
                    onSurface: pt.ink,
                  )
                : ColorScheme.light(
                    primary: pt.primary,
                    surface: pt.card,
                    onSurface: pt.ink,
                  ),
            useMaterial3: true,
            scaffoldBackgroundColor: pt.scaffold,
            textTheme: GoogleFonts.nunitoTextTheme().apply(
              bodyColor: pt.ink,
              displayColor: pt.ink,
            ),
            drawerTheme: DrawerThemeData(backgroundColor: pt.navBar),
            dialogTheme: DialogThemeData(backgroundColor: pt.card),
            bottomSheetTheme: BottomSheetThemeData(backgroundColor: pt.sheet),
            dividerTheme: DividerThemeData(color: pt.divider),
          ),
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
