import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Model data ringkasan rekap untuk dikirim ke WhatsApp
class WhatsAppRecapData {
  final String namaToko;
  final String periode;
  final String? namaPetugas;
  final int totalPenjualan;
  final int jumlahTransaksi;
  final int totalCash;
  final int countCash;
  final int totalQrisBJB;
  final int countQris;
  final int totalGoPay;
  final int countGoPay;
  final int totalShopeePay;
  final int countShopeePay;
  final double totalKg;
  final double kgCilembuBakar;
  final int totalCilembuBakar;
  final double kgCilembuMentah;
  final int totalCilembuMentah;
  final double kgUngu;
  final int totalUngu;
  final double kgYakon;
  final int totalYakon;
  final int totalPengeluaran;

  const WhatsAppRecapData({
    required this.namaToko,
    required this.periode,
    this.namaPetugas,
    required this.totalPenjualan,
    this.jumlahTransaksi = 0,
    this.totalCash = 0,
    this.countCash = 0,
    this.totalQrisBJB = 0,
    this.countQris = 0,
    this.totalGoPay = 0,
    this.countGoPay = 0,
    this.totalShopeePay = 0,
    this.countShopeePay = 0,
    this.totalKg = 0,
    this.kgCilembuBakar = 0,
    this.totalCilembuBakar = 0,
    this.kgCilembuMentah = 0,
    this.totalCilembuMentah = 0,
    this.kgUngu = 0,
    this.totalUngu = 0,
    this.kgYakon = 0,
    this.totalYakon = 0,
    this.totalPengeluaran = 0,
  });

  int get totalDigital => totalQrisBJB + totalGoPay + totalShopeePay;
  int get countDigital => countQris + countGoPay + countShopeePay;
  int get kasBersih => totalPenjualan - totalPengeluaran;

  static String _fmt(num val) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    ).format(val).trim();
  }

  /// Membentuk teks WhatsApp yang rapi dan elegan
  String buildMessage() {
    final buffer = StringBuffer();
    buffer.writeln('📊 *REKAP PENJUALAN ${namaToko.toUpperCase()}*');
    buffer.writeln('📅 *Periode:* $periode');
    if (namaPetugas != null && namaPetugas!.isNotEmpty) {
      buffer.writeln('👤 *Petugas Kasir:* $namaPetugas');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 *Total Omset:* Rp ${_fmt(totalPenjualan)}');
    if (jumlahTransaksi > 0) {
      buffer.writeln('🧾 *Jumlah Transaksi:* $jumlahTransaksi Trx');
    }
    if (totalKg > 0) {
      buffer.writeln('📦 *Total Volume Ubi:* ${totalKg.toStringAsFixed(1)} Kg');
    }
    buffer.writeln('');

    // Metode Pembayaran
    buffer.writeln('💳 *Metode Pembayaran:*');
    final cashPct = totalPenjualan > 0 ? (totalCash / totalPenjualan * 100).toStringAsFixed(1) : '0';
    buffer.writeln('• Tunai (Cash): Rp ${_fmt(totalCash)} ($countCash trx / $cashPct%)');
    if (totalQrisBJB > 0 || countQris > 0) {
      buffer.writeln('• QRIS BJB: Rp ${_fmt(totalQrisBJB)} ($countQris trx)');
    }
    if (totalGoPay > 0 || countGoPay > 0) {
      buffer.writeln('• GoPay: Rp ${_fmt(totalGoPay)} ($countGoPay trx)');
    }
    if (totalShopeePay > 0 || countShopeePay > 0) {
      buffer.writeln('• ShopeePay: Rp ${_fmt(totalShopeePay)} ($countShopeePay trx)');
    }
    if (totalDigital > 0 && (totalGoPay > 0 || totalShopeePay > 0)) {
      final digPct = totalPenjualan > 0 ? (totalDigital / totalPenjualan * 100).toStringAsFixed(1) : '0';
      buffer.writeln('• Total Digital: Rp ${_fmt(totalDigital)} ($digPct%)');
    }
    buffer.writeln('');

    // Rincian Produk (jika ada data ubi)
    final hasProduct = totalCilembuBakar > 0 || totalCilembuMentah > 0 || totalUngu > 0 || totalYakon > 0;
    if (hasProduct) {
      buffer.writeln('🍠 *Rincian Produk Terjual:*');
      if (totalCilembuBakar > 0 || kgCilembuBakar > 0) {
        buffer.writeln('• Cilembu Bakar: ${kgCilembuBakar.toStringAsFixed(1)} Kg (Rp ${_fmt(totalCilembuBakar)})');
      }
      if (totalCilembuMentah > 0 || kgCilembuMentah > 0) {
        buffer.writeln('• Cilembu Mentah: ${kgCilembuMentah.toStringAsFixed(1)} Kg (Rp ${_fmt(totalCilembuMentah)})');
      }
      if (totalUngu > 0 || kgUngu > 0) {
        buffer.writeln('• Ubi Ungu: ${kgUngu.toStringAsFixed(1)} Kg (Rp ${_fmt(totalUngu)})');
      }
      if (totalYakon > 0 || kgYakon > 0) {
        buffer.writeln('• Ubi Yakon: ${kgYakon.toStringAsFixed(1)} Kg (Rp ${_fmt(totalYakon)})');
      }
      buffer.writeln('');
    }

    // Keuangan Kas
    buffer.writeln('💼 *Arus Kas & Operasional:*');
    buffer.writeln('• Penerimaan Omset: Rp ${_fmt(totalPenjualan)}');
    buffer.writeln('• Pengeluaran Operasional: Rp ${_fmt(totalPengeluaran)}');
    final isSurplus = kasBersih >= 0;
    buffer.writeln('• Estimasi Kas Bersih: Rp ${_fmt(kasBersih)} (${isSurplus ? "SURPLUS ✅" : "DEFISIT ⚠️"})');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('_Laporan otomatis dari Aplikasi Kasir Kasumba Sawelas_');

    return buffer.toString().trim();
  }
}

