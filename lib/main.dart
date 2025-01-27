import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/sign_in.dart'; // Import halaman login
import 'pages/sign_up.dart';
import 'pages/home.dart';
import 'pages/record.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login with Firebase',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/sign-in': (context) => LoginPage(),
        '/sign-up': (context) => SignUpPage(),
        '/home': (context) => HomePage(),
        '/record': (context) => RecordPage(),
      },
      home: LoginPage(), // Halaman awal
    );
  }
}
