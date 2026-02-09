import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'form_penjualan_page.dart';

class SetupPetugasPage extends StatelessWidget {
  const SetupPetugasPage({super.key});

  Future<void> _setPetugas(
    BuildContext context, {
    required String nama,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 🔐 SIMPAN DATA
    await prefs.setString('namaPetugas', nama);
    await prefs.setString('rolePetugas', role);
    await prefs.setBool('isPetugasSet', true);

    // 🔎 DEBUG (PENTING)
    debugPrint('=== PETUGAS DISIMPAN ===');
    debugPrint('namaPetugas  : ${prefs.getString('namaPetugas')}');
    debugPrint('rolePetugas  : ${prefs.getString('rolePetugas')}');
    debugPrint('isPetugasSet : ${prefs.getBool('isPetugasSet')}');

    // 🚀 PINDAH HALAMAN & HAPUS HISTORY
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const FormPenjualanPage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Petugas'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Pilih Perangkat Ini Sebagai:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),

            // ===== KARYAWAN =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _setPetugas(
                  context,
                  nama: 'Heri',
                  role: 'Karyawan',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Heri',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ===== ADMIN =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _setPetugas(
                  context,
                  nama: 'Admin',
                  role: 'Admin',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
