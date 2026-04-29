import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

// IMPORTANT: Run `flutterfire configure` in your terminal to generate this file automatically
// import 'firebase_options.dart';

void main() async {
  // 1. Ensure Flutter bindings are initialized before calling Firebase Android code
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform, // Uncomment after running flutterfire
  );

  // 3. Start the application
  runApp(const PatwariApp());
}

class PatwariApp extends StatelessWidget {
  const PatwariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'चतुरसीमा (Chaturseema) Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Use a professional, official-looking color seed (e.g., solid blue or green)
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade800),
        useMaterial3: true,
        // Integrate Hindi Font Support Globally
        textTheme: GoogleFonts.notoSansDevanagariTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      
      // Basic Named Routing Structure
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/create-document': (context) => const GenerateChaturseemaScreen(),
      },
    );
  }
}

// ============================================================================
// Placeholder Screens for Routing Structure
// ============================================================================

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('लॉग इन (Login)')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Implement Google Sign-In or Phone OTP here
                Navigator.pushReplacementNamed(context, '/dashboard');
              },
              child: const Text('Google से लॉगिन करें'),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('डैशबोर्ड (Dashboard)')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/create-document'),
          child: const Text('नया चतुरसीमा बनाएं (Generate New)'),
        ),
      ),
    );
  }
}

class GenerateChaturseemaScreen extends StatelessWidget {
  const GenerateChaturseemaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('नया चतुरसीमा (New Chaturseema)')),
      body: const Center(
        child: Text('Add your flutter_typeahead inputs here...'),
      ),
    );
  }
}
