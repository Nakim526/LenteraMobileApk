import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/firebase_options.dart';
import 'pages/sign-in.dart';
import 'pages/sign-up.dart';
import 'pages/home.dart';
import 'pages/presence.dart';
import 'pages/profile.dart';
import 'pages/dataLog.dart';
import 'pages/notes.dart';
import 'pages/lesson.dart';
import 'pages/chat.dart';
import 'pages/task.dart';

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

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: isLoggedIn ? '/home' : '/sign-in',
      routes: {
        '/sign-in': (context) => SignInPage(),
        '/sign-up': (context) => SignUpPage(),
        '/home': (context) => HomePage(),
        '/presence': (context) => PresencePage(),
        '/profile': (context) => ProfilePage(),
        '/datalog': (context) => DataLogPage(),
        '/notes': (context) => NotesPage(),
        '/lesson': (context) => LessonPage(),
        '/chat': (context) => ChatPage(),
        '/task': (context) => TaskPage(),
      },
    );
  }
}
