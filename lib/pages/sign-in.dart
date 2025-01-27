import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

// Setelah login berhasil
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        // Simpan status login ke SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true); // Menyimpan status login
        await prefs.setString(
          'userEmail',
          _emailController.text,
        ); // Simpan email pengguna

        // Navigasi ke halaman utama
        Navigator.pushReplacementNamed(context, '/home');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        // Error tak terduga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithGoogle() async {
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

      // Simpan status login di SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      // Navigasi ke halaman utama
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      // Menampilkan pesan error jika login gagal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Login failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double statusBarHeight = MediaQuery.of(context).padding.top;
    double availableHeight = screenHeight - statusBarHeight;
    return Scaffold(
      body: Container(
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
                          'LENTERA MOBILE',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 50.0),
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
                                decoration: InputDecoration(labelText: 'Email'),
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
                                decoration:
                                    InputDecoration(labelText: 'Password'),
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
                                  Text("Belum punya akun?"),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/sign-up');
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                    ),
                                    child: Text(
                                      " Daftar disini!",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[900]),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        _isLoading
                            ? CircularProgressIndicator()
                            : ElevatedButton(
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
                        Container(
                          width: MediaQuery.of(context).size.width,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 45,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26.0),
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
                                      borderRadius: BorderRadius.circular(26.0),
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
    );
  }
}
