import 'package:flutter_test/flutter_test.dart';
import 'package:kasumbasawelas/scanner/scan_buku_page.dart';

void main() {
  group('OCR Note Parsing Tests', () {
    test('catatanubi.jpeg image text parsing correctly identifies all 9 rows', () {
      final sampleNote = '''
31 Agustus 2026
UBI Bakar 35.000 Cash
" 10.000 QRIS
Mentah 11.000 Cash
" 15.000 QRIS
" 10.000 Cash
Bakar 20.000 QRIS
" 10.000 Cash
u 11.000 Cash
" 10.000 Cash
''';

      final results = NoteOcrParser.parseFullText(sampleNote);

      expect(results.length, 9);

      // Row 1: UBI Bakar 35.000 Cash
      expect(results[0].jenis, 'Bakar');
      expect(results[0].hargaText, '35.000');
      expect(results[0].pembayaran, 'Cash');
      expect(results[0].beratText, '1');

      // Row 2: " 10.000 QRIS -> Bakar inherited from Row 1, Harga 10.000, Pembayaran QRIS BJB
      expect(results[1].jenis, 'Bakar');
      expect(results[1].hargaText, '10.000');
      expect(results[1].pembayaran, 'QRIS BJB');
      expect(results[1].beratText, '0,3');

      // Row 3: Mentah 11.000 Cash -> Mentah detected, Harga 11.000, Pembayaran Cash
      expect(results[2].jenis, 'Mentah');
      expect(results[2].hargaText, '11.000');
      expect(results[2].pembayaran, 'Cash');
      expect(results[2].beratText, '0,4');

      // Row 4: " 15.000 QRIS -> Mentah inherited from Row 3, Harga 15.000, Pembayaran QRIS BJB
      expect(results[3].jenis, 'Mentah');
      expect(results[3].hargaText, '15.000');
      expect(results[3].pembayaran, 'QRIS BJB');
      expect(results[3].beratText, '0,6');

      // Row 5: " 10.000 Cash -> Mentah inherited from Row 4, Harga 10.000, Pembayaran Cash
      expect(results[4].jenis, 'Mentah');
      expect(results[4].hargaText, '10.000');
      expect(results[4].pembayaran, 'Cash');
      expect(results[4].beratText, '0,4');

      // Row 6: Bakar 20.000 QRIS -> Bakar detected, Harga 20.000, Pembayaran QRIS BJB
      expect(results[5].jenis, 'Bakar');
      expect(results[5].hargaText, '20.000');
      expect(results[5].pembayaran, 'QRIS BJB');
      expect(results[5].beratText, '0,6');

      // Row 7: " 10.000 Cash -> Bakar inherited from Row 6, Harga 10.000, Pembayaran Cash
      expect(results[6].jenis, 'Bakar');
      expect(results[6].hargaText, '10.000');
      expect(results[6].pembayaran, 'Cash');
      expect(results[6].beratText, '0,3');

      // Row 8: u 11.000 Cash -> Bakar inherited from Row 7, Harga 11.000, Pembayaran Cash
      expect(results[7].jenis, 'Bakar');
      expect(results[7].hargaText, '11.000');
      expect(results[7].pembayaran, 'Cash');
      expect(results[7].beratText, '0,3');

      // Row 9: " 10.000 Cash -> Bakar inherited from Row 8, Harga 10.000, Pembayaran Cash
      expect(results[8].jenis, 'Bakar');
      expect(results[8].hargaText, '10.000');
      expect(results[8].pembayaran, 'Cash');
      expect(results[8].beratText, '0,3');
    });

    test(
      'Handles OCR handwriting variations of Mentah, Bakar, QFIS, and row numbers',
      () {
        final sampleNoteWithOcrMisreads = '''
1. Ubi Bakar 35.000 Cash
2. " 10.000 QFIS
3. Menta4 11.060 Cash
4. '' 15.000 QKIS
5. ,, 10.000 casn
6. bkr 20.000 QRIS
7. " 10.000 csh
8. 11.000 Cash
9. (( 10.000 Cash
''';

        final results = NoteOcrParser.parseFullText(sampleNoteWithOcrMisreads);

        expect(results.length, 9);
        expect(results[0].jenis, 'Bakar');
        expect(results[0].hargaText, '35.000');

        expect(results[1].jenis, 'Bakar');
        expect(results[1].pembayaran, 'QRIS BJB');

        // Mentah correctly identified even if OCR says Menta4 and price 11.060 -> 11.000
        expect(results[2].jenis, 'Mentah');
        expect(results[2].hargaText, '11.000');

        // Dittos under Mentah stay Mentah
        expect(results[3].jenis, 'Mentah');
        expect(results[3].pembayaran, 'QRIS BJB');
        expect(results[4].jenis, 'Mentah');
        expect(results[4].pembayaran, 'Cash');

        // Row 6 changes to Bakar
        expect(results[5].jenis, 'Bakar');
        expect(results[5].hargaText, '20.000');

        // Row 7 stays Bakar
        expect(results[6].jenis, 'Bakar');

        // Row 8 starts with 11.000 without product name -> stays Bakar, price is 11.000
        expect(results[7].jenis, 'Bakar');
        expect(results[7].hargaText, '11.000');

        // Row 9 stays Bakar
        expect(results[8].jenis, 'Bakar');
        expect(results[8].hargaText, '10.000');
      },
    );
  });
}
