import 'package:firebase_auth/firebase_auth.dart';
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
  bool _isLoading = false;
  bool _isVisible = false;
  bool _isProcessing = false;
  String? keyId;

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await _databaseRef.child('uploads').get();
        if (snapshot.exists) {
          setState(() {
            data = snapshot.value as Map<dynamic, dynamic>;
          });
        } else {
          setState(() {
            data = null;
          });
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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
          actions: [
            if (!_isVisible)
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _fetchData();
                    });
                  },
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            if (!_isVisible && data != null)
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
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: data!.length,
                  itemBuilder: (context, index) {
                    final key = data!.keys.elementAt(index);
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
                            data![key]['name'],
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            data![key]['timestamp'],
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            setState(() {
                              _isVisible = true;
                              _isProcessing = true;
                              keyId = key;
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (_isVisible && keyId != null)
              ListView(
                children: [
                  Container(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        if (_isProcessing)
                          Container(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        Container(
                          height: MediaQuery.of(context).size.height * 0.4,
                          margin: EdgeInsets.only(bottom: 10.0),
                          child: Image.network(
                            data![keyId]['photoUrl'],
                            loadingBuilder: (context, child, loadingProgress) {
                              try {
                                if (loadingProgress == null) {
                                  return child; // Tampilkan gambar
                                } else {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    setState(() {
                                      _isProcessing = false;
                                    });
                                  });
                                  return Container(
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                              } catch (e) {
                                return child; // Tampilkan gambar
                              } finally {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  setState(() {
                                    _isProcessing = false;
                                  });
                                });
                              }
                            },
                          ),
                        ),
                        Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: EdgeInsets.only(
                                top: 30.0,
                                bottom: 16.0,
                                left: 16.0,
                                right: 16.0,
                              ),
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
                                  Flexible(
                                    child: Text(
                                      data![keyId]['name'],
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Text(
                                "Nama",
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: EdgeInsets.only(
                                top: 30.0,
                                bottom: 16.0,
                                left: 16.0,
                                right: 16.0,
                              ),
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
                                  Flexible(
                                    child: Text(
                                      data![keyId]['nim'],
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Text(
                                "NIM",
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: EdgeInsets.only(
                                top: 30.0,
                                bottom: 16.0,
                                left: 16.0,
                                right: 16.0,
                              ),
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
                                  Flexible(
                                    child: Text(
                                      data![keyId]['lesson'],
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Text(
                                "Mata Kuliah",
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: EdgeInsets.only(
                                top: 30.0,
                                bottom: 16.0,
                                left: 16.0,
                                right: 16.0,
                              ),
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
                                  Flexible(
                                    child: Text(
                                      data![keyId]['attendance'],
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Text(
                                "Keterangan",
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: EdgeInsets.only(
                                top: 30.0,
                                bottom: 16.0,
                                left: 16.0,
                                right: 16.0,
                              ),
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
                                  Flexible(
                                    child: Text(
                                      data![keyId]['timestamp'],
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Text(
                                "Waktu",
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (keyId != null) {
                              final locationUrl = data![keyId]['location'];
                              if (locationUrl != null &&
                                  locationUrl.isNotEmpty) {
                                launch(locationUrl); // Membuka URL lokasi
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text("URL lokasi tidak tersedia")),
                                );
                              }
                            }
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
                        SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            if (_isLoading)
              Container(
                color: Colors.black45,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (data == null)
              Container(
                color: Colors.white,
                child: Center(
                  child: Text(
                    "Not Attendance yet",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
