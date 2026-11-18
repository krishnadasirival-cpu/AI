import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/m3_expressive_ui/main_pool_screen.dart';
import 'features/m3_expressive_ui/theme.dart';
import 'features/native_onboarding/onboarding_constants.dart';
import 'features/native_onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isOnboarded = prefs.getBool(OnboardingKeys.keyOnboardingCompleted) ?? false;

  runApp(
    ProviderScope(
      child: P2PFilePoolApp(initialOnboarded: isOnboarded),
    ),
  );
}

class P2PFilePoolApp extends StatefulWidget {
  final bool initialOnboarded;

  const P2PFilePoolApp({super.key, required this.initialOnboarded});

  @override
  State<P2PFilePoolApp> createState() => _P2PFilePoolAppState();
}

class _P2PFilePoolAppState extends State<P2PFilePoolApp> {
  late bool _isOnboarded;

  @override
  void initState() {
    super.initState();
    _isOnboarded = widget.initialOnboarded;
  }

  void _onSetupCompleted() {
    setState(() {
      _isOnboarded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'P2P File Pool',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          darkTheme: ExpressiveTheme.darkTheme(darkDynamic),
          theme: ExpressiveTheme.darkTheme(darkDynamic),
          home: _isOnboarded
              ? const MainPoolScreen()
              : OnboardingScreen(onSetupCompleted: _onSetupCompleted),
        );
      },
    );
  }
}
