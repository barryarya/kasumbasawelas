import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:kasumbasawelas/keboiwa/transaksi_page.dart';
import 'package:kasumbasawelas/dalung/transaksi_page.dart';
import 'package:kasumbasawelas/nusadua/transaksi_page.dart';
import 'package:kasumbasawelas/core/price_config.dart';

class ScannedItemModel {
  String id;
  String jenis;
  String pembayaran;
  String channel;
  final TextEditingController beratController;
  final TextEditingController hargaController;
  final TextEditingController catatanController;
  final TextEditingController namaPemesanController;
  bool isSelected;
  bool isEditingBerat;
  bool isEditingHarga;

  ScannedItemModel({
    required this.id,
    required this.jenis,
    required this.pembayaran,
    this.channel = 'Toko',
    required String beratText,
    required String hargaText,
    String catatanText = '',
    String namaPemesanText = '',
    this.isSelected = true,
    this.isEditingBerat = false,
    this.isEditingHarga = false,
  }) : beratController = TextEditingController(text: beratText),
       hargaController = TextEditingController(text: hargaText),
       catatanController = TextEditingController(text: catatanText),
       namaPemesanController = TextEditingController(text: namaPemesanText);

  String get beratText => beratController.text;
  String get hargaText => hargaController.text;
  String get catatanText => catatanController.text;
  String get namaPemesanText => namaPemesanController.text;

  void dispose() {
    beratController.dispose();
    hargaController.dispose();
    catatanController.dispose();
    namaPemesanController.dispose();
  }
}

class ScanBukuPage extends StatefulWidget {
  final String tokoName;
  final String sheetUrl;
  final String namaPetugas;
  final bool bolehInput;
  final File? initialImageFile;

  const ScanBukuPage({
    super.key,
    required this.tokoName,
    required this.sheetUrl,
    required this.namaPetugas,
    this.bolehInput = true,
    this.initialImageFile,
  });

  @override
  State<ScanBukuPage> createState() => _ScanBukuPageState();
}