/// Service untuk menangani pengiriman pesan WhatsApp dan konfigurasi nomor Owner
class WhatsAppRecapService {
  static const String _keyOwnerPhone = 'owner_whatsapp_phone';

  /// Dapatkan nomor WhatsApp Owner yang tersimpan
  static Future<String> getOwnerPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyOwnerPhone) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Simpan nomor WhatsApp Owner
  static Future<void> setOwnerPhone(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyOwnerPhone, phone.trim());
    } catch (_) {}
  }

  /// Format nomor HP ke standar internasional Indonesia (cth: 081234 -> 6281234)
  static String normalizePhoneNumber(String phone) {
    var clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    } else if (clean.startsWith('8')) {
      clean = '62$clean';
    }
    return clean;
  }

  /// Buka aplikasi WhatsApp dengan pesan teks
  static Future<bool> sendToWhatsApp({
    required String message,
    String? targetPhone,
  }) async {
    final encodedText = Uri.encodeComponent(message);
    Uri targetUri;

    final phone = targetPhone != null && targetPhone.isNotEmpty
        ? normalizePhoneNumber(targetPhone)
        : '';

    if (phone.isNotEmpty) {
      // Buka langsung chat dengan nomor tujuan
      targetUri = Uri.parse('https://wa.me/$phone?text=$encodedText');
    } else {
      // Buka pemilih kontak WhatsApp
      targetUri = Uri.parse('whatsapp://send?text=$encodedText');
    }

    try {
      final launched = await launchUrl(
        targetUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && phone.isNotEmpty) {
        // Fallback jika https wa.me gagal
        final fallbackUri = Uri.parse('whatsapp://send?phone=$phone&text=$encodedText');
        return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } else if (!launched) {
        // Fallback untuk share generic
        final webFallback = Uri.parse('https://api.whatsapp.com/send?text=$encodedText');
        return await launchUrl(webFallback, mode: LaunchMode.externalApplication);
      }
      return launched;
    } catch (e) {
      // Fallback web api jika schema url bermasalah
      try {
        final fallbackUri = phone.isNotEmpty
            ? Uri.parse('https://api.whatsapp.com/send?phone=$phone&text=$encodedText')
            : Uri.parse('https://api.whatsapp.com/send?text=$encodedText');
        return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }

  /// Tampilkan BottomSheet Rekap dengan tombol 1-Click WhatsApp
  static void showRecapModal(BuildContext context, WhatsAppRecapData data) {
    showCustomRecapModal(
      context,
      storeName: data.namaToko,
      reportText: data.buildMessage(),
    );
  }

  /// Tampilkan BottomSheet Rekap dengan teks laporan kustom
  static void showCustomRecapModal(
    BuildContext context, {
    required String storeName,
    required String reportText,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecapModalWidget(
        storeName: storeName,
        reportText: reportText,
      ),
    );
  }
}

class _RecapModalWidget extends StatefulWidget {
  final String storeName;
  final String reportText;

  const _RecapModalWidget({
    required this.storeName,
    required this.reportText,
  });

  @override
  State<_RecapModalWidget> createState() => _RecapModalWidgetState();
}

class _RecapModalWidgetState extends State<_RecapModalWidget> {
  String _savedPhone = '';
  bool _isLoadingPhone = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    final phone = await WhatsAppRecapService.getOwnerPhone();
    if (mounted) {
      setState(() {
        _savedPhone = phone;
        _isLoadingPhone = false;
      });
    }
  }

  Future<void> _editPhoneDialog() async {
    final controller = TextEditingController(text: _savedPhone);
    final result = await showDialog<String>(
      context: context,
      builder: (dlgContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone_android_rounded, color: Color(0xFFFF8A00)),
            SizedBox(width: 10),
            Text(
              'Nomor WhatsApp Owner',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan nomor HP pemilik/tujuan laporan (contoh: 08123456789 atau 628123456789):',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Contoh: 08123456789',
                prefixIcon: const Icon(Icons.call_rounded, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8A00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(dlgContext, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result != null) {
      await WhatsAppRecapService.setOwnerPhone(result);
      if (mounted) {
        setState(() {
          _savedPhone = result;
        });
      }
    }
  }

  Future<void> _handleSendWhatsApp() async {
    Navigator.pop(context);
    final success = await WhatsAppRecapService.sendToWhatsApp(
      message: widget.reportText,
      targetPhone: _savedPhone,
    );

    if (!success && mounted) {
      Clipboard.setData(ClipboardData(text: widget.reportText));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF20251F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFFF8A00), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gagal membuka WhatsApp otomatis. Teks telah disalin ke clipboard!',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.reportText));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF20251F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF25D366), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Laporan berhasil disalin ke clipboard!',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
          const SizedBox(height: 14),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chat_rounded,
                      color: Color(0xFF1EBE5D),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rekap WhatsApp',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF20251F),
                        ),
                      ),
                      Text(
                        widget.storeName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Target Owner Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.send_rounded, size: 18, color: Color(0xFF25D366)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kirim ke:',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        _isLoadingPhone
                            ? 'Memuat...'
                            : (_savedPhone.isNotEmpty
                                ? _savedPhone
                                : 'Pilih kontak saat WhatsApp terbuka'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF20251F),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _editPhoneDialog,
                  icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFFFF8A00)),
                  label: Text(
                    _savedPhone.isEmpty ? 'Atur No HP' : 'Ubah',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFFF8A00), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Message Preview Container
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.reportText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.45,
                    color: Color(0xFF2E3842),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              // Copy Button
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF20251F),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _handleCopy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(
                    'Salin',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Send to WhatsApp Button (1-Click)
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: _handleSendWhatsApp,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'Kirim ke WA',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
