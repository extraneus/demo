import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/firebase_service.dart';
import 'services/auth_service.dart';
import 'login_page.dart';
import 'homepage.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use the options when initializing Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print("Firebase initialized successfully");

  final authService = AuthService();
  await authService.initializeUser();
  print("Auth service initialized successfully");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        Provider(create: (_) => FirebaseService()),
      ],
      child: const BanglaLitApp(),
    ),
  );
}

class BanglaLitApp extends StatelessWidget {
  const BanglaLitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BanglaLit',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Hind Siliguri',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Builder(
        builder: (context) {
          try {
            // Add error handling here
            return Consumer<AuthService>(
              builder: (context, authService, _) {
                final user = authService.currentUser;
                return user != null ? const Homepage() : const LoginPage();
              },
            );
          } catch (e) {
            print("Error in BanglaLitApp build: $e");
            return Scaffold(
              body: Center(child: Text("Error: $e\nPlease restart the app.")),
            );
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
