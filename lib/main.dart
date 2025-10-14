import 'package:RoyalClinic/dokter/Pemeriksaan.dart';
import 'package:RoyalClinic/screen/register.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:RoyalClinic/screen/login.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Royal Clinic',
      theme: ThemeData(
        fontFamily: 'PlusJakartaSans', // ✅ Semua teks pakai Plus Jakarta Sans
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,

        // ✅ Kamu juga bisa atur gaya default TextTheme-nya di sini
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ✅ Locale Indonesia
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('id', 'ID'),
      ],

      home: const LoginPage(),
    );
  }
}
