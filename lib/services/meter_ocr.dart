import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device text recognition (Google ML Kit, bundled model).
/// Runs fully offline; the image never leaves the phone.
Future<String> recognizeText(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
    return result.text;
  } finally {
    await recognizer.close();
  }
}
