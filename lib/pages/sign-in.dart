import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  Map<String, String> matkul = {
    'Pemrograman Web 1': 'Senin, 08.00-09.40',
    'Struktur Data': 'Selasa, 09.45-11.25',
    'Basis Data': 'Rabu, 12.50-14.30',
    'Pemrograman Terstruktur': 'Kamis, 14.35-16.15',
    'Algoritma dan Pemrograman': 'Jum\'at, 08.00-09.40',
    'Pemrograman Berorientasi Objek': 'Senin, 09.45-11.25',
    'Fisika Terapan': 'Selasa, 12.50-14.30',
    'Elektronika Digital': 'Rabu, 14.35-16.15',
    'Pengenalan Teknologi Informasi dan Ilmu Komputer': 'Kamis, 08.00-09.40',
    'Sistem Tertanam': 'Jum\'at, 09.45-11.25',
    'Sistem Operasi Komputer': 'Senin, 12.50-14.30',
  };

  Future<void> saveUserDataToDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      bool admin = false;
      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');

      final snapshot = await userRef.get();
      if (!snapshot.exists) {
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName ?? 'Anonymous',
        });
      }

      if (user.displayName != null) {
        admin = true;
        await userRef.update({
          'name': user.displayName,
          'role': 'admin',
        });
      } else {
        await userRef.update({
          'role': 'user',
        });
      }

      for (var entry in matkul.entries) {
        await getProgress(entry.key, entry.value, admin);
      }
    }
  }

  Future<void> getProgress(String? matkul, String? jadwal, bool? admin) async {
    double currentProgress = 0;
    double totalProgress = 0;
    double progress = 0;
    double total = 0;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef =
          FirebaseDatabase.instance.ref('users/${user.uid}/$matkul');
      final taskRef = FirebaseDatabase.instance.ref('tasks/$matkul');
      final snapshot = await taskRef.get();
      if (snapshot.exists) {
        final outerMap = Map.from(snapshot.value as Map);
        for (var key in outerMap.keys) {
          if (outerMap[key]['type'] == 'Tugas' ||
              outerMap[key]['type'] == 'Kehadiran') {
            total += 1;
            if (admin!) {
              progress += 1;
            } else if (!admin) {
              final userSnapshot = await userRef.child('presences').get();
              if (userSnapshot.exists) {
                final userProgress = Map.from(userSnapshot.value as Map);
                for (var uid in userProgress.keys) {
                  if (userProgress[uid] is Map) {
                    if (userProgress[uid]['taskUid'] == key) {
                      if (userProgress[uid]['status'] == 'Selesai') {
                        progress += 1;
                      } else if (userProgress[uid]['status'] == 'Terlambat') {
                        progress += 0.5;
                      }
                    }
                  }
                }
              }
            }
          } else if (outerMap[key]['type'] == 'Pengumuman') {
            total += 0.5;
            if (admin!) {
              progress += 0.5;
            } else {
              final announcements = await userRef.child('announcements').get();
              if (announcements.exists) {
                final userProgress = Map.from(announcements.value as Map);
                for (var uid in userProgress.keys) {
                  if (userProgress[uid] is Map) {
                    if (userProgress[uid]['taskUid'] == key) {
                      if (userProgress[uid]['status'] == 'Selesai') {
                        progress += 0.5;
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      setState(() {
        if (total == 0) total = 0.1;
        currentProgress = progress;
        totalProgress = admin! ? 30 : total;
      });
      double percentage = currentProgress / totalProgress;
      int percentText = (percentage * 100).toInt();
      await userRef.update({
        'progress': progress,
        'total': admin! ? 30 : total,
        'percentage': percentage,
        'percentText': percentText,
        'jadwal': jadwal,
      });
    }
  }

  Future<void> _loginWithEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Proses login
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await saveUserDataToDatabase();

        // Menyimpan status login ke SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        // Jika berhasil, pindah ke halaman utama
        Navigator.pushReplacementNamed(context, '/home');
      } on FirebaseAuthException catch (e) {
        String errorMessage;

        // Menangani error berdasarkan kode
        switch (e.code) {
          case 'invalid-email':
            errorMessage = 'Email yang Anda masukkan tidak valid.';
            break;
          case 'user-not-found':
            errorMessage = 'Akun dengan email ini tidak ditemukan.';
            break;
          case 'wrong-password':
            errorMessage = 'Password yang Anda masukkan salah.';
            break;
          case 'user-disabled':
            errorMessage =
                'Akun ini telah dinonaktifkan. Silakan hubungi admin.';
            break;
          case 'too-many-requests':
            errorMessage =
                'Terlalu banyak percobaan login. Silakan coba lagi nanti.';
            break;
          default:
            errorMessage = 'Login gagal. Silakan coba lagi.';
            break;
        }

        // Menampilkan pesan error kepada pengguna
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error'),
            content: Text('$errorMessage : $e'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      } catch (e) {
        // Error tak terduga
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error'),
            content: Text('$e'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Buat instance GoogleSignIn
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Logout terlebih dahulu untuk memaksa pengguna memilih akun kembali
      await googleSignIn.signOut();

      // Proses login
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; // Pengguna batal login

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Login ke Firebase dengan credential Google
      await FirebaseAuth.instance.signInWithCredential(credential);

      await saveUserDataToDatabase();

      // Simpan status login di SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      // Navigasi ke halaman utama
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      // Menampilkan pesan error jika login gagal
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('$e'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _onExitConfirmation(BuildContext context) async {
    return await showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Keluar Aplikasi"),
            content: Text("Apakah Anda yakin ingin keluar?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text("Batal"),
              ),
              TextButton(
                onPressed: () => SystemNavigator.pop(), // Keluar
                child: Text("Keluar"),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double statusBarHeight = MediaQuery.of(context).padding.top;
    double availableHeight = screenHeight - statusBarHeight;
    return WillPopScope(
      onWillPop: () => _onExitConfirmation(context),
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.lightGreenAccent,
                    Colors.green,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ListView(
                children: [
                  Container(
                    height: availableHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 30.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Lentera Mobile',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Crestwood',
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 25.0),
                                child: Image.asset(
                                  "lib/assets/logo UINAM.png",
                                  width: 100,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(20.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20.0),
                                  color: Colors.green,
                                ),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      decoration:
                                          InputDecoration(labelText: 'Email'),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your email';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: 16),
                                    TextFormField(
                                      controller: _passwordController,
                                      decoration: InputDecoration(
                                          labelText: 'Password'),
                                      obscureText: true,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your password';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Text("Belum punya akun? "),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pushNamed(
                                                context, '/sign-up');
                                          },
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.zero,
                                            ),
                                          ),
                                          child: Text(
                                            "Daftar disini!",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[900],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _loginWithEmail,
                                child: Text('Masuk'),
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('atau'),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              SizedBox(height: 16),
                              SizedBox(
                                width: MediaQuery.of(context).size.width,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      height: 45,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(26.0),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            offset: Offset(0, 1),
                                            blurRadius: 1.0,
                                          ),
                                        ],
                                      ),
                                      child: TextButton(
                                        onPressed: () {
                                          _loginWithGoogle();
                                        },
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(26.0),
                                          ),
                                        ),
                                        child: Container(
                                          child: Row(
                                            children: [
                                              Image.asset(
                                                "lib/assets/icon Google.png",
                                                width: 20,
                                              ),
                                              SizedBox(width: 10.0),
                                              Text("Masuk dengan Google"),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
