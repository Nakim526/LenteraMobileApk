import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

class DataLogPage extends StatefulWidget {
  @override
  _DataLogPageState createState() => _DataLogPageState();
}

class _DataLogPageState extends State<DataLogPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  Map<dynamic, dynamic>? data;
  bool _isVisible = false;
  String? keyId;

  Future<void> _fetchData() async {
    try {
      final snapshot = await _databaseRef.child('uploads').get();
      if (snapshot.exists) {
        setState(() {
          data = snapshot.value as Map<dynamic, dynamic>;
        });
      } else {
        print('No data available.');
      }
    } catch (e) {
      print('Error reading data: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isVisible) {
          setState(() {
            _isVisible = false;
            keyId = null;
          });
          return false; // Mencegah aplikasi keluar, hanya tutup tampilan detail.
        }
        return true;
      },
      child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.green[900],
            title: Text(
              'Riwayat',
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
                  if (_isVisible) {
                    setState(() {
                      _isVisible = false;
                      keyId = null;
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
          body: Stack(
            children: [
              if (!_isVisible)
                data == null
                    ? Center(child: CircularProgressIndicator())
                    : Container(
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
                        child: ListView.builder(
                          itemCount: data!.length,
                          itemBuilder: (context, index) {
                            final key = data!.keys.elementAt(index);
                            return Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 8.0,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16.0),
                                color: Colors.green.shade200,
                              ),
                              child: ListTile(
                                title: Text('Nama: ${data![key]['name']}'),
                                subtitle: Text('NIM: ${data![key]['nim']}'),
                                onTap: () {
                                  setState(() {
                                    _isVisible = true;
                                    keyId = key;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
              if (_isVisible && keyId != null)
                Column(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      margin: EdgeInsets.only(top: 20.0, bottom: 10.0),
                      child: Image.network(
                        data![keyId]['photoUrl'],
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null)
                            return child;
                          else
                            return Center(
                              child: CircularProgressIndicator(),
                            );
                        },
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Nama: ${data![keyId]['name']}',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'NIM: ${data![keyId]['nim']}',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Waktu: ${data![keyId]['timestamp']}',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        launch(data![keyId]['location']);
                      },
                      label: Text(
                        "Lihat Lokasi",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      icon: Icon(
                        Icons.location_on,
                        color: Colors.white,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        minimumSize: Size(175, 50),
                        elevation: 5,
                        shadowColor: Colors.grey,
                      ),
                    ),
                  ],
                )
            ],
          )),
    );
  }
}
