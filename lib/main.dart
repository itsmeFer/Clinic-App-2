import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Services
import 'package:RoyalClinic/services/local_notification_service.dart';
import 'package:RoyalClinic/services/splash_gate.dart'; // ⬅️ penting: gate cek token

// Screens
import 'package:RoyalClinic/screen/login.dart';
import 'package:RoyalClinic/screen/register.dart';

// Dokter pages
import 'package:RoyalClinic/dokter/dashboard.dart';
// (opsional) import lain kalau memang dipakai di routes:
// import 'package:RoyalClinic/dokter/RiwayatPasien.dart';
// import 'package:RoyalClinic/dokter/EditProfilDokter.dart';
// import 'package:RoyalClinic/dokter/Sidebar.dart' as Sidebar;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone init
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  // Notif permission (Android 13+)
  await _requestNotificationPermissions();

  // Local notifications init
  await LocalNotificationService().initialize();

  runApp(const MyApp());
}

Future<void> _requestNotificationPermissions() async {
  await Permission.notification.request();
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Royal Clinic',
      theme: ThemeData(
        fontFamily: 'PlusJakartaSans',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('id', 'ID'),
      ],

      // ✅ Routes yang dipakai untuk named navigation
      routes: {
        '/login'    : (context) => const LoginPage(),
        '/register' : (context) => const RegisterPage(),
        '/dashboard': (context) => const DokterDashboard(),
      },

      // ✅ START di SplashGate (bukan initialRoute '/')
      // SplashGate akan cek token -> valid? push ke /dashboard, kalau tidak -> /login
      home: const SplashGate(),

      // ✅ Fallback kalau ada unknown route
      onUnknownRoute: (_) => MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }
}
