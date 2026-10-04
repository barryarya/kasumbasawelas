import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pilih_toko_page.dart';
import 'setup_petugas_page.dart';
import '../core/staff_access_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // 1. Controller untuk animasi jatuh & membal (Bounce In)
  late AnimationController _bounceController;
  late Animation<double> _dropAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // 2. Controller untuk animasi teks muncul bertahap
  late AnimationController _textController;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;

  // 3. Controller untuk animasi mengambang santai (Idle Float)
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // 4. Controller untuk animasi keluar ke bawah (Exit Downwards)
  late AnimationController _exitController;
  late Animation<double> _exitSlideAnimation;
  late Animation<double> _exitFadeAnimation;

  String _statusText = "Menyiapkan sistem kasir...";
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();

    // =====================================================
    // 1. ANIMASI JATUH & MEMBAL LENGKAP (Durasi 1800ms)
    // =====================================================
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Posisi jatuh dari atas (-320px) lalu membal berkali-kali sampai diam di 0
    _dropAnimation = Tween<double>(begin: -340.0, end: 0.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.bounceOut),
    );

    // Skala membesar dari 0.4 ke 1.0 dengan pantulan kenyal
    _scaleAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    // Opasitas gambar muncul dari 0 ke 1
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    // =====================================================
    // 2. TEKS MUNCUL SETELAH PANTULAN PERTAMA
    // =====================================================
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 20), end: Offset.zero).animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    // =====================================================
    // 3. IDLE FLOATING (Mengambang santai)
    // =====================================================
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _floatAnimation = Tween<double>(begin: -7.0, end: 7.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // =====================================================
    // 4. EXIT KE BAWAH (Meluncur cepat keluar layar)
    // =====================================================
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    // Meluncur jatuh ke bawah (+750px) tembus layar bawah
    _exitSlideAnimation = Tween<double>(begin: 0.0, end: 780.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOutCubic),
    );

    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    // Jalankan seluruh siklus splash
    _startAnimationCycle();
  }

  Future<void> _startAnimationCycle() async {
    // 1. Mulai animasi membal (bounce)
    _bounceController.forward();

    // Setelah separuh animasi bounce, tampilkan teks secara elegan
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _textController.forward();
    });

    // Jalankan pengecekan preferences secara asynchronous
    final startTime = DateTime.now();
    bool isPetugasSet = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      isPetugasSet = prefs.getBool('isPetugasSet') ?? false;
      if (isPetugasSet) {
        final isActive = await StaffAccessConfig.checkAccountActiveOnline();
        if (!isActive) {
          isPetugasSet = false;
        }
      }
      debugPrint('SplashScreen check: isPetugasSet = $isPetugasSet');
    } catch (e) {
      debugPrint('SplashScreen prefs error: $e');
    }

    // Tunggu animasi bounce selesai, lalu mulai idle floating
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted || _isExiting) return;

    _floatController.repeat(reverse: true);

    // Beri jeda idle mengambang agar animasi dinikmati pengguna (~1.6 detik)
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    const totalTargetDisplay = 3600; // Total durasi splash ~3.6 detik
    if (elapsed < totalTargetDisplay) {
      await Future.delayed(
        Duration(milliseconds: totalTargetDisplay - elapsed),
      );
    }

    if (!mounted || _isExiting) return;

    // Mulai transisi keluar ke bawah
    await _executeExit(isPetugasSet);
  }

  Future<void> _executeExit(bool isPetugasSet) async {
    if (_isExiting) return;
    _isExiting = true;

    if (mounted) {
      setState(() {
        _statusText = "Membuka aplikasi...";
      });
    }

    _floatController.stop();
    await _exitController.forward();

    if (!mounted) return;

    final targetPage = isPetugasSet
        ? const PilihTokoPage()
        : const SetupPetugasPage();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, __, ___) => targetPage,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _textController.dispose();
    _floatController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Fitur skip ramah kasir: ketuk layar jika ingin langsung masuk
          if (!_isExiting) {
            SharedPreferences.getInstance().then((prefs) {
              final isSet = prefs.getBool('isPetugasSet') ?? false;
              _executeExit(isSet);
            });
          }
        },
        child: Stack(
          children: [
            // Background ambient radial glow oranye hangat
            Center(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF8A00).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Konten Teranimasi
            SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _bounceController,
                    _floatController,
                    _exitController,
                  ]),
                  builder: (context, child) {
                    final dropY = _dropAnimation.value;
                    final scale = _scaleAnimation.value;
                    final fade = _fadeAnimation.value;

                    final floatY = _floatController.isAnimating
                        ? _floatAnimation.value
                        : 0.0;

                    final exitY = _exitSlideAnimation.value;
                    final exitFade = _exitFadeAnimation.value;

                    final totalY = dropY + floatY + exitY;
                    final currentOpacity = (fade * exitFade).clamp(0.0, 1.0);

                    return Transform.translate(
                      offset: Offset(0, totalY),
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: currentOpacity,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // =============================================
                              // GAMBAR UBI MEMBAL ELEGAN
                              // =============================================
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFF8A00,
                                    ).withValues(alpha: 0.40),
                                    width: 3.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF8A00,
                                      ).withValues(alpha: 0.28),
                                      blurRadius: 36,
                                      spreadRadius: 6,
                                      offset: const Offset(0, 12),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.07,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Padding(
                                    padding: const EdgeInsets.all(7),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/ubi_cilembu.jpeg',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) {
                                          return Image.asset(
                                            'assets/logo.png',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) {
                                              return const Center(
                                                child: Icon(
                                                  Icons.eco_rounded,
                                                  color: Color(0xFFFF8A00),
                                                  size: 70,
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 28),

                              // =============================================
                              // TEKS & BRAND (Animasi Slide Up & Fade In)
                              // =============================================
                              AnimatedBuilder(
                                animation: _textController,
                                builder: (context, _) {
                                  final textFade = _textFadeAnimation.value;
                                  final textOffset = _textSlideAnimation.value;

                                  return Opacity(
                                    opacity: textFade,
                                    child: Transform.translate(
                                      offset: textOffset,
                                      child: Column(
                                        children: [
                                          // Badge Kasumba
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFFF8A00,
                                              ).withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.eco_rounded,
                                                  color: Color(0xFFFF7800),
                                                  size: 15,
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  "KASUMBA SAWELAS",
                                                  style: TextStyle(
                                                    color: Color(0xFFFF7800),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 12),

                                          const Text(
                                            "Kasumba Sawelas",
                                            style: TextStyle(
                                              fontSize: 27,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.6,
                                              color: Color(0xFF20251F),
                                            ),
                                          ),

                                          const SizedBox(height: 5),

                                          Text(
                                            "Spesialis Ubi Cilembu & Kuliner",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 36),

                              // =============================================
                              // INDIKATOR LOADING HALUS
                              // =============================================
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xFFFF8A00),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _statusText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Versi aplikasi & petunjuk skip di bawah layar
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "Ketuk layar untuk langsung masuk",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
