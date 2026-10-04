import 'package:flutter/material.dart';
import 'package:kasumbasawelas/core/price_config.dart';

class PengaturanHargaPage extends StatefulWidget {
  const PengaturanHargaPage({super.key});

  @override
  State<PengaturanHargaPage> createState() => _PengaturanHargaPageState();
}

class _PengaturanHargaPageState extends State<PengaturanHargaPage> {
  late TextEditingController _mentahCtrl;
  late TextEditingController _bakarCtrl;
  late TextEditingController _unguMentahCtrl;
  late TextEditingController _unguBakarCtrl;
  late TextEditingController _yakonCtrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _mentahCtrl = TextEditingController(
      text: PriceConfig.formatRupiah(PriceConfig.hargaMentah),
    );
    _bakarCtrl = TextEditingController(
      text: PriceConfig.formatRupiah(PriceConfig.hargaBakar),
    );
    _unguMentahCtrl = TextEditingController(
      text: PriceConfig.formatRupiah(PriceConfig.hargaUnguMentah),
    );
    _unguBakarCtrl = TextEditingController(
      text: PriceConfig.formatRupiah(PriceConfig.hargaUnguBakar),
    );
    _yakonCtrl = TextEditingController(
      text: PriceConfig.formatRupiah(PriceConfig.hargaYakon),
    );
  }

  @override
  void dispose() {
    _mentahCtrl.dispose();
    _bakarCtrl.dispose();
    _unguMentahCtrl.dispose();
    _unguBakarCtrl.dispose();
    _yakonCtrl.dispose();
    super.dispose();
  }

  int _parsePrice(TextEditingController ctrl, int fallback) {
    final clean = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? fallback;
  }

  void _formatControllerInput(TextEditingController controller) {
    final rawText = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawText.isEmpty) return;
    final intVal = int.tryParse(rawText) ?? 0;
    final formatted = PriceConfig.formatRupiah(intVal);

    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    final mentah = _parsePrice(_mentahCtrl, PriceConfig.defaultMentah);
    final bakar = _parsePrice(_bakarCtrl, PriceConfig.defaultBakar);
    final unguMentah = _parsePrice(
      _unguMentahCtrl,
      PriceConfig.defaultUnguMentah,
    );
    final unguBakar = _parsePrice(_unguBakarCtrl, PriceConfig.defaultUnguBakar);
    final yakon = _parsePrice(_yakonCtrl, PriceConfig.defaultYakon);

    await PriceConfig.savePrices(
      mentah: mentah,
      bakar: bakar,
      unguMentah: unguMentah,
      unguBakar: unguBakar,
      yakon: yakon,
    );

    setState(() => _isSaving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF20251F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF25D366),
              size: 22,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Harga ubi berhasil diperbarui dan langsung aktif!',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Color(0xFFFF8A00)),
            SizedBox(width: 10),
            Text(
              'Reset ke Standar?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Semua harga ubi akan dikembalikan ke harga default bawaan:\n'
          '• Mentah: Rp 26.000\n'
          '• Bakar: Rp 36.000\n'
          '• Ungu Mentah: Rp 25.000\n'
          '• Ungu Bakar: Rp 35.000\n'
          '• Yakon: Rp 35.000',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8A00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Kembalikan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PriceConfig.resetToDefault();
      setState(() {
        _mentahCtrl.text = PriceConfig.formatRupiah(PriceConfig.defaultMentah);
        _bakarCtrl.text = PriceConfig.formatRupiah(PriceConfig.defaultBakar);
        _unguMentahCtrl.text = PriceConfig.formatRupiah(
          PriceConfig.defaultUnguMentah,
        );
        _unguBakarCtrl.text = PriceConfig.formatRupiah(
          PriceConfig.defaultUnguBakar,
        );
        _yakonCtrl.text = PriceConfig.formatRupiah(PriceConfig.defaultYakon);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF20251F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Row(
            children: [
              Icon(
                Icons.restart_alt_rounded,
                color: Color(0xFFFF8A00),
                size: 22,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Harga telah di-reset ke nilai default standar!',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildPriceInputCard({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF20251F),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 125,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF20251F),
              ),
              onChanged: (_) => _formatControllerInput(controller),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: const Color(0xFFF7F8F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF8A00),
                    width: 1.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7F4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF20251F),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pengaturan Harga Ubi',
          style: TextStyle(
            color: Color(0xFF20251F),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset ke Bawaan',
            onPressed: _handleReset,
            icon: const Icon(
              Icons.restart_alt_rounded,
              color: Color(0xFFFF8A00),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            // Banner Info
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A00), Color(0xFFFFA726)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8A00).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Harga Per Kilogram (Kg)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Perubahan harga otomatis diterapkan pada Form Kasir semua cabang & OCR scanner.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Item Cards
            _buildPriceInputCard(
              title: 'Ubi Cilembu Bakar',
              subtitle: 'Kategori Ubi Cilembu (Bakar)',
              controller: _bakarCtrl,
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFE65100),
            ),
            _buildPriceInputCard(
              title: 'Ubi Cilembu Mentah',
              subtitle: 'Kategori Ubi Cilembu (Mentah)',
              controller: _mentahCtrl,
              icon: Icons.eco_rounded,
              iconColor: const Color(0xFF2E7D32),
            ),
            _buildPriceInputCard(
              title: 'Ubi Ungu Bakar',
              subtitle: 'Kategori Ubi Ungu (Bakar)',
              controller: _unguBakarCtrl,
              icon: Icons.local_fire_department_outlined,
              iconColor: const Color(0xFF7B1FA2),
            ),
            _buildPriceInputCard(
              title: 'Ubi Ungu Mentah',
              subtitle: 'Kategori Ubi Ungu (Mentah)',
              controller: _unguMentahCtrl,
              icon: Icons.spa_rounded,
              iconColor: const Color(0xFF9C27B0),
            ),
            _buildPriceInputCard(
              title: 'Ubi Yakon',
              subtitle: 'Kategori Ubi Yakon',
              controller: _yakonCtrl,
              icon: Icons.nature_rounded,
              iconColor: const Color(0xFF00897B),
            ),

            const SizedBox(height: 16),

            // Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20251F),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Simpan Perubahan Harga',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 12),

            // Helper Note
            Center(
              child: Text(
                'Data harga disimpan aman di memori perangkat lokal.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
