import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatelessWidget {
  Future<void> _logout(BuildContext context) async {
    // Hapus status login dari SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');

    // Logout dari Firebase
    await FirebaseAuth.instance.signOut();

    // Navigasi kembali ke halaman login
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LENTERA MOBILE APP'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Container(
        child: ListView(
          children: [
            ListTile(
              title: const Text('Pemrograman Web 1'),
              subtitle: const Text('Pertemuan ke-1'),
              leading: const Icon(Icons.lens),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pushNamed(context, '/record');
              },
            ),
          ],
        ),
      ),
    );
  }
}
