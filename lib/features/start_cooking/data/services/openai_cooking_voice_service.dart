import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// this service speaks cooking steps using openai tts and falls back to flutter tts
class OpenAiCookingVoiceService {
  OpenAiCookingVoiceService();

  // this key comes from dart define and is needed for openai requests
  static const String _apiKey = String.fromEnvironment('OPENAI_API_KEY');
  // this endpoint generates spoken audio from text
  static final Uri _speechUri = Uri.parse(
    'https://api.openai.com/v1/audio/speech',
  );
  // this is the tts model used to generate voice
  static const String _model = 'gpt-4o-mini-tts';
  // this is the voice profile name
  static const String _voice = 'sage';

  // this player plays mp3 bytes returned by openai
  final AudioPlayer _audioPlayer = AudioPlayer();
  // this is local fallback voice when openai is missing or fails
  final FlutterTts _fallbackTts = FlutterTts();

  // this makes sure setup is done only once
  bool _isInitialized = false;

  // this configures fallback tts settings
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _fallbackTts.setLanguage('en-US');
    await _fallbackTts.setSpeechRate(0.45);
    await _fallbackTts.setPitch(1.0);
    await _fallbackTts.awaitSpeakCompletion(true);
  }

  // this tries openai speech first then fallback tts if needed
  Future<bool> speak(String text) async {
    await init();
    await stop();

    // if api key is empty we directly use fallback voice
    if (_apiKey.trim().isEmpty) {
      await _fallbackTts.speak(text);
      return false;
    }

    try {
      // this sends the text to openai and asks for mp3 response
      final response = await http.post(
        _speechUri,
        headers: <String, String>{
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body:
            '{"model":"$_model","voice":"$_voice","input":"${_escapeJson(text)}","format":"mp3","instructions":"Speak naturally, warm, and clear. Keep pauses between sentence ideas."}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _fallbackTts.speak(text);
        return false;
      }

      // this saves mp3 in temp folder then plays it
      final filePath = await _writeMp3ToTemp(response.bodyBytes);
      await _audioPlayer.play(DeviceFileSource(filePath));
      // this waits for audio to finish before returning
      await _audioPlayer.onPlayerComplete.first.timeout(
        const Duration(minutes: 5),
      );
      return true;
    } catch (_) {
      // any request or playback error will still keep voice working with fallback
      await _fallbackTts.speak(text);
      return false;
    }
  }

  // this stops any currently playing audio
  Future<void> stop() async {
    await _audioPlayer.stop();
    await _fallbackTts.stop();
  }

  // this releases audio resources when screen is closed (with dispose and stop)
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    await _fallbackTts.stop();
  }

  // this writes raw mp3 bytes to a temporary file path
  Future<String> _writeMp3ToTemp(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/cooking_step_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // this escapes special characters so text stays valid inside json body
  String _escapeJson(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
  }
}
