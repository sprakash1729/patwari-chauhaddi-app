import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/patwari_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/history_screen.dart';
import 'screens/create_chaturseema_screen.dart';
import 'screens/profile_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PatwariProvider()),
      ],
      child: const PatwariApp(),
    ),
  );
}

class PatwariApp extends StatelessWidget {
  const PatwariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patwari - Chauhaddi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade800),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansDevanagariTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => AuthScreen(),
        '/history': (context) => HistoryScreen(),
        '/create': (context) => CreateChaturseemaScreen(),
        '/profile-setup': (context) => ProfileSetupScreen(),
      },
    );
  }
}
