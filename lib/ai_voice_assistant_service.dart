import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AiVoiceResponse {
  final String action;
  final String spokenResponse;

  AiVoiceResponse({required this.action, required this.spokenResponse});

  factory AiVoiceResponse.fromJson(Map<String, dynamic> json) {
    return AiVoiceResponse(
      action: json['action'] ?? 'none',
      spokenResponse: json['spoken_response'] ?? 'I am here with you.',
    );
  }
}

class AiVoiceAssistantService {
  static final AiVoiceAssistantService instance = AiVoiceAssistantService._internal();
  AiVoiceAssistantService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechInitialized = false;

  // Resolves backend address across Web, Android Emulator, and Desktop/iOS
  String get _baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  Future<void> init() async {
    // 1. Safe platform check that will not crash Chrome
    if (!kIsWeb && Platform.isAndroid) {
      await _flutterTts.setEngine("com.google.android.tts");
    }

    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.15);
    await _flutterTts.setVolume(1.0);
    _isSpeechInitialized = await _speech.initialize();
  }

 Future<void> speak(String text) async {
    String ttsLang = 'en-IN'; // Default to English for English text

    // Auto-detect the script of the text itself to dynamically switch voices
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(text)) {
      ttsLang = 'bn-IN'; // Bengali script detected
    } else if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      ttsLang = 'hi-IN'; // Hindi (Devanagari) script detected
    } 

    await _flutterTts.setLanguage(ttsLang);
    await _flutterTts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required Function(bool isListening) onListeningStatusChanged,
  }) async {
    if (!_isSpeechInitialized) {
      _isSpeechInitialized = await _speech.initialize();
    }

    if (_isSpeechInitialized) {
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString('app_language') ?? 'en';

      String localeId = 'en_IN';
      if (langCode == 'bn') localeId = 'bn_IN';
      if (langCode == 'hi') localeId = 'hi_IN';
      if (langCode == 'as') localeId = 'as_IN';

      onListeningStatusChanged(true);

      await _speech.listen(
        localeId: localeId,
        onResult: (result) {
          onResult(result.recognizedWords);
          if (result.finalResult) {
            onListeningStatusChanged(false);
          }
        },
      );
    } else {
      onListeningStatusChanged(false);
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  // --- REASONING VIA FASTAPI BACKEND ---
  Future<AiVoiceResponse> processUserSpeech(String spokenText) async {
    if (spokenText.trim().isEmpty) {
      return AiVoiceResponse(action: 'none', spokenResponse: 'I am listening whenever you are ready.');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/voice-assistant/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': spokenText}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return AiVoiceResponse.fromJson(data);
      }
    } catch (e) {
      print('--- AI BACKEND ERROR: $e ---');
    }

    // Client-side localized fallback if the backend network request fails completely
    String fallbackResponse;
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(spokenText)) {
      fallbackResponse = 'আমার কানেক্ট করতে সমস্যা হচ্ছে, তবে আমি আপনার সাথেই আছি।';
    } else if (RegExp(r'[\u0900-\u097F]').hasMatch(spokenText)) {
      fallbackResponse = 'मुझे अभी कनेक्ट करने में थोड़ी परेशानी हो रही है, लेकिन मैं आपके साथ हूँ।';
    } else {
      fallbackResponse = 'I am having trouble connecting right now, but I am right here with you.';
    }

    return AiVoiceResponse(
      action: 'none',
      spokenResponse: fallbackResponse,
    );
  }
}