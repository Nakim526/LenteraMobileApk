import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/firebase_options.dart';
import 'pages/sign-in.dart'; // Import halaman login
import 'pages/sign-up.dart';
import 'pages/home.dart';
import 'pages/record.dart';
import 'pages/profile.dart';
import 'pages/dataLog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Cek status login
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: isLoggedIn ? '/home' : '/sign-in',
      routes: {
        '/sign-in': (context) => SignInPage(),
        '/sign-up': (context) => SignUpPage(),
        '/home': (context) => HomePage(),
        '/record': (context) => RecordPage(),
        '/profile': (context) => ProfilePage(),
        '/dataLog': (context) => DataLogPage(),
      },
    );
  }
}
