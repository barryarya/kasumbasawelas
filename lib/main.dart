import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setup_petugas_page.dart';
import 'form_penjualan_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Catatan Penjualan Ubi',
      theme: ThemeData(primarySwatch: Colors.brown),
      home: const SplashCheck(),
    );
  }
}

class SplashCheck extends StatelessWidget {
  const SplashCheck({super.key});

  Future<bool> _isPetugasSet() async {
    final prefs = await SharedPreferences.getInstance();
    final isSet = prefs.getBool('isPetugasSet') ?? false;

    // 🔎 LOG WAJIB (INI PENTING)
    debugPrint('isPetugasSet = $isSet');
    debugPrint('namaPetugas  = ${prefs.getString('namaPetugas')}');
    debugPrint('rolePetugas  = ${prefs.getString('rolePetugas')}');

    return isSet;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isPetugasSet(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return const FormPenjualanPage();
        } else {
          return const SetupPetugasPage();
        }
      },
    );
  }
}
