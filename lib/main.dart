import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/splash_screen.dart';
import 'services/tts_service.dart';
import 'services/storage_service.dart';
import 'config/theme_config.dart';

// Global notifier for theme
final themeNotifier = ValueNotifier<String>('Teal');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage (Web and Mobile compatible)
  await Hive.initFlutter();
  await Hive.openBox('vocabulary_box');
  await Hive.openBox('api_keys_box');
  await Hive.openBox('settings_box');
  
  // Load saved theme
  final savedTheme = await StorageService().getTheme();
  themeNotifier.value = savedTheme;
  
  // Initialize TTS
  await TtsService().init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: themeNotifier,
      builder: (context, currentThemeName, _) {
        final appTheme = AppTheme.themes.firstWhere(
          (t) => t.name == currentThemeName,
          orElse: () => AppTheme.themes.first,
        );

        return MaterialApp(
          title: 'Word to 5 Sentences',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getThemeData(appTheme),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: appTheme.seedColor,
              brightness: Brightness.dark,
            ),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
          ),
          themeMode: appTheme.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.system,
          home: const SplashScreen(),
        );
      },
    );
  }
}

