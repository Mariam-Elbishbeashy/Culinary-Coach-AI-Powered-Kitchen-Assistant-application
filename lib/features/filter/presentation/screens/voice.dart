// ============================================================
// VOICE SEARCH SCREEN
// ------------------------------------------------------------
// This screen allows the user to:
// 1. Record voice using microphone
// 2. Convert speech into text using OpenAI Whisper API
// 3. Clean the transcript into ingredient names
// 4. Return the recognized ingredient back to FilterScreen

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// Main screen widget for voice ingredient search
class VoiceSearchScreen extends StatefulWidget {
  const VoiceSearchScreen({super.key});

  @override
  State<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

// Handles recording, transcription, OpenAI requests, and UI state
class _VoiceSearchScreenState extends State<VoiceSearchScreen> {
  static const Color _orangeDark = Color(0xFFB87313);
  static const Color _orange = Color(0xFFD99622);
  static const Color _cream = Color(0xFFF7F1DE);
  static const Color _cardCream = Color(0xFFFCF7E8);
  static const Color _brown = Color(0xFF3A2214);
  static const Color _mutedBrown = Color(0xFF8B7355);
  static const Color _border = Color(0xFFE2C9A4);

  final AudioRecorder _recorder = AudioRecorder();

  static const String apiKey = String.fromEnvironment('OPENAI_API_KEY');

  bool isRecording = false;
  bool isLoading = false;
  String transcript = '';
  String? errorMessage;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  // Starts or stops recording depending on current state
  Future<void> _toggleRecording() async {
    if (isLoading) return;
    if (isRecording) {
      await _stopRecordingAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  // Starts microphone recording and stores audio temporarily
  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        setState(() => errorMessage = 'Microphone permission is required.');
        return;
      }

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/voice_search_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        transcript = '';
        errorMessage = null;
        isRecording = true;
      });
    } catch (_) {
      setState(() => errorMessage = 'Could not start recording. Please try again.');
    }
  }

  // Stops recording then sends audio for transcription
  Future<void> _stopRecordingAndTranscribe() async {
    try {
      final path = await _recorder.stop();
      setState(() {
        isRecording = false;
        isLoading = true;
        errorMessage = null;
      });

      if (path == null || !File(path).existsSync()) {
        throw Exception('No audio file was recorded.');
      }

      final rawTranscript = await _transcribeAudio(File(path));
      final cleaned = await _extractIngredientWords(rawTranscript);

      if (!mounted) return;
      if (cleaned.trim().isEmpty) {
        throw Exception('No ingredient words detected.');
      }

      setState(() {
        transcript = cleaned;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = _friendlyError(e);
      });
    }
  }

  // Sends audio file to OpenAI Whisper transcription API
  Future<String> _transcribeAudio(File audioFile) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Missing OpenAI API key.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
    );

    request.headers['Authorization'] = 'Bearer $apiKey';
    request.fields['model'] = 'whisper-1';
    request.fields['language'] = 'en';
    request.fields['response_format'] = 'json';

    // Do NOT put instructions here. A transcription prompt is only a bias hint.
    // If instructions are placed here, they can appear as the recognized text.
    request.fields['prompt'] = 'milk, eggs, tomato, chicken breast, rice, onion, garlic';

    request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('OpenAI transcription failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['text'] as String? ?? '').trim();
  }

  // Cleans transcript and extracts only ingredient names
  Future<String> _extractIngredientWords(String rawTranscript) async {
    final raw = rawTranscript.trim();
    if (raw.isEmpty) return '';

    // Safety guard for the exact bug shown in your screenshot.
    final lower = raw.toLowerCase();
    if (lower.contains('recipe pantry search') ||
        lower.contains('return only the ingredient words') ||
        lower.contains('ingredient names for a recipe')) {
      return '';
    }

    if (apiKey.trim().isEmpty) {
      return _cleanIngredientSearchText(raw);
    }

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'temperature': 0,
        'messages': [
          {
            'role': 'system',
            'content': 'You clean voice transcripts for an ingredient pantry search. Return only ingredient words, separated by commas if there is more than one. No sentence. No explanation. No markdown.',
          },
          {
            'role': 'user',
            'content': raw,
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _cleanIngredientSearchText(raw);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content']?.toString() ?? '';
    return _cleanIngredientSearchText(content);
  }

  // Removes unnecessary words and formatting from transcript
  String _cleanIngredientSearchText(String value) {
    var text = value.trim();

    text = text.replaceAll(RegExp(r'```.*?```', dotAll: true), '');
    text = text.replaceAll(RegExp(r'[\[\]{}"`]+'), '');
    text = text.replaceAll(RegExp(r'\b(ingredient|ingredients|search|recipe|pantry)\b', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'^(search for|find|show me|i need|i want|please add|add)\s+', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\b(return only|words|name|names|for a)\b', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'[.!?;:]+'), '');
    text = text.replaceAll(RegExp(r'\s*,\s*'), ', ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.toLowerCase().contains('recipe pantry') ||
        text.toLowerCase().contains('return only')) {
      return '';
    }

    return text;
  }

  // Converts technical errors into user-friendly messages
  String _friendlyError(dynamic error) {
    final value = error.toString().toLowerCase();
    if (value.contains('api key') || value.contains('401')) {
      return 'OpenAI API key is missing or invalid.';
    }
    if (value.contains('429')) {
      return 'Too many requests. Please try again shortly.';
    }
    if (value.contains('permission')) {
      return 'Microphone permission is required.';
    }
    if (value.contains('no ingredient')) {
      return 'No ingredient was recognized. Please say only the ingredient name, like milk or tomato.';
    }
    return 'Could not understand the audio. Please try again.';
  }

  // Returns transcript back to previous screen
  void _useTranscript() {
    final value = transcript.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  // Builds the complete voice search UI
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldColor = isDarkMode ? const Color(0xFF121212) : _cream;
    final cardColor = isDarkMode ? const Color(0xFF232323) : _cardCream;
    final borderColor = isDarkMode ? const Color(0xFF3A3A3A) : _border;
    final titleColor = isDarkMode ? const Color(0xFFF2F2F2) : _brown;
    final subtitleColor = isDarkMode ? const Color(0xFFBEBEBE) : _mutedBrown;
    final backButtonBg = isDarkMode ? const Color(0xFF232323) : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(color: backButtonBg, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_rounded, color: _orangeDark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Voice Search',
                      style: TextStyle(color: titleColor, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: isRecording ? 138 : 120,
                width: isRecording ? 138 : 120,
                decoration: BoxDecoration(
                  color: isRecording ? _orange : _orangeDark,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _orangeDark.withOpacity(isRecording ? 0.35 : 0.22),
                      blurRadius: isRecording ? 28 : 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _toggleRecording,
                  icon: Icon(isRecording ? Icons.stop_rounded : Icons.keyboard_voice_rounded),
                  color: Colors.white,
                  iconSize: isRecording ? 58 : 52,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isRecording
                    ? 'Listening... tap to stop'
                    : isLoading
                    ? 'Understanding your voice...'
                    : 'Tap and say an ingredient',
                textAlign: TextAlign.center,
                style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Example: milk, tomato, chicken breast, rice',
                textAlign: TextAlign.center,
                style: TextStyle(color: subtitleColor, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 28),
              if (isLoading)
                const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_orangeDark)),
              if (errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(isDarkMode ? 0.14 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(isDarkMode ? 0.38 : 0.25)),
                  ),
                  child: Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              if (transcript.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Recognized ingredient',
                        style: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        transcript,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: titleColor, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _useTranscript,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orangeDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    child: const Text('Search Ingredient', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
