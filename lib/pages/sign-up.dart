import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> saveUserDataToDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final databaseRef = FirebaseDatabase.instance.ref();
      final userRef = databaseRef.child('users').child(user.uid);

      // Simpan data pengguna
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'name': _usernameController.text.trim(),
      });
    }
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Mendaftarkan pengguna baru
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Menampilkan pop-up konfirmasi
        await showDialog(
          context: context,
          barrierDismissible: false, // Jangan tutup saat klik di luar dialog
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Daftar Akun Berhasil!'),
              content: Text(
                  'Akun kamu berhasil dibuat. Silahkan lanjut ke halaman login.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Menutup dialog
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );

        // Simpan data pengguna ke Firebase Realtime Database
        await saveUserDataToDatabase();

        // Kembali ke halaman login
        Navigator.pop(context);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          // Menampilkan pesan error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('The password provided is too weak.')),
          );
        } else if (e.code == 'email-already-in-use') {
          // Menampilkan pesan error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('The account already exists for that email.')),
          );
        } else {
          // Menampilkan pesan error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign-Up failed: Input is not available')),
          );
        }
      } catch (e) {
        // Menampilkan pesan error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-Up failed: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double statusBarHeight = MediaQuery.of(context).padding.top;
    double appBarHeight = kToolbarHeight;
    double availableHeight = screenHeight - statusBarHeight - appBarHeight;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[900],
        title: Text(
          'Kembali Login',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'DAFTAR AKUN',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 50),
                    Container(
                      padding: EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        color: Colors.green,
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Nama Lengkap',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your username';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration:
                                InputDecoration(labelText: 'Email Baru'),
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
                                InputDecoration(labelText: 'Password Baru'),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                                labelText: 'Konfirmasi Password'),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              } else if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 10),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    _isLoading
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _signUp,
                            child: Text('Daftar'),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
