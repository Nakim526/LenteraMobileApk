import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sign_up.dart'; // Import halaman sign-up
import 'home.dart'; // Import halaman utama

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _loginWithEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        setState(() {
          _isLoading = true;
        });

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
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
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // Pengguna batal login

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Login failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ListView(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            decoration: InputDecoration(labelText: 'Password'),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 24),
                          _isLoading
                              ? CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _loginWithEmail,
                                  child: Text('Login'),
                                ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loginWithGoogle,
                            icon: Icon(Icons.login),
                            label: Text('Login with Google'),
                          ),
                          SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => SignUpPage()),
                              );
                            },
                            child: Text('Don\'t have an account? Sign Up'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            child: Container(),
          ),
        ],
      ),
    );
  }
}