class _ScanBukuPageState extends State<ScanBukuPage> {
  final List<ScannedItemModel> _items = [];
  bool _isProcessingOcr = false;
  bool _isSending = false;
  String _rawOcrText = '';
  File? _selectedImage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialImageFile != null) {
      _selectedImage = widget.initialImageFile;
      _processImage(widget.initialImageFile!);
    } else {
      // Check for lost data (handles Android camera activity termination)
      _checkLostData();
    }
  }

  Future<void> _checkLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (!response.isEmpty) {
        final List<XFile>? files = response.files;
        if (files != null && files.isNotEmpty) {
          final file = File(files.first.path);
          setState(() {
            _selectedImage = file;
          });
          await _processImage(file);
          return;
        } else if (response.file != null) {
          final file = File(response.file!.path);
          setState(() {
            _selectedImage = file;
          });
          await _processImage(file);
          return;
        }
      }
    } catch (_) {}

    // Show source dialog only if no image is already processing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _items.isEmpty &&
          !_isProcessingOcr &&
          _selectedImage == null) {
        _showImageSourceDialog();
      }
    });
  }

  @override
  void dispose() {
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  int getHargaPerKg(String jenis) => NoteOcrParser.getHargaPerKg(jenis);
  double round1Decimal(double value) => NoteOcrParser.round1Decimal(value);
  int roundUpToThousand(int value) => NoteOcrParser.roundUpToThousand(value);
  String formatRupiah(int angka) => NoteOcrParser.formatRupiah(angka);
  double parseBeratToDouble(String input) =>
      NoteOcrParser.parseBeratToDouble(input);
  String convertBerat(String input) => NoteOcrParser.convertBerat(input);

  void _showImageSourceDialog() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Pilih Sumber Foto Catatan",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Foto buku catatan penjualan Anda. Tulisan tangan jenis, harga, dan tanda petik dua (\") akan otomatis dideteksi.",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2474E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Color(0xFF2474E5),
                    ),
                  ),
                  title: const Text(
                    "Ambil Foto (Kamera)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Buka kamera untuk memfoto buku catatan",
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Future.delayed(const Duration(milliseconds: 250));
                    if (mounted) _pickAndProcessImage(ImageSource.camera);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A00).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Color(0xFFFF8A00),
                    ),
                  ),
                  title: const Text(
                    "Pilih dari Galeri",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Pilih foto catatan yang sudah ada di galeri",
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Future.delayed(const Duration(milliseconds: 250));
                    if (mounted) _pickAndProcessImage(ImageSource.gallery);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.purple,
                    ),
                  ),
                  title: const Text(
                    "Input / Tempel Teks Manual",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Ketik atau tempel teks catatan penjualan",
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRawTextDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 2000,
        imageQuality: 85,
      );

      if (image == null) return;

      final file = File(image.path);
      setState(() {
        _selectedImage = file;
      });

      await _processImage(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal mengambil gambar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processImage(File file) async {
    setState(() {
      _isProcessingOcr = true;
    });

    try {
      final inputImage = InputImage.fromFile(file);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      await textRecognizer.close();

      // Collect all text lines with precise coordinates
      List<OcrLineItem> allLines = [];
      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          final top = line.boundingBox.top.toDouble();
          final bottom = line.boundingBox.bottom.toDouble();
          final left = line.boundingBox.left.toDouble();
          final right = line.boundingBox.right.toDouble();
          final height = (bottom - top).abs();

          allLines.add(
            OcrLineItem(
              text: line.text,
              top: top,
              bottom: bottom,
              left: left,
              right: right,
              height: height > 0 ? height : 20.0,
              centerY: (top + bottom) / 2,
            ),
          );
        }
      }

      final combinedRows = NoteOcrParser.groupOcrLinesToRows(allLines);
      _rawOcrText = combinedRows.isNotEmpty
          ? combinedRows.join('\n')
          : recognizedText.text;
      _parseOcrTextToItems(_rawOcrText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal membaca teks dari foto: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOcr = false;
        });
      }
    }
  }

  void _parseOcrTextToItems(String fullText) {
    for (var it in _items) {
      it.dispose();
    }
    _items.clear();

    final parsedItems = NoteOcrParser.parseFullText(fullText);
    for (var item in parsedItems) {
      _attachListeners(item);
      _items.add(item);
    }

    if (_items.isEmpty && fullText.trim().isNotEmpty) {
      final fallback = ScannedItemModel(
        id: "1",
        jenis: "Bakar",
        pembayaran: "Cash",
        beratText: "1.0",
        hargaText: formatRupiah(PriceConfig.getHargaPerKg("Bakar")),
        catatanText: fullText.trim().length > 50
            ? fullText.trim().substring(0, 50)
            : fullText.trim(),
      );
      _attachListeners(fallback);
      _items.add(fallback);
    }

    setState(() {});
  }

  void _attachListeners(ScannedItemModel item) {
    // When Berat is edited by user -> auto update Harga
    item.beratController.addListener(() {
      if (item.isEditingHarga) return;
      if (item.beratController.text.isEmpty) return;

      item.isEditingBerat = true;
      double berat = parseBeratToDouble(item.beratController.text);
      double beratRounded = round1Decimal(berat);
      int pricePerKg = getHargaPerKg(item.jenis);
      int total = roundUpToThousand((beratRounded * pricePerKg).round());

      final newHarga = formatRupiah(total);
      if (item.hargaController.text != newHarga) {
        item.hargaController.text = newHarga;
      }
      item.isEditingBerat = false;
      if (mounted) setState(() {});
    });

    // When Harga is edited by user -> auto update Berat
    item.hargaController.addListener(() {
      if (item.isEditingBerat) return;
      if (item.hargaController.text.isEmpty) return;

      item.isEditingHarga = true;
      String clean = item.hargaController.text
          .replaceAll('.', '')
          .replaceAll(',', '');
      int harga = int.tryParse(clean) ?? 0;
      if (harga > 0) {
        int pricePerKg = getHargaPerKg(item.jenis);
        double berat = round1Decimal(harga / pricePerKg);
        String formattedBerat = berat.toStringAsFixed(1).replaceAll('.', ',');
        if (formattedBerat.endsWith(',0')) {
          formattedBerat = berat.toInt().toString();
        }
        if (item.beratController.text != formattedBerat) {
          item.beratController.text = formattedBerat;
        }
      }
      item.isEditingHarga = false;
      if (mounted) setState(() {});
    });
  }

  void _addNewManualItem() {
    final newItem = ScannedItemModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      jenis: "Bakar",
      pembayaran: "Cash",
      channel: "Toko",
      beratText: "1.0",
      hargaText: formatRupiah(PriceConfig.getHargaPerKg("Bakar")),
      catatanText: "",
    );
    _attachListeners(newItem);
    setState(() {
      _items.add(newItem);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  void _recalculateAllPrices() {
    for (var item in _items) {
      double berat = parseBeratToDouble(item.beratController.text);
      double beratRounded = round1Decimal(berat);
      int pricePerKg = getHargaPerKg(item.jenis);
      int total = roundUpToThousand((beratRounded * pricePerKg).round());

      item.hargaController.text = formatRupiah(total);
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Semua harga berhasil dihitung ulang sesuai berat & jenis ubi",
        ),
      ),
    );
  }

  int get _selectedCount => _items.where((i) => i.isSelected).length;

  int get _totalNominal {
    int total = 0;
    for (var item in _items) {
      if (item.isSelected) {
        int h =
            int.tryParse(item.hargaController.text.replaceAll('.', '')) ?? 0;
        total += h;
      }
    }
    return total;
  }

  double get _totalBerat {
    double total = 0;
    for (var item in _items) {
      if (item.isSelected) {
        total += parseBeratToDouble(item.beratController.text);
      }
    }
    return round1Decimal(total);
  }

  void _showRawTextDialog() {
    final textController = TextEditingController(text: _rawOcrText);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Row(
                  children: [
                    Icon(Icons.text_snippet_rounded, color: Color(0xFF2474E5)),
                    SizedBox(width: 8),
                    Text(
                      "Teks Catatan OCR",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Scrollable content area
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Edit atau tempel teks catatan penjualan (gunakan tanda petik dua \" untuk mewakili produk baris di atasnya):",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: textController,
                          maxLines: null,
                          minLines: 6,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText:
                                "Contoh:\nUbi Bakar 35.000 Cash\n\" 10.000 QRIS\nMentah 11.000 Cash\n\" 15.000 QRIS",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Batal"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text("Deteksi Ulang"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2474E5),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        _rawOcrText = textController.text;
                        _parseOcrTextToItems(_rawOcrText);
                        Navigator.pop(ctx);
                      },
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

  void _showPhotoPreviewDialog() {
    if (_selectedImage == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text(
                "Foto Asli Buku Catatan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0.5,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 500),
              padding: const EdgeInsets.all(8),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(_selectedImage!, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _kirimSemuaData() async {
    if (!widget.bolehInput) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Anda hanya memiliki hak akses melihat, tidak bisa input.",
          ),
        ),
      );
      return;
    }

    final selectedItems = _items.where((i) => i.isSelected).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pilih minimal 1 data transaksi untuk dikirim"),
        ),
      );
      return;
    }

    // Confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Konfirmasi Kirim"),
        content: Text(
          "Apakah Anda yakin ingin mengirim ${selectedItems.length} data transaksi penjualan senilai ${formatRupiah(_totalNominal)} ke Google Sheet ${widget.tokoName}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20251F),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ya, Kirim Semua"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSending = true;
    });

    int berhasil = 0;
    int gagal = 0;

    // Show persistent progress dialog
    final ValueNotifier<String> progressMessage = ValueNotifier(
      "Menyiapkan pengiriman data...",
    );
    final ValueNotifier<double> progressValue = ValueNotifier(0.0);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: progressValue,
                    builder: (_, val, __) => LinearProgressIndicator(
                      value: val > 0 ? val : null,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFFFF8A00),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<String>(
                    valueListenable: progressMessage,
                    builder: (_, msg, __) => Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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

    for (int i = 0; i < selectedItems.length; i++) {
      final item = selectedItems[i];
      progressMessage.value =
          "Mengirim ${i + 1} dari ${selectedItems.length} transaksi...";
      progressValue.value = (i + 1) / selectedItems.length;

      int hargaBersih =
          int.tryParse(item.hargaController.text.replaceAll('.', '')) ?? 0;

      final data = {
        "type": "penjualan",
        "tanggal": DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        "petugas": widget.namaPetugas,
        "berat": convertBerat(item.beratController.text),
        "jenis": item.jenis,
        "channel": item.channel,
        "nama_pemesan":
            (item.channel == 'ShopeeFood' || item.channel == 'GoFood')
            ? item.namaPemesanController.text
            : '',
        "pembayaran": item.pembayaran,
        "harga": hargaBersih,
        "catatan": item.catatanController.text,
      };

      try {
        final response = await http
            .post(
              Uri.parse(widget.sheetUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 || response.statusCode == 302) {
          berhasil++;
        } else {
          berhasil++; // Google Script redirects
        }
      } catch (e) {
        gagal++;
      }

      // Small delay between posts to prevent rate-limit
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (!mounted) return;
    Navigator.pop(context); // Close progress dialog

    setState(() {
      _isSending = false;
    });

    // Show result dialog
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                gagal == 0 ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: gagal == 0 ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(gagal == 0 ? "Pengiriman Berhasil" : "Selesai"),
            ],
          ),
          content: Text(
            "Berhasil mengirim $berhasil data transaksi.${gagal > 0 ? '\n$gagal data gagal dikirim, silakan periksa koneksi.' : ''}",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Return to sales form
              },
              child: const Text("Tutup"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A00),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Widget targetPage;
                if (widget.tokoName.contains("Dalung")) {
                  targetPage = const TransaksiDalungPage();
                } else if (widget.tokoName.contains("Nusa Dua")) {
                  targetPage = const TransaksiNusaDuaPage();
                } else {
                  targetPage = const TransaksiPage();
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => targetPage),
                );
              },
              child: const Text("Lihat Riwayat Transaksi"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Scan Catatan Buku",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              "${widget.tokoName} • Petugas: ${widget.namaPetugas}",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (_selectedImage != null)
            IconButton(
              tooltip: "Lihat Foto Asli",
              icon: const Icon(Icons.image_rounded, color: Color(0xFF3D8B55)),
              onPressed: _showPhotoPreviewDialog,
            ),
          IconButton(
            tooltip: "Lihat / Edit Teks OCR",
            icon: const Icon(
              Icons.text_snippet_rounded,
              color: Color(0xFF2474E5),
            ),
            onPressed: _showRawTextDialog,
          ),
          IconButton(
            tooltip: "Ganti Foto / Kamera",
            icon: const Icon(
              Icons.add_a_photo_rounded,
              color: Color(0xFFFF8A00),
            ),
            onPressed: _showImageSourceDialog,
          ),
        ],
      ),
      body: _isProcessingOcr
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFFF8A00)),
                  const SizedBox(height: 20),
                  const Text(
                    "Sedang membaca catatan dari foto...",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Mendeteksi baris transaksi, tanda petik (\"), harga & metode pembayaran",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Top Summary Card
                _buildSummaryCard(),

                // Action Bar (Select All, Add Manual, Recalculate)
                _buildControlBar(),

                // List of Detected Items
                Expanded(
                  child: _items.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            return _buildItemCard(index, _items[index]);
                          },
                        ),
                ),
              ],
            ),
      bottomSheet: _items.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$_selectedCount dari ${_items.length} dipilih",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            "Rp ${formatRupiah(_totalNominal)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF8A00),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSending ? null : _kirimSemuaData,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSending
                            ? "Mengirim..."
                            : "Kirim Semua ($_selectedCount)",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20251F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF20251F), Color(0xFF343B32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryColumn(
            "TOTAL DATA",
            "${_items.length} Baris",
            Icons.receipt_long_rounded,
          ),
          Container(width: 1, height: 36, color: Colors.white24),
          _buildSummaryColumn(
            "TOTAL BERAT",
            "$_totalBerat kg",
            Icons.scale_rounded,
          ),
          Container(width: 1, height: 36, color: Colors.white24),
          _buildSummaryColumn(
            "TOTAL HARGA",
            "Rp ${formatRupiah(_totalNominal)}",
            Icons.payments_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFFFF8A00)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildControlBar() {
    final bool allSelected =
        _items.isNotEmpty && _items.every((i) => i.isSelected);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Select All Checkbox
          InkWell(
            onTap: () {
              setState(() {
                final newValue = !allSelected;
                for (var it in _items) {
                  it.isSelected = newValue;
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected,
                  activeColor: const Color(0xFFFF8A00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (val) {
                    setState(() {
                      for (var it in _items) {
                        it.isSelected = val ?? true;
                      }
                    });
                  },
                ),
                const Text(
                  "Pilih Semua",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Recalculate Prices Button
          TextButton.icon(
            icon: const Icon(
              Icons.refresh_rounded,
              size: 16,
              color: Color(0xFF2474E5),
            ),
            label: const Text(
              "Hitung Ulang",
              style: TextStyle(fontSize: 12, color: Color(0xFF2474E5)),
            ),
            onPressed: _recalculateAllPrices,
          ),
          const SizedBox(width: 4),
          // Add Manual Item Button
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              "Tambah Baris",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8A00),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _addNewManualItem,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2474E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                size: 40,
                color: Color(0xFF2474E5),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Belum Ada Catatan Terdeteksi",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              "Ambil foto buku catatan penjualan atau ketik transaksi manual.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text("Foto / Scan"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2474E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _addNewManualItem,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text("Tambah Manual"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index, ScannedItemModel item) {
    Color badgeColor = const Color(0xFFFF8A00);
    if (item.jenis.contains('Ungu')) {
      badgeColor = const Color(0xFF7545B8);
    } else if (item.jenis.contains('Yakon')) {
      badgeColor = const Color(0xFF3D8B55);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isSelected
              ? badgeColor.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: item.isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header: Checkbox, Badge Index, Jenis Dropdown, Delete Button
            Row(
              children: [
                Checkbox(
                  value: item.isSelected,
                  activeColor: badgeColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (val) {
                    setState(() {
                      item.isSelected = val ?? true;
                    });
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "#${index + 1}",
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: item.jenis,
                    isDense: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Bakar',
                        child: Text(
                          'Cilembu Bakar',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Mentah',
                        child: Text(
                          'Cilembu Mentah',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Ubi Ungu Bakar',
                        child: Text(
                          'Ungu Bakar',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Ubi Ungu Mentah',
                        child: Text(
                          'Ungu Mentah',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Ubi Yakon',
                        child: Text(
                          'Ubi Yakon',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          item.jenis = val;
                          String clean = item.hargaController.text
                              .replaceAll('.', '')
                              .replaceAll(',', '');
                          int harga = int.tryParse(clean) ?? 0;
                          if (harga > 0) {
                            int pricePerKg = getHargaPerKg(val);
                            double b = round1Decimal(harga / pricePerKg);
                            String strB = b
                                .toStringAsFixed(1)
                                .replaceAll('.', ',');
                            if (strB.endsWith(',0')) {
                              strB = b.toInt().toString();
                            }
                            item.beratController.text = strB;
                          }
                        });
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row: Harga & Berat
            Row(
              children: [
                // Harga Input (Primary in ledger notes)
                Expanded(
                  flex: 6,
                  child: TextFormField(
                    controller: item.hargaController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Harga (Rp)",
                      prefixText: "Rp ",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Berat Input
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: item.beratController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: "Berat (kg)",
                      hintText: "1.0",
                      suffixText: "kg",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row: Pembayaran & Channel
            Row(
              children: [
                // Pembayaran Dropdown
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    initialValue: item.pembayaran,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: "Pembayaran",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Cash',
                        child: Text('Cash', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'QRIS BJB',
                        child: Text('QRIS BJB', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'ShopeePay',
                        child: Text(
                          'ShopeePay',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'GoPay',
                        child: Text('GoPay', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          item.pembayaran = val;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Channel Dropdown
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    initialValue: item.channel,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: "Channel",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Toko',
                        child: Text('Toko', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'ShopeeFood',
                        child: Text(
                          'ShopeeFood',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'GoFood',
                        child: Text('GoFood', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          item.channel = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            // Optional Nama Pemesan if Online
            if (item.channel == 'ShopeeFood' || item.channel == 'GoFood') ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: item.namaPemesanController,
                decoration: InputDecoration(
                  labelText: "Nama Pemesan (${item.channel})",
                  hintText: "Contoh: Bpk Budi",
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Optional Catatan
            TextFormField(
              controller: item.catatanController,
              decoration: InputDecoration(
                labelText: "Catatan Tambahan (Opsional)",
                hintText: "Keterangan...",
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OcrLineItem {
  final String text;
  final double top;
  final double left;
  final double bottom;
  final double right;
  final double height;
  final double centerY;

  OcrLineItem({
    required this.text,
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
    required this.height,
    required this.centerY,
  });
}

class NoteOcrParser {
  static int getHargaPerKg(String jenis) => PriceConfig.getHargaPerKg(jenis);

  static double round1Decimal(double value) {
    return double.parse(value.toStringAsFixed(1));
  }

  static int roundUpToThousand(int value) {
    return ((value / 1000).ceil()) * 1000;
  }

  static String formatRupiah(int angka) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(angka);
  }

  static double parseBeratToDouble(String input) {
    input = input.trim().replaceAll(',', '.');

    // contoh: 1 1/4 atau 1 1/2
    if (input.contains(' ')) {
      final parts = input.split(' ');
      if (parts.length == 2) {
        final angkaUtuh = double.tryParse(parts[0]) ?? 0;
        if (parts[1].contains('/')) {
          final pecahan = parts[1].split('/');
          if (pecahan.length == 2) {
            final pembilang = double.tryParse(pecahan[0]) ?? 0;
            final penyebut = double.tryParse(pecahan[1]) ?? 1;
            return angkaUtuh + (pembilang / penyebut);
          }
        }
      }
    }

    // contoh: 1/4 atau 1/2
    if (input.contains('/')) {
      final pecahan = input.split('/');
      if (pecahan.length == 2) {
        final pembilang = double.tryParse(pecahan[0]) ?? 0;
        final penyebut = double.tryParse(pecahan[1]) ?? 1;
        return pembilang / penyebut;
      }
    }

    return double.tryParse(input) ?? 0;
  }

  static String convertBerat(String input) {
    input = input.trim().replaceAll(',', '.');

    if (input.contains(' ')) {
      final parts = input.split(' ');
      if (parts.length == 2) {
        final angkaUtuh = double.tryParse(parts[0]) ?? 0;
        if (parts[1].contains('/')) {
          final pecahan = parts[1].split('/');
          if (pecahan.length == 2) {
            final pembilang = double.tryParse(pecahan[0]) ?? 0;
            final penyebut = double.tryParse(pecahan[1]) ?? 1;
            return (angkaUtuh + (pembilang / penyebut)).toString().replaceAll(
              '.',
              ',',
            );
          }
        }
      }
    }

    if (input.contains('/')) {
      final pecahan = input.split('/');
      if (pecahan.length == 2) {
        final pembilang = double.tryParse(pecahan[0]) ?? 0;
        final penyebut = double.tryParse(pecahan[1]) ?? 1;
        return (pembilang / penyebut).toString().replaceAll('.', ',');
      }
    }

    return input.replaceAll('.', ',');
  }

  static String normalizeOcrText(String input) {
    var text = input;

    // 1. Replace common ditto mark variants
    text = text.replaceAll(RegExp(r'["“”„‟]'), '"');
    text = text.replaceAll(RegExp(r"['’‘]{2}"), '"');
    text = text.replaceAll(RegExp(r'[,]{2,}'), '"');
    text = text.replaceAll(RegExp(r'[\^]{1,2}'), '"');

    // 2. Fix handwritten OCR misreads of prices like "u.000", "u.ooo", "ll.000", "11.060", "10.ooo"
    // e.g. "u.000" or "u.ooo" -> "11.000" (two 1s joined at bottom in handwriting)
    text = text.replaceAllMapped(
      RegExp(r'\b[uUvV][\.\-\s,]([0-9oO]{3})\b'),
      (m) => '11.${m.group(1)!.replaceAll(RegExp(r'[oO]'), '0')}',
    );

    // e.g. "ll.000" or "l1.000" or "1l.000" or "ii.000" or "il.000" -> "11.000"
    text = text.replaceAllMapped(
      RegExp(
        r'\b(?:ll|l1|1l|ii|il|li)[\.\-\s,]([0-9oO]{3})\b',
        caseSensitive: false,
      ),
      (m) => '11.${m.group(1)!.replaceAll(RegExp(r'[oO]'), '0')}',
    );

    // e.g. "lo.ooo" or "io.ooo" or "1o.ooo" -> "10.000"
    text = text.replaceAllMapped(
      RegExp(r'\b(?:lo|io|1o|10)[\.\-\s,]([0-9oO]{3})\b', caseSensitive: false),
      (m) => '10.${m.group(1)!.replaceAll(RegExp(r'[oO]'), '0')}',
    );

    // e.g. "l5.000" or "is.ooo" or "i5.ooo" -> "15.000"
    text = text.replaceAllMapped(
      RegExp(r'\b(?:l5|is|i5|15)[\.\-\s,]([0-9oO]{3})\b', caseSensitive: false),
      (m) => '15.${m.group(1)!.replaceAll(RegExp(r'[oO]'), '0')}',
    );

    // e.g. "2o.ooo" -> "20.000"
    text = text.replaceAllMapped(
      RegExp(r'\b(?:2o|20)[\.\-\s,]([0-9oO]{3})\b', caseSensitive: false),
      (m) => '20.${m.group(1)!.replaceAll(RegExp(r'[oO]'), '0')}',
    );

    // e.g. "3s.ooo" or "35.ooo" -> "35.000"
    text = text.replaceAllMapped(
      RegExp(r'\b(?:3s|35)[\.\-\s,]([0-9oO]{3})\b', caseSensitive: false),
      (m) => '35.${m.group(1)!.replaceAll(RegExp(r'[oO]'), '0')}',
    );

    // Replace letter 'o' or 'O' in 3-digit thousand separators (e.g. ".ooo" -> ".000", ".060" -> ".000")
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{1,3})[\.\-\s,]([0-9oO]{3})\b'),
      (m) {
        String num = m.group(1)!;
        String thousand = m.group(2)!.replaceAll(RegExp(r'[oO]'), '0');
        // Handle common handwriting loop artifacts on zero e.g. 060, 0b0, 080
        if (thousand == '060' || thousand == '0b0' || thousand == '080') {
          thousand = '000';
        }
        return '$num.$thousand';
      },
    );

    return text;
  }

  static String cleanLine(String line) {
    var text = line.trim();
    // Strip leading row numbering like "1. ", "2) ", "No. 1 ", "1 - "
    // Be careful NOT to strip prices like "11.000" or "10.000"
    text = text.replaceAll(
      RegExp(
        r'^(?:no\.?\s*)?\d{1,2}[\.\)\-\:]\s+(?!\d{2,})',
        caseSensitive: false,
      ),
      '',
    );
    return text.trim();
  }

  static bool isHeaderOrNoise(String line) {
    final lower = line.trim().toLowerCase();
    if (lower.isEmpty) return true;
    if (lower.startsWith('laporan') ||
        lower.startsWith('catatan') ||
        lower.startsWith('penjualan') ||
        lower.startsWith('kasumba') ||
        lower.startsWith('tanggal') ||
        lower.startsWith('total') ||
        lower.startsWith('petugas') ||
        lower.startsWith('rekap') ||
        lower == '---' ||
        lower == '***' ||
        lower == '===') {
      return true;
    }

    // Ignore Date lines (e.g. "31 Agustus 2024", "31 Agushis 2024", "31/08/2024", "31-08-2024")
    if (RegExp(
          r'^\d{1,2}\s+(?:jan|feb|mar|apr|mei|jun|jul|agu|agt|sep|okt|nov|des|[a-z]{3,9})\s*(?:\d{2,4})?',
          caseSensitive: false,
        ).hasMatch(lower) ||
        RegExp(r'^\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}').hasMatch(lower) ||
        RegExp(
          r'^(?:senin|selasa|rabu|kamis|jumat|sabtu|minggu)\b',
          caseSensitive: false,
        ).hasMatch(lower)) {
      if (!RegExp(r'\b\d{1,3}[\.,]\d{3}\b').hasMatch(lower)) {
        return true;
      }
    }

    return false;
  }

  static bool isDittoMark(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.startsWith('"') ||
        lower.startsWith('\'') ||
        lower.startsWith('”') ||
        lower.startsWith('“') ||
        lower.startsWith('„') ||
        lower.startsWith(',,') ||
        lower.startsWith('^') ||
        lower.startsWith('((') ||
        lower.startsWith('))') ||
        lower.startsWith('=') ||
        lower.startsWith('-') ||
        lower.startsWith('~') ||
        RegExp(r'^(?:["]|["]{1,2}|[,]{2}|\^{1,2})\b').hasMatch(lower) ||
        RegExp(r'^(?:[uUvV]{1,2}|11|ll|ii|1|l|i)\s+').hasMatch(lower)) {
      return true;
    }
    return false;
  }

  static String detectJenis(String text, String currentProduct) {
    final lower = text.toLowerCase();

    // Check Ubi Ungu Mentah
    if (lower.contains('ungu mentah') ||
        lower.contains('ungu mth') ||
        lower.contains('ungumentah') ||
        (lower.contains('ungu') &&
            (lower.contains('mentah') ||
                lower.contains('mth') ||
                lower.contains('raw')))) {
      return 'Ubi Ungu Mentah';
    }

    // Check Ubi Ungu Bakar
    if (lower.contains('ungu bakar') ||
        lower.contains('ungu bkr') ||
        lower.contains('ungubakar') ||
        lower.contains('ubi ungu') ||
        (lower.contains('ungu') && !lower.contains('mentah'))) {
      return 'Ubi Ungu Bakar';
    }

    // Check Ubi Yakon
    if (lower.contains('yakon') ||
        lower.contains('yacon') ||
        lower.contains('jakon') ||
        lower.contains('yacun')) {
      return 'Ubi Yakon';
    }

    // Check Mentah (handles common OCR handwriting misreads like menta4, mertah, mehtah, montah, mntah, mental, etc.)
    if (lower.contains('mentah') ||
        lower.contains('menta') ||
        lower.contains('mertah') ||
        lower.contains('mehtah') ||
        lower.contains('montah') ||
        lower.contains('memtah') ||
        lower.contains('mntah') ||
        lower.contains('mnta') ||
        lower.contains('mentak') ||
        lower.contains('mentan') ||
        lower.contains('mental') ||
        lower.contains('metah') ||
        lower.contains('mth') ||
        lower.contains('raw') ||
        RegExp(
          r'\b(?:m[eoa3u]?[rnmtwv][tli1][a4o0e][hk4n]?|mth|raw)\b',
          caseSensitive: false,
        ).hasMatch(text) ||
        RegExp(
          r'\bm[eoa]?n?t[aeo][hk4n]?\b',
          caseSensitive: false,
        ).hasMatch(text)) {
      return 'Mentah';
    }

    // Check Bakar
    if (lower.contains('ubi bakar') ||
        lower.contains('ubakar') ||
        lower.contains('bakar') ||
        lower.contains('bkr') ||
        lower.contains('bakr') ||
        lower.contains('bkar') ||
        lower.contains('rakar') ||
        lower.contains('pakar') ||
        lower.contains('dakar') ||
        lower.contains('batar') ||
        lower.contains('bolar') ||
        lower.contains('balcar') ||
        lower.contains('panggang') ||
        lower.contains('matang') ||
        RegExp(
          r'\b(?:b[a4o]k[a4e]r?|bkr|rakar|pakar|dakar)\b',
          caseSensitive: false,
        ).hasMatch(text)) {
      return 'Bakar';
    }

    // Check Cilembu
    if (lower.contains('cilembu') && !isDittoMark(text)) {
      return 'Bakar';
    }

    // Default: Inherits ONLY the product type from row above (tanda petik / ditto / baris tanpa nama produk)
    return currentProduct;
  }

  static String detectPembayaran(String text) {
    final lower = text.toLowerCase();

    // Check QRIS variants (including handwriting misreads: QR15, QRI5, QK15, Qk1s, Qf1s, QFIS, Q15, ORIS, 0RIS, OR15, KRIS, KR15, CRIS, ARIS, BJB, QR)
    if (RegExp(
          r'\b(?:q[rfk4p]i?s|qris|aris|gris|oris|kris|bjb|qr|q[rfk4p]1[5s]|qr15|qri5|qk15|qf1s|qk1s|qfis|q15|qis|or15|0r15|kr15|cr15|ar15|0ris|q215|qrie|qrse)\b',
          caseSensitive: false,
        ).hasMatch(text) ||
        lower.contains('qris') ||
        lower.contains('qr15') ||
        lower.contains('qri5') ||
        lower.contains('qk15') ||
        lower.contains('qkis') ||
        lower.contains('qfis') ||
        lower.contains('qf1s') ||
        lower.contains('qk1s') ||
        lower.contains('q15') ||
        lower.contains('aris') ||
        lower.contains('oris') ||
        lower.contains('kris') ||
        lower.contains('cris') ||
        lower.contains('bjb') ||
        lower.contains('qr')) {
      return 'QRIS BJB';
    } else if (lower.contains('shopeepay') ||
        lower.contains('spay') ||
        lower.contains('s-pay') ||
        (lower.contains('shopee') && !lower.contains('shopeefood'))) {
      return 'ShopeePay';
    } else if (lower.contains('gopay') ||
        lower.contains('go-pay') ||
        lower.contains('gp') ||
        lower.contains('go pay')) {
      return 'GoPay';
    } else if (lower.contains('cash') ||
        lower.contains('casn') ||
        lower.contains('csh') ||
        lower.contains('cosh') ||
        lower.contains('cas') ||
        lower.contains('cah') ||
        lower.contains('tunai') ||
        lower.contains('uang') ||
        RegExp(
          r'\b(?:c[ao]s[hn]?|csh|kash|tunai|uang|cs)\b',
          caseSensitive: false,
        ).hasMatch(text)) {
      return 'Cash';
    }

    return 'Cash';
  }

  static String detectChannel(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('shopeefood') ||
        lower.contains('shopee food') ||
        lower.contains('sf')) {
      return 'ShopeeFood';
    } else if (lower.contains('gofood') ||
        lower.contains('go food') ||
        lower.contains('gf')) {
      return 'GoFood';
    }
    return 'Toko';
  }

  static int? extractHarga(String text) {
    // Normalize and clean handwriting OCR errors first
    String normalized = normalizeOcrText(text);

    // 1. Format with 'k' or 'rb' (e.g. 35k, 10rb)
    final priceMatchK = RegExp(
      r'(\d+)\s*(?:k|rb)\b',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (priceMatchK != null) {
      int? val = int.tryParse(priceMatchK.group(1)!);
      if (val != null) {
        return val * 1000;
      }
    }

    // 2. Format with dot/dash/space/comma separator (e.g. "35.000", "10.000", "11.000", "15.000", "20.000")
    final sepPriceMatch = RegExp(
      r'\b(\d{1,3})[\.\-\s,]([0-9oO]{3})\b',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (sepPriceMatch != null) {
      String num1 = sepPriceMatch.group(1)!;
      String num2 = sepPriceMatch.group(2)!.replaceAll(RegExp(r'[oO]'), '0');
      int? val = int.tryParse("$num1$num2");
      if (val != null && val >= 3000) {
        if (val % 1000 != 0 && val % 100 != 0) {
          val = ((val + 500) ~/ 1000) * 1000;
        }
        return val;
      }
    }

    // 3. Raw integer price >= 3000 (e.g. 36000, 10000, 15000, 20000)
    final rawPriceMatch = RegExp(r'\b(\d{4,6})\b').allMatches(normalized);
    for (var m in rawPriceMatch) {
      int? val = int.tryParse(m.group(1)!);
      if (val != null && val >= 3000) {
        return val;
      }
    }

    return null;
  }

  static double? extractBerat(String text) {
    // Mixed fraction: "1 1/2", "1 1/4"
    final mixedFracMatch = RegExp(
      r'\b(\d+)\s+(\d+)\s*/\s*(\d+)\b',
    ).firstMatch(text);
    if (mixedFracMatch != null) {
      double whole = double.tryParse(mixedFracMatch.group(1)!) ?? 0;
      double num = double.tryParse(mixedFracMatch.group(2)!) ?? 0;
      double den = double.tryParse(mixedFracMatch.group(3)!) ?? 1;
      return whole + (num / den);
    }

    // Simple fraction: "1/2", "1/4", "3/4"
    final fracMatch = RegExp(r'\b(\d+)\s*/\s*(\d+)\b').firstMatch(text);
    if (fracMatch != null) {
      double num = double.tryParse(fracMatch.group(1)!) ?? 0;
      double den = double.tryParse(fracMatch.group(2)!) ?? 1;
      return num / den;
    }

    // Explicit with kg: "1.5 kg", "2kg", "500 gr"
    final explicitKgMatch = RegExp(
      r'\b(\d+[\.,]\d+|\d+)\s*(?:kg|kilo|gr|gram)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (explicitKgMatch != null) {
      String numStr = explicitKgMatch.group(1)!.replaceAll(',', '.');
      double? b = double.tryParse(numStr);
      if (b != null) {
        if (explicitKgMatch.group(0)!.toLowerCase().contains('gr') ||
            explicitKgMatch.group(0)!.toLowerCase().contains('gram')) {
          if (b >= 50) b = b / 1000;
        }
        return b;
      }
    }

    // Standalone decimal weight (< 20, e.g. 1.5, 0.5, 2.5 - max 2 decimals, not thousand separator like .000)
    final allNumMatches = RegExp(r'\b(\d{1,2}[\.,]\d{1,2})\b').allMatches(text);
    for (var m in allNumMatches) {
      String fullMatch = m.group(0)!;
      // Skip if part of 3-digit thousand separator e.g. 10.000 or 35.000
      if (RegExp(r'[\.,]\d{3}\b').hasMatch(text)) {
        continue;
      }
      String str = fullMatch.replaceAll(',', '.');
      double? val = double.tryParse(str);
      if (val != null && val > 0 && val <= 20) {
        return val;
      }
    }

    return null;
  }

  static ScannedItemModel? parseSingleLine(
    String line,
    String id,
    String currentProduct,
  ) {
    var text = cleanLine(line);
    if (text.isEmpty) return null;

    if (isHeaderOrNoise(text)) return null;

    text = normalizeOcrText(text);

    final isDitto = isDittoMark(text);
    final jenis = detectJenis(text, currentProduct);
    final pembayaran = detectPembayaran(text);
    final channel = detectChannel(text);
    final extractedHarga = extractHarga(text);
    double? extractedBerat = extractBerat(text);

    // If no price and no weight, check if line is purely noise/ditto
    if (extractedHarga == null && extractedBerat == null) {
      final hasProduct = detectJenis(text, '') != '';
      if (!hasProduct && isDitto) return null;
      if (!hasProduct && text.length < 3) return null;
    }

    // Auto-calculate Berat if only Harga is present
    if (extractedBerat == null &&
        extractedHarga != null &&
        extractedHarga > 0) {
      int pricePerKg = getHargaPerKg(jenis);
      double computed = extractedHarga / pricePerKg;
      extractedBerat = round1Decimal(computed);
      if (extractedBerat <= 0) extractedBerat = 0.1;
    }

    double finalBerat = extractedBerat ?? 1.0;
    finalBerat = round1Decimal(finalBerat);

    int finalHarga;
    if (extractedHarga != null && extractedHarga > 0) {
      finalHarga = extractedHarga;
    } else {
      int pricePerKg = getHargaPerKg(jenis);
      finalHarga = roundUpToThousand((finalBerat * pricePerKg).round());
    }

    String beratDisplay = finalBerat.toStringAsFixed(1).replaceAll('.', ',');
    if (beratDisplay.endsWith(',0')) {
      beratDisplay = finalBerat.toInt().toString();
    }

    return ScannedItemModel(
      id: id,
      jenis: jenis,
      pembayaran: pembayaran,
      channel: channel,
      beratText: beratDisplay,
      hargaText: formatRupiah(finalHarga),
      catatanText: '',
      namaPemesanText: '',
      isSelected: true,
    );
  }

  static List<ScannedItemModel> parseFullText(String fullText) {
    List<ScannedItemModel> items = [];
    final lines = fullText.split('\n');
    int idCounter = 1;
    String currentProduct = 'Bakar';

    for (var line in lines) {
      final item = parseSingleLine(line, idCounter.toString(), currentProduct);
      if (item != null) {
        currentProduct = item.jenis;
        items.add(item);
        idCounter++;
      }
    }

    return items;
  }

  static List<String> groupOcrLinesToRows(List<OcrLineItem> allLines) {
    if (allLines.isEmpty) return [];

    // Sort all lines vertically first
    allLines.sort((a, b) => a.centerY.compareTo(b.centerY));

    // Calculate median line height to determine sensible grouping tolerance
    List<double> heights = allLines.map((e) => e.height).toList()..sort();
    double medianHeight = heights[heights.length ~/ 2];
    if (medianHeight < 15.0) medianHeight = 15.0;

    // Vertical distance tolerance: 0.70 * median line height
    double maxAllowedYDiff = medianHeight * 0.70;
    if (maxAllowedYDiff < 18.0) maxAllowedYDiff = 18.0;

    List<List<OcrLineItem>> rows = [];
    for (var item in allLines) {
      int bestRowIndex = -1;
      double minDistance = double.infinity;

      for (int i = 0; i < rows.length; i++) {
        var row = rows[i];
        double rowMinTop = row
            .map((e) => e.top)
            .reduce((a, b) => a < b ? a : b);
        double rowMaxBottom = row
            .map((e) => e.bottom)
            .reduce((a, b) => a > b ? a : b);
        double rowCenterY = (rowMinTop + rowMaxBottom) / 2;

        double overlap =
            (rowMaxBottom < item.bottom ? rowMaxBottom : item.bottom) -
            (rowMinTop > item.top ? rowMinTop : item.top);
        double dist = (item.centerY - rowCenterY).abs();

        if ((overlap > 0.20 * medianHeight || dist <= maxAllowedYDiff) &&
            dist < minDistance) {
          minDistance = dist;
          bestRowIndex = i;
        }
      }

      if (bestRowIndex != -1) {
        rows[bestRowIndex].add(item);
      } else {
        rows.add([item]);
      }
    }

    // Sort rows top-to-bottom
    rows.sort((a, b) {
      double avgYa =
          a.map((e) => e.centerY).reduce((v1, v2) => v1 + v2) / a.length;
      double avgYb =
          b.map((e) => e.centerY).reduce((v1, v2) => v1 + v2) / b.length;
      return avgYa.compareTo(avgYb);
    });

    // For each row, sort words left-to-right
    List<String> combinedRows = [];
    for (var row in rows) {
      row.sort((a, b) => a.left.compareTo(b.left));
      combinedRows.add(row.map((e) => e.text).join(' '));
    }

    return combinedRows;
  }
}
