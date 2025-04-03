import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TextRecognitionService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<String> recognizeTextFromImage(File imageFile) async {
    try {
      final InputImage inputImage = InputImage.fromFile(imageFile);

      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.trim().isEmpty) {
        return '';
      }

      String bestEquation = _findBestEquation(recognizedText);

      if (bestEquation.isNotEmpty) {
        bestEquation = _cleanupMathEquation(bestEquation);
        debugPrint('Best equation found: $bestEquation');
        return bestEquation;
      }

      String extractedText = recognizedText.text;
      extractedText = _cleanupMathEquation(extractedText);

      debugPrint('Recognized text: $extractedText');
      return extractedText;
    } catch (e) {
      debugPrint('Error recognizing text from image: $e');
      return '';
    }
  }

  String _findBestEquation(RecognizedText recognizedText) {
    List<String> candidates = [];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String lineText = line.text.trim();

        int score = _scoreEquationCandidate(lineText);
        if (score > 0) {
          candidates.add(lineText);
        }
      }
    }

    if (candidates.isNotEmpty) {
      candidates.sort(
          (a, b) => _scoreEquationCandidate(b) - _scoreEquationCandidate(a));
      return candidates.first;
    }

    return '';
  }

  int _scoreEquationCandidate(String text) {
    int score = 0;

    if (text.contains('=')) score += 10;
    if (text.contains('+')) score += 5;
    if (text.contains('-')) score += 5;
    if (text.contains('×') || text.contains('*')) score += 5;
    if (text.contains('÷') || text.contains('/')) score += 5;
    if (text.contains('^') || text.contains('²') || text.contains('³'))
      score += 8;
    if (text.contains('(') && text.contains(')')) score += 7;
    if (text.contains('√')) score += 8;

    for (String variable in ['x', 'y', 'z', 'a', 'b', 'c', 'n', 'm']) {
      if (text.contains(variable)) score += 3;
    }

    final numberCount = RegExp(r'\d').allMatches(text).length;
    score += numberCount * 2;

    if (text.length < 3) score -= 10;
    if (text.length > 50) score -= (text.length - 50) ~/ 5;

    if (RegExp(r'\b[a-z]\s*=').hasMatch(text)) score += 15;
    if (RegExp(r'\b[a-z]\^2').hasMatch(text)) score += 15;
    if (RegExp(r'd/d[a-z]').hasMatch(text)) score += 15;
    if (text.contains('∫')) score += 15;

    return score;
  }

  String _cleanupMathEquation(String text) {
    String cleaned = text.replaceAll('\n', ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    Map<String, String> replacements = {
      '÷': '/',
      '×': '*',
      '−': '-',
      '=': '=',
      ',': '.',
      'O': '0',
      'o': '0',
      'l': '1',
      'I': '1',
      '{': '(',
      '}': ')',
      '[': '(',
      ']': ')',
      '²': '^2',
      '³': '^3',
      '⁴': '^4',
      '⁵': '^5',
      '⁶': '^6',
    };

    replacements.forEach((key, value) {
      cleaned = cleaned.replaceAll(key, value);
    });

    cleaned = cleaned.replaceAll('+ ', '+').replaceAll(' +', '+');
    cleaned = cleaned.replaceAll('- ', '-').replaceAll(' -', '-');
    cleaned = cleaned.replaceAll('* ', '*').replaceAll(' *', '*');
    cleaned = cleaned.replaceAll('/ ', '/').replaceAll(' /', '/');
    cleaned = cleaned.replaceAll('= ', '=').replaceAll(' =', '=');
    cleaned = cleaned.replaceAll('^ ', '^').replaceAll(' ^', '^');

    return cleaned;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
