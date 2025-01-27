import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatelessWidget {
  Future<void> _logout(BuildContext context) async {
    // Hapus status login dari SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Navigasi kembali ke halaman login
    Navigator.pushReplacementNamed(context, '/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    List<String> matkul = [
      'Pemrograman Web 1',
      'Struktur Data',
      'Basis Data',
      'Pemrograman Terstruktur',
      'Algoritma dan Pemrograman',
      'Pemrograman Berorientasi Objek',
      'Fisika Terapan',
      'Elektronika Digital',
      'Pengenalan Teknologi Informasi dan Ilmu Komputer',
      'Sistem Tertanam',
      'Sistem Operasi Komputer',
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text('LENTERA MOBILE APP'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green,
              Colors.lightGreenAccent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView.separated(
          itemCount: matkul.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16.0),
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.green.shade200,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: ListTile(
                title: Text(matkul[index]),
                subtitle: Text('Pertemuan ke-1'),
                leading: Icon(Icons.lens),
                trailing: Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, '/record');
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
