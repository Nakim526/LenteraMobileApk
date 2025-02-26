import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'pages/answer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Cek status login
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  User? _user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        _user = user;
      });

      if (user != null) {
        _updateUserStatus("online");
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_user != null) {
      if (state == AppLifecycleState.resumed) {
        _updateUserStatus("online");
      } else if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.detached) {
        _updateUserStatus("offline", saveLastSeen: true);
      }
      print(state);
    }
  }

  void _updateUserStatus(String status, {bool saveLastSeen = false}) {
    if (_user != null) {
      FirebaseDatabase.instance.ref("users/${_user!.uid}").update({
        "status": status,
        if (saveLastSeen) "lastSeen": DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: child,
        );
      },
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate, // Diperlukan untuk showDatePicker
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('id', 'ID')],
      debugShowCheckedModeBanner: false,
      initialRoute: widget.isLoggedIn ? '/home' : '/sign-in',
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
        '/answer': (context) => AnswerPage(),
      },
    );
  }
}
