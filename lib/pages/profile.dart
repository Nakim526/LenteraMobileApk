import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GlobalKey<FormFieldState> fieldKeyName = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> fieldKeyNim = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> fieldKeyAddress = GlobalKey<FormFieldState>();
  final _nameController = TextEditingController();
  final _nimController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> saveUserDataToDatabase() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final databaseRef = FirebaseDatabase.instance.ref();
          final userRef = databaseRef.child('users').child(user.uid);

          // Simpan data pengguna
          await userRef.update({
            'name': _nameController.text.trim(),
            'nim': _nimController.text.trim(),
            'address': _addressController.text.trim(),
          });
        }

        await showDialog(
          context: context,
          barrierDismissible: false, // Jangan tutup saat klik di luar dialog
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Data Disimpan!'),
              content: Text(
                  'Data kamu berhasil diubah. Silahkan kembali ke halaman profil.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan data: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isEditing = false;
          _isSaving = false;
          _loadUserData();
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final databaseRef = FirebaseDatabase.instance.ref();
      final snapshot = await databaseRef.child('users/${user.uid}').get();
      if (snapshot.exists) {
        setState(() {
          _userData = Map<String, dynamic>.from(snapshot.value as Map);
        });
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double statusBarHeight = MediaQuery.of(context).padding.top;
    double appBarHeight = kToolbarHeight;
    double availableHeight = screenHeight - statusBarHeight - appBarHeight;
    double profileHeight = availableHeight * 0.3;
    if (_userData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Profile',
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
        body: Container(
          color: Colors.black45,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    return WillPopScope(
      onWillPop: () async {
        if (_isEditing) {
          setState(() {
            _isEditing = false;
          });
          return false; // Mencegah aplikasi keluar, hanya tutup tampilan detail.
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Profile',
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
                if (_isEditing) {
                  setState(() {
                    _isEditing = false;
                  });
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  if (_isEditing) {
                    setState(() {
                      _nameController.text = _userData?['name'] ?? '';
                      _nimController.text = _userData?['nim'] ?? '';
                      _addressController.text = _userData?['address'] ?? '';
                    });
                  } else {
                    setState(() {
                      _loadUserData();
                    });
                  }
                },
              ),
            ),
          ],
        ),
        body: Container(
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
          child: Form(
            key: _formKey,
            child: Stack(
              children: [
                if (!_isEditing)
                  ListView(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        width: MediaQuery.of(context).size.width,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: profileHeight,
                              width: profileHeight,
                              decoration: BoxDecoration(
                                color: Colors.grey[600],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(Icons.person,
                                    size: 150, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        padding: const EdgeInsets.all(20),
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
                          children: [
                            SizedBox(
                              width: 75,
                              child: Text(
                                "Nama",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Flexible(
                              child: Text(_userData?['name'] ?? "Unknown"),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        padding: const EdgeInsets.all(20),
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
                          children: [
                            SizedBox(
                              width: 75,
                              child: Text(
                                "NIM",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Flexible(
                              child: Text(_userData?['nim'] ?? "Unknown"),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        padding: const EdgeInsets.all(20),
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
                          children: [
                            SizedBox(
                              width: 75,
                              child: Text(
                                "Alamat",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Flexible(
                              child: Text(_userData?['address'] ?? "Unknown"),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        padding: const EdgeInsets.all(20),
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
                          children: [
                            SizedBox(
                              width: 75,
                              child: Text(
                                "Email",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Flexible(
                              child: Text(_userData?['email'] ?? "Unknown"),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isEditing = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 5,
                              ),
                              icon: Icon(Icons.edit, color: Colors.green[900]),
                              label: Text("Edit"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  ListView(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        width: MediaQuery.of(context).size.width,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: profileHeight,
                              width: profileHeight,
                              decoration: BoxDecoration(
                                color: Colors.grey[600],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(Icons.person,
                                    size: 150, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          key: fieldKeyName,
                          controller: _nameController,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 19.0,
                            ),
                            fillColor: Colors.white,
                            filled: true,
                            labelText: 'Nama',
                            labelStyle: TextStyle(
                              color: Colors.black,
                              backgroundColor: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.grey,
                              ), // Warna saat tidak fokus
                              borderRadius: BorderRadius.circular(15),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.blue[900]!,
                                width: 2,
                              ), // Warna saat fokus
                              borderRadius: BorderRadius.circular(15),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.red,
                                width: 1,
                              ), // Warna saat error
                              borderRadius: BorderRadius.circular(15),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.black12,
                              ), // Warna saat disabled
                              borderRadius: BorderRadius.circular(15),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.red[900]!,
                                width: 2,
                              ), // Warna saat error dan fokus
                              borderRadius: BorderRadius.circular(15),
                            ),
                            errorStyle: TextStyle(
                              height: 0, // Menyembunyikan error text bawaan
                              fontSize: 0,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        child: Builder(
                          builder: (context) {
                            final errorText =
                                fieldKeyName.currentState?.errorText;
                            if (errorText != null) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: 8.0,
                                  bottom: 8.0,
                                ),
                                child: Text(
                                  errorText,
                                  style: TextStyle(
                                    color: Colors.red[900],
                                    fontSize: 12,
                                    height: 1.0,
                                  ),
                                ),
                              );
                            }
                            return SizedBox.shrink();
                          },
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          key: fieldKeyNim,
                          controller: _nimController,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 19.0,
                            ),
                            fillColor: Colors.white,
                            filled: true,
                            labelText: 'NIM',
                            labelStyle: TextStyle(
                              color: Colors.black,
                              backgroundColor: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.grey,
                              ), // Warna saat tidak fokus
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.blue[900]!,
                                width: 2,
                              ), // Warna saat fokus
                              borderRadius: BorderRadius.circular(14),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.red,
                                width: 1,
                              ), // Warna saat error
                              borderRadius: BorderRadius.circular(14),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.black12,
                              ), // Warna saat disabled
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.red[900]!,
                                width: 2,
                              ), // Warna saat error dan fokus
                              borderRadius: BorderRadius.circular(14),
                            ),
                            errorStyle: TextStyle(
                              height: 0, // Menyembunyikan error text bawaan
                              fontSize: 0,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your NIM';
                            }
                            return null;
                          },
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        child: Builder(
                          builder: (context) {
                            final errorText =
                                fieldKeyNim.currentState?.errorText;
                            if (errorText != null) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: 8.0,
                                  bottom: 8.0,
                                ),
                                child: Text(
                                  errorText,
                                  style: TextStyle(
                                    color: Colors.red[900],
                                    fontSize: 12,
                                    height: 1.0,
                                  ),
                                ),
                              );
                            }
                            return SizedBox.shrink();
                          },
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          key: fieldKeyAddress,
                          controller: _addressController,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 19.0,
                            ),
                            fillColor: Colors.white,
                            filled: true,
                            labelText: 'Alamat',
                            labelStyle: TextStyle(
                              color: Colors.black,
                              backgroundColor: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.grey,
                              ), // Warna saat tidak fokus
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.blue[900]!,
                                width: 2,
                              ), // Warna saat fokus
                              borderRadius: BorderRadius.circular(14),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.red,
                                width: 1,
                              ), // Warna saat error
                              borderRadius: BorderRadius.circular(14),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.black12,
                              ), // Warna saat disabled
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.red[900]!,
                                width: 2,
                              ), // Warna saat error dan fokus
                              borderRadius: BorderRadius.circular(14),
                            ),
                            errorStyle: TextStyle(
                              height: 0, // Menyembunyikan error text bawaan
                              fontSize: 0,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your address';
                            }
                            return null;
                          },
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        child: Builder(
                          builder: (context) {
                            final errorText =
                                fieldKeyAddress.currentState?.errorText;
                            if (errorText != null) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: 8.0,
                                  bottom: 8.0,
                                ),
                                child: Text(
                                  errorText,
                                  style: TextStyle(
                                    color: Colors.red[900],
                                    fontSize: 12,
                                    height: 1.0,
                                  ),
                                ),
                              );
                            }
                            return SizedBox.shrink();
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                });
                              },
                              label: Text("Kembali"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 5,
                              ),
                              icon: Icon(Icons.arrow_back,
                                  color: Colors.green[900]),
                            ),
                            SizedBox(
                              width: 25,
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  saveUserDataToDatabase();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 5,
                              ),
                              icon: Icon(Icons.save, color: Colors.green[900]),
                              label: Text("Simpan"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (_isSaving || _isLoading)
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
