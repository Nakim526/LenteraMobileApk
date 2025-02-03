import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({super.key});

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('lessons');
  bool _isLoading = false;

  void initstate() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _dbRef.push().set({
        'matkul': 'Pemrograman Web 1',
        'jadwal': 'Senin, 08.00-09.40',
        'url':
            'https://drive.google.com/drive/folders/1CIbV6B6PPLCaOS03AZi_V9PudCDJ0FkO'
      });
      await _dbRef.push().set({
        'matkul': 'Struktur Data',
        'jadwal': 'Selasa, 09.45-11.25',
        'url':
            'https://drive.google.com/drive/folders/1KYMzou-ljLuFIDHTW6PXBS5K9tfifQdX'
      });
      await _dbRef.push().set({
        'matkul': 'Basis Data',
        'jadwal': 'Rabu, 12.50-14.30',
        'url':
            'https://drive.google.com/drive/folders/14GskqOWlFLKFMBKTDE9BhTfk_-JZ10hL'
      });
      await _dbRef.push().set({
        'matkul': 'Pemrograman Terstruktur',
        'jadwal': 'Kamis, 14.35-16.15',
        'url':
            'https://drive.google.com/drive/folders/1gEtfYQx4raaLJgsskM-S-6bwIPRQeGdQ'
      });
      await _dbRef.push().set({
        'matkul': 'Algoritma dan Pemrograman',
        'jadwal': 'Jum\'at, 08.00-09.40',
        'url':
            'https://drive.google.com/drive/folders/18am1POmcnD1g1PeE-dBokD9m4plS00Ew'
      });
      await _dbRef.push().set({
        'matkul': 'Pemrograman Berorientasi Objek',
        'jadwal': 'Senin, 09.45-11.25',
        'url':
            'https://drive.google.com/drive/folders/1EGvM-fJTsWWMxvtEJdu76xohVXQHNB0q'
      });
      await _dbRef.push().set({
        'matkul': 'Fisika Terapan',
        'jadwal': 'Selasa, 12.50-14.30',
        'url':
            'https://drive.google.com/drive/folders/1U0N0iNqUbYqzjiOldHltnIc_RGEp6xk7'
      });
      await _dbRef.push().set({
        'matkul': 'Elektronika Digital',
        'jadwal': 'Rabu, 14.35-16.15',
        'url':
            'https://drive.google.com/drive/folders/19GLSvTGC9Ifd7cI1h3Y7kfQ0VtYER1wB'
      });
      await _dbRef.push().set({
        'matkul': 'Pengenalan Teknologi Informasi dan Ilmu Komputer',
        'jadwal': 'Kamis, 08.00-09.40',
        'url':
            'https://drive.google.com/drive/folders/1GBPC0_f9IG7LRdTe79VwqwcxYBjz4QIh'
      });
      await _dbRef.push().set({
        'matkul': 'Sistem Tertanam',
        'jadwal': 'Jum\'at, 09.45-11.25',
        'url':
            'https://drive.google.com/drive/folders/1RDWTGvPu7IJwUJIqJPyF9W0YAr1gHRuo'
      });
      await _dbRef.push().set({
        'matkul': 'Sistem Operasi Komputer',
        'jadwal': 'Senin, 12.50-14.30',
        'url':
            'https://drive.google.com/drive/folders/16a7RWugCMVaGkS0VjhFlqya-SmKuOQun'
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final matkul = Map<String, String>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              matkul['matkul']!,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.green[900],
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
          body: Stack(
            children: [
              Container(
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
                child: ListView(
                  physics: ClampingScrollPhysics(),
                  children: [
                    Container(
                      alignment: Alignment.topLeft,
                      height: MediaQuery.of(context).size.height * 0.25,
                      margin: const EdgeInsets.all(20.0),
                      padding: EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        color: Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            matkul['matkul']!,
                            style: TextStyle(
                              fontSize: 24.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            matkul['jadwal']!,
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListView.builder(
                      padding: EdgeInsets.only(bottom: 20.0),
                      itemCount: matkul.length,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        return Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 8.0,
                          ),
                          child: Material(
                            color: Colors.green.shade100,
                            elevation: 4.0,
                            clipBehavior: Clip.hardEdge,
                            borderRadius: BorderRadius.circular(16.0),
                            child: ListTile(
                              title: Text(
                                'matkul[index]',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('Pertemuan ke-1'),
                              trailing: Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/record',
                                  arguments: matkul['matkul'],
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 24.0,
                right: 24.0,
                child: IconButton(
                  onPressed: () {
                    _loadData();
                  },
                  icon: Icon(Icons.add),
                  color: Colors.black,
                  iconSize: 32.0,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.all(
                      12.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black45,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
