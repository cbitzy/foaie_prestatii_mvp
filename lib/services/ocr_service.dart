import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String? inDate;
  final String? inTime;
  final String? outDate;
  final String? outTime;
  final String debugText;
  OcrResult({this.inDate, this.inTime, this.outDate, this.outTime, this.debugText = ''});
}

class OcrService {
  static Future<OcrResult> extractTimes(File image) async {
    try {
      final input = InputImage.fromFile(image);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final res = await recognizer.processImage(input);
      await recognizer.close();

      final lines = <String>[];
      for (final block in res.blocks) {
        for (final line in block.lines) {
          lines.add(line.text);
        }
      }
      final all = lines.join('\n');

      String? findDateNear(String anchor) {
        final idx = all.toLowerCase().indexOf(anchor.toLowerCase());
        if (idx < 0) return null;
        final end = (idx + 160) > all.length ? all.length : (idx + 160);
        final win = all.substring(idx, end);
        final m = RegExp(r'(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})').firstMatch(win);
        return m?.group(1);
      }

      String? findTimeNear(String anchor) {
        final idx = all.toLowerCase().indexOf(anchor.toLowerCase());
        if (idx < 0) return null;
        final end = (idx + 160) > all.length ? all.length : (idx + 160);
        final win = all.substring(idx, end);
        final m = RegExp(r'(\d{1,2})\s*[:\.]\s*([0-5]\d)').firstMatch(win);
        if (m == null) return null;
        final hh = m.group(1)!.padLeft(2, '0');
        final mm = m.group(2)!;
        return '$hh:$mm';
      }

      final inDate = findDateNear('prezent'); // „Prezentarea echipei la serviciu”
      final inTime = findTimeNear('prezent');
      final outDate = findDateNear('ieșirii echipei') ?? findDateNear('iesirii echipei');
      final outTime = findTimeNear('ieșirii echipei') ?? findTimeNear('iesirii echipei');

      return OcrResult(
        inDate: inDate,
        inTime: inTime,
        outDate: outDate,
        outTime: outTime,
        debugText: all,
      );
    } catch (e) {
      return OcrResult(debugText: 'OCR error: $e');
    }
  }
}
