import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dalung/form_penjualan_page.dart';
import 'keboiwa/form_penjualan_page.dart';
import 'nusadua/form_penjualan_page.dart';
import 'auth/setup_petugas_page.dart';
import 'settings/pengaturan_harga_page.dart';
import 'settings/kelola_akses_petugas_page.dart';
import 'owner/dashboard_konsolidasi_page.dart';
import 'owner/form_kulakan_page.dart';
import 'owner/shared_neraca_page.dart';
import 'core/staff_access_config.dart';

class PilihTokoPage extends StatefulWidget {
  const PilihTokoPage({super.key});

  @override
  State<PilihTokoPage> createState() => _PilihTokoPageState();
}

class _PilihTokoPageState extends State<PilihTokoPage> {
  String namaPetugas = '';
  String rolePetugas = '';
  bool isLoaded = false;

  bool get isAdmin =>
      rolePetugas.toLowerCase() == 'admin' ||
      namaPetugas.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _loadPetugas();
    _checkActiveStatus();
  }

  Future<void> _checkActiveStatus() async {
    final isActive = await StaffAccessConfig.checkAccountActiveOnline();
    if (!isActive && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SetupPetugasPage()),
        (route) => false,
      );
    }
  }

  Future<void> _loadPetugas() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      namaPetugas = prefs.getString('namaPetugas') ?? '';
      rolePetugas = prefs.getString('rolePetugas') ?? 'Karyawan';
      isLoaded = true;
    });
  }

  bool _isTokoAllowed(String toko) {
    return StaffAccessConfig.isStoreAllowed(namaPetugas, toko);
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.lock_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFD32F2F)
            : const Color(0xFF20251F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLoadingDialog(String toko) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFFFF8A00),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Membuka $toko...",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF20251F),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Menyiapkan form penjualan",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFE53935),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Ganti Petugas?",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Anda akan keluar dari akun $namaPetugas dan dapat memilih petugas kasir lain.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          "Batal",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('isPetugasSet');
                          await prefs.remove('namaPetugas');
                          await prefs.remove('rolePetugas');
                          await prefs.remove('passwordPetugas');

                          if (!mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SetupPetugasPage(),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Ganti",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _verifyAdmin(VoidCallback onSuccess) {
    if (rolePetugas.toLowerCase() == 'admin' ||
        namaPetugas.toLowerCase() == 'admin') {
      onSuccess();
      return;
    }

    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFF8A00)),
            SizedBox(width: 10),
            Text(
              "Verifikasi Admin",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Fitur ini khusus untuk Pemilik / Admin. Masukkan password admin:",
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Password Admin",
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8A00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (passController.text == "admin99") {
                Navigator.pop(dlgContext);
                onSuccess();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Password admin salah!"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Masuk"),
          ),
        ],
      ),
    );
  }

  void _openDashboardKonsolidasi() {
    _verifyAdmin(() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DashboardKonsolidasiPage()),
      );
    });
  }

  void _openKulakan() {
    _verifyAdmin(() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FormKulakanPage()),
      );
    });
  }

  void _openNeraca() {
    _verifyAdmin(() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SharedNeracaPage()),
      );
    });
  }

  void _openPengaturanHarga() {
    _verifyAdmin(() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PengaturanHargaPage()),
      );
    });
  }

  void _openKelolaAkses() {
    _verifyAdmin(() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const KelolaAksesPetugasPage()),
      );
    });
  }

  void _showAdminHubModal() {
    _verifyAdmin(() {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Menu Khusus Owner / Admin',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF20251F),
                ),
              ),
              const SizedBox(height: 14),

              // 1. Dashboard Konsolidasi
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF20251F).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    color: Color(0xFF20251F),
                  ),
                ),
                title: const Text(
                  'Dashboard Konsolidasi Semua Cabang',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Pantau total omset, kas bersih, dan kontribusi 4 cabang',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DashboardKonsolidasiPage(),
                    ),
                  );
                },
              ),
              const Divider(),

              // 2. Pengaturan Harga
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8A00).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFFFF8A00),
                  ),
                ),
                title: const Text(
                  'Pengaturan Harga Ubi',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Atur harga per kg ubi untuk kasir dan OCR scanner',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PengaturanHargaPage(),
                    ),
                  );
                },
              ),
              const Divider(),

              // 3. Kelola Hak Akses Petugas
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                title: const Text(
                  'Kelola Hak Akses Petugas',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Atur cabang kasir & izin input penjualan tiap karyawan',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const KelolaAksesPetugasPage(),
                    ),
                  );
                },
              ),
              const Divider(),

              // 4. Catat Kulakan Ubi
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD84315).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Color(0xFFD84315),
                  ),
                ),
                title: const Text(
                  'Catat Kulakan Ubi (Bahan Baku)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Input belanja ubi baru, berat (Kg), dan total biaya modal',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FormKulakanPage()),
                  );
                },
              ),
              const Divider(),

              // 5. Neraca Usaha & Laba Rugi
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Color(0xFF1565C0),
                  ),
                ),
                title: const Text(
                  'Neraca & Laba Rugi Toko',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Pantau HPP, laba bersih riil, arus kas, dan nilai stok ubi',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SharedNeracaPage()),
                  );
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> setToko(String toko) async {
    final prefs = await SharedPreferences.getInstance();
    String? nama = prefs.getString('namaPetugas') ?? namaPetugas;

    // 🔒 Pemeriksaan Hak Akses Toko Dinamis
    if (!StaffAccessConfig.isStoreAllowed(nama, toko)) {
      _showModernSnackBar(
        StaffAccessConfig.getAllowedStoresMessage(nama),
        isError: true,
      );
      return;
    }

    _showLoadingDialog(toko);

    await prefs.setString('namaToko', toko);

    Widget page;
    switch (toko) {
      case "Dalung":
        page = const FormPenjualanDalungPage();
        break;
      case "Kebo Iwa":
        page = const FormPenjualanPage();
        break;
      case "Nusa Dua":
        page = const FormPenjualanNusaDuaPage();
        break;
      default:
        page = const FormPenjualanPage();
    }

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    Navigator.pop(context); // tutup loading dialog
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      _loadPetugas();
    }
  }

  Widget _buildTokoCard({
    required String namaToko,
    required String targetToko,
    required String subtitle,
    required String tag,
    required Color accentColor,
    required IconData icon,
  }) {
    final bool isAllowed = _isTokoAllowed(targetToko);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isAllowed
              ? Colors.grey.shade200
              : Colors.red.shade100.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isAllowed ? 0.03 : 0.01),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setToko(targetToko),
          borderRadius: BorderRadius.circular(22),
          child: Opacity(
            opacity: isAllowed ? 1.0 : 0.65,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isAllowed
                          ? accentColor.withValues(alpha: 0.12)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      color: isAllowed ? accentColor : Colors.grey.shade500,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                namaToko,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: isAllowed
                                      ? const Color(0xFF20251F)
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isAllowed
                                    ? accentColor.withValues(alpha: 0.10)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: isAllowed
                                      ? accentColor
                                      : Colors.grey.shade600,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (!isAllowed) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                size: 12,
                                color: Colors.red.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Tidak ada akses untuk $namaPetugas",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isAllowed
                          ? const Color(0xFFF7F7F5)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Icon(
                      isAllowed
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.lock_outline_rounded,
                      size: 13,
                      color: isAllowed
                          ? const Color(0xFF20251F)
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerActionCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accentColor, size: 22),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF20251F),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            // =====================================================
            // 1. BRANDING HEADER & LOGOUT
            // =====================================================
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8A00),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Kasumba Sawelas",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Pusat Kasir & Manajemen",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Ganti Petugas / Logout button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    tooltip: "Ganti Petugas",
                    onPressed: _showLogoutDialog,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: Color(0xFF20251F),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // =====================================================
            // 2. PETUGAS PROFILE BANNER (Clean & Terpadu)
            // =====================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF20251F), Color(0xFF343B32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF20251F).withValues(alpha: 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.person_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                namaPetugas.isEmpty ? "Memuat..." : namaPetugas,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isAdmin
                                            ? const Color(0xFFFF8A00)
                                            : Colors.blueAccent)
                                        .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isAdmin ? "ADMIN" : "KARYAWAN",
                                style: TextStyle(
                                  color: isAdmin
                                      ? const Color(0xFFFFB74D)
                                      : Colors.lightBlueAccent,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isAdmin
                              ? "Akses penuh manajemen & cabang kasir"
                              : "Petugas kasir aktif siap transaksi",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Color(0xFF5BE37A), size: 7),
                        SizedBox(width: 5),
                        Text(
                          "Online",
                          style: TextStyle(
                            color: Color(0xFF8FF0A3),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // =====================================================
            // 3. SEKSI FITUR 1: CABANG KASIR (3 Cabang Ubi)
            // =====================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Cabang Kasir",
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Pilih cabang untuk mulai transaksi",
                      style: TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8A00).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "3 CABANG",
                    style: TextStyle(
                      color: Color(0xFFFF7800),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 1. Toko Dalung
            _buildTokoCard(
              namaToko: "Toko Dalung",
              targetToko: "Dalung",
              subtitle: "Ubi Cilembu & Ubi Ungu",
              tag: "Dalung",
              accentColor: const Color(0xFFFF8A00),
              icon: Icons.store_rounded,
            ),

            // 2. Toko Kebo Iwa
            _buildTokoCard(
              namaToko: "Toko Kebo Iwa",
              targetToko: "Kebo Iwa",
              subtitle: "Ubi Cilembu & Ubi Ungu",
              tag: "Kebo Iwa",
              accentColor: const Color(0xFF2E7D32),
              icon: Icons.storefront_rounded,
            ),

            // 3. Toko Nusa Dua
            _buildTokoCard(
              namaToko: "Toko Nusa Dua",
              targetToko: "Nusa Dua",
              subtitle: "Ubi Cilembu & Ubi Ungu",
              tag: "Nusa Dua",
              accentColor: const Color(0xFF1565C0),
              icon: Icons.beach_access_rounded,
            ),

            // =====================================================
            // 4. SEKSI FITUR 2: MENU PEMILIK & MANAJEMEN (Khusus Admin)
            // =====================================================
            if (isAdmin) ...[
              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Menu Manajemen & Owner",
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Konsolidasi, modal, laba & kontrol staf",
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20251F).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "KHUSUS ADMIN",
                      style: TextStyle(
                        color: Color(0xFF20251F),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Hero Card: Dashboard Konsolidasi 3 Cabang
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E242B), Color(0xFF2C353F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFFFB74D).withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openDashboardKonsolidasi,
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8A00), Color(0xFFFFA726)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF8A00,
                                  ).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.analytics_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        "Dashboard Konsolidasi",
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFFB74D,
                                        ).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        "3 CABANG",
                                        style: TextStyle(
                                          color: Color(0xFFFFB74D),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "Konsolidasi omset, transaksi & kas bersih 3 cabang",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white70,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2x2 Grid Fitur Manajemen
              Row(
                children: [
                  Expanded(
                    child: _buildOwnerActionCard(
                      title: "Catat Kulakan",
                      subtitle: "Input belanja ubi baru",
                      badge: "MODAL",
                      icon: Icons.inventory_2_rounded,
                      accentColor: const Color(0xFFD84315),
                      onTap: _openKulakan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOwnerActionCard(
                      title: "Neraca & Laba",
                      subtitle: "Laba bersih & aset stok",
                      badge: "KEUANGAN",
                      icon: Icons.account_balance_wallet_rounded,
                      accentColor: const Color(0xFF1565C0),
                      onTap: _openNeraca,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildOwnerActionCard(
                      title: "Pengaturan Harga",
                      subtitle: "Katalog harga ubi/kg",
                      badge: "KATALOG",
                      icon: Icons.price_change_rounded,
                      accentColor: const Color(0xFF2E7D32),
                      onTap: _openPengaturanHarga,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOwnerActionCard(
                      title: "Hak Akses Staf",
                      subtitle: "Atur izin kasir & toko",
                      badge: "OTORITAS",
                      icon: Icons.security_rounded,
                      accentColor: const Color(0xFF6A1B9A),
                      onTap: _openKelolaAkses,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Opsi untuk Karyawan jika owner meminjam perangkat
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: _showAdminHubModal,
                  icon: const Icon(Icons.lock_outline_rounded, size: 16),
                  label: const Text(
                    "Masuk ke Menu Khusus Owner",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
