import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pilih_toko_page.dart';
import '../core/staff_access_config.dart';
import 'package:http/http.dart' as http;

class SetupPetugasPage extends StatefulWidget {
  const SetupPetugasPage({super.key});

  @override
  State<SetupPetugasPage> createState() => _SetupPetugasPageState();
}

class _SetupPetugasPageState extends State<SetupPetugasPage> {
  @override
  void initState() {
    super.initState();
    StaffAccessConfig.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _setPetugas({
    required String nama,
    required String role,
    required String password,
  }) async {
    _showLoadingDialog();

    final url = Uri.parse(
      "https://script.google.com/macros/s/AKfycbxIusc8pC9My8OX7o3rFnueXR2OdNO0R67pwIqkInSUKgdzN4DOtOSHDMeufYwyTUCV/exec"
      "?nama=$nama&role=$role&password=$password",
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 25));

      if (!mounted) return;
      Navigator.pop(context); // tutup loading

      final status = response.body.trim();

      if (status == "AKTIF") {
        // Jika akun belum tersimpan di HP ini (misal di HP baru/karyawan baru),
        // otomatis daftarkan ke StaffAccessConfig lokal
        if (StaffAccessConfig.getRule(nama) == null) {
          await StaffAccessConfig.saveRule(
            StaffRule(
              nama: nama,
              role: role,
              allowedStores: ['ALL'],
              canInput: true,
            ),
          );
        }

        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('namaPetugas', nama);
        await prefs.setString('rolePetugas', role);
        await prefs.setString('passwordPetugas', password);

        final bool canInput = StaffAccessConfig.canInput(nama);
        await prefs.setBool('bolehInput', canInput);

        final allowedStores = StaffAccessConfig.getAllowedStores(nama);
        if (allowedStores.isNotEmpty) {
          await prefs.setString('aksesToko', allowedStores.first);
        }

        await prefs.setBool('isPetugasSet', true);

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PilihTokoPage()),
          (route) => false,
        );
      } else if (status == "PASSWORD_SALAH") {
        _showModernSnackBar("Password salah", isError: true);
      } else if (status == "NONAKTIF") {
        _showModernSnackBar("Akun nonaktif", isError: true);
      } else {
        _showModernSnackBar("User tidak ditemukan", isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // tutup loading kalau error

      // Fallback darurat khusus akun Admin utama: jika jaringan lambat / offline
      // dan password cocok dengan master 'admin99', izinkan Admin tetap masuk
      if (nama.toLowerCase().trim() == 'admin' && password == 'admin99') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('namaPetugas', 'Admin');
        await prefs.setString('rolePetugas', 'Admin');
        await prefs.setString('passwordPetugas', password);
        await prefs.setBool('bolehInput', true);
        await prefs.setString('aksesToko', 'ALL');
        await prefs.setBool('isPetugasSet', true);

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PilihTokoPage()),
          (route) => false,
        );
        return;
      }

      _showModernSnackBar(
        "Koneksi lambat / gagal terhubung ke server. Silakan coba lagi.",
        isError: true,
      );
    }
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
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

  void _showLoadingDialog() {
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
                        const Text(
                          "Memverifikasi...",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF20251F),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Menghubungkan ke server",
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

  void _showLoginDialog({
    required String nama,
    required String role,
    required Color accentColor,
    required IconData icon,
  }) {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top header: icon & close
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(icon, color: accentColor, size: 26),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Text(
                          "Login $nama",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      "Masukkan password akun Anda untuk mengaktifkan perangkat.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Password input field matching form style
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: "Password",
                        hintText: "Masukkan password",
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () {
                            setModalState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF7F7F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF20251F),
                            width: 1.5,
                          ),
                        ),
                      ),
                      onSubmitted: (_) {
                        final pwd = passwordController.text.trim();
                        if (pwd.isEmpty) return;
                        Navigator.pop(dialogContext);
                        _setPetugas(nama: nama, role: role, password: pwd);
                      },
                    ),

                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          final pwd = passwordController.text.trim();
                          if (pwd.isEmpty) {
                            _showModernSnackBar(
                              "Password tidak boleh kosong",
                              isError: true,
                            );
                            return;
                          }
                          Navigator.pop(dialogContext);
                          _setPetugas(nama: nama, role: role, password: pwd);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF20251F),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Masuk & Simpan",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showManualLoginDialog() {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'Karyawan';
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isAdmin = selectedRole.toLowerCase() == 'admin';
            final Color accentColor = isAdmin
                ? const Color(0xFF20251F)
                : const Color(0xFFFF8A00);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top header: icon & close
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.person_add_alt_1_rounded,
                              color: accentColor,
                              size: 26,
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => Navigator.pop(dialogContext),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        "Login Petugas Lain",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "Masukkan nama dan password yang telah didaftarkan di Google Sheet.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Nama Field
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: "Nama Petugas / Karyawan",
                          hintText: "Contoh: Aden",
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF20251F),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Role Switcher
                      const Text(
                        "Role Akun:",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF20251F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text(
                                  "Karyawan",
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              selected: selectedRole == 'Karyawan',
                              selectedColor: const Color(
                                0xFFFF8A00,
                              ).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: selectedRole == 'Karyawan'
                                    ? const Color(0xFFFF8A00)
                                    : Colors.grey.shade700,
                              ),
                              side: BorderSide(
                                color: selectedRole == 'Karyawan'
                                    ? const Color(0xFFFF8A00)
                                    : Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setModalState(
                                    () => selectedRole = 'Karyawan',
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text(
                                  "Admin",
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              selected: selectedRole == 'Admin',
                              selectedColor: const Color(
                                0xFF20251F,
                              ).withValues(alpha: 0.12),
                              labelStyle: TextStyle(
                                color: selectedRole == 'Admin'
                                    ? const Color(0xFF20251F)
                                    : Colors.grey.shade700,
                              ),
                              side: BorderSide(
                                color: selectedRole == 'Admin'
                                    ? const Color(0xFF20251F)
                                    : Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setModalState(() => selectedRole = 'Admin');
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Password Field
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          hintText: "Masukkan password",
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () {
                              setModalState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF20251F),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onSubmitted: (_) {
                          final name = nameController.text.trim();
                          final pwd = passwordController.text.trim();
                          if (name.isEmpty || pwd.isEmpty) return;
                          Navigator.pop(dialogContext);
                          _setPetugas(
                            nama: name,
                            role: selectedRole,
                            password: pwd,
                          );
                        },
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final pwd = passwordController.text.trim();
                            if (name.isEmpty) {
                              _showModernSnackBar(
                                "Nama petugas tidak boleh kosong",
                                isError: true,
                              );
                              return;
                            }
                            if (pwd.isEmpty) {
                              _showModernSnackBar(
                                "Password tidak boleh kosong",
                                isError: true,
                              );
                              return;
                            }
                            Navigator.pop(dialogContext);
                            _setPetugas(
                              nama: name,
                              role: selectedRole,
                              password: pwd,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF20251F),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Verifikasi & Masuk",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPetugasCard({
    required String nama,
    required String role,
    required String subtitle,
    required String badge,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor, size: 26),
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
                              nama,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
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
                              color: accentColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: accentColor,
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
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Color(0xFF20251F),
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
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            // =====================================================
            // BRANDING HEADER (Matching Form UI)
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
                        "Aktivasi Perangkat Kasir",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8A00).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "SETUP",
                    style: TextStyle(
                      color: Color(0xFFFF7800),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            // =====================================================
            // GREETING
            // =====================================================
            const Text(
              "Setup Petugas Dulu Ya👋",
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              "Pilih identitas petugas untuk mengaktifkan perangkat ini.",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 20),

            // =====================================================
            // HERO CARD (Matching Dark Gradient in Form UI)
            // =====================================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF20251F), Color(0xFF343B32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF20251F).withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.devices_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PILIH IDENTITAS KASIR",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Perangkat Siap Digunakan",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A00).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Siap",
                      style: TextStyle(
                        color: Color(0xFFFFAC42),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // =====================================================
            // SECTION TITLE
            // =====================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Daftar Petugas",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Ketuk untuk login & atur perangkat",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${StaffAccessConfig.getAllRules().length} PETUGAS",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // =====================================================
            // PETUGAS CARDS (Dinamis dari StaffAccessConfig)
            // =====================================================
            ...StaffAccessConfig.getAllRules().map((rule) {
              final isAdmin = rule.role.toLowerCase() == 'admin';
              final Color accentColor = isAdmin
                  ? const Color(0xFF20251F)
                  : (rule.canInput
                        ? const Color(0xFFFF8A00)
                        : const Color(0xFF2474E5));
              final IconData icon = isAdmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_rounded;

              String subtitle;
              if (isAdmin) {
                subtitle = "Akses Manajemen, Input & Dashboard Lengkap";
              } else if (rule.hasFullAccess) {
                subtitle = "Akses Penuh Semua Cabang Kasir";
              } else {
                subtitle = "Akses: ${rule.allowedStores.join(', ')}";
              }
              if (!rule.canInput && !isAdmin) {
                subtitle = "$subtitle (Lihat Saja)";
              }

              return _buildPetugasCard(
                nama: rule.nama,
                role: rule.role,
                subtitle: subtitle,
                badge: isAdmin ? "Administrator" : "Karyawan",
                accentColor: accentColor,
                icon: icon,
                onTap: () => _showLoginDialog(
                  nama: rule.nama,
                  role: rule.role,
                  accentColor: accentColor,
                  icon: icon,
                ),
              );
            }),

            const SizedBox(height: 6),

            // Tombol Login Sebagai Petugas Lain (Untuk HP baru / karyawan baru)
            OutlinedButton.icon(
              onPressed: _showManualLoginDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text(
                "Login Sebagai Petugas Lain",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF20251F),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
