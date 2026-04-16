import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'home_screen.dart';

import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('products');
  await Hive.openBox('session');
  runApp(const ProviderScope(child: VoiceBazaarApp()));
}

final themeProvider = Provider((ref) {
  return ThemeData(
    fontFamily: 'NotoSansTamil',
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF4CAF50),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF81D4FA),
      onSecondary: Color(0xFF333333),
      error: Colors.red,
      onError: Colors.white,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF333333),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5DC),
    canvasColor: const Color(0xFFF5F5DC),
  );
});

class TamilTts {
  static Future<bool> speak(
    FlutterTts tts,
    String text, {
    String primaryLanguage = 'ta-IN',
    bool allowEnglishFallback = true,
  }) async {
    try {
      await tts.stop();
    } catch (_) {}

    final candidates = <String>[];
    if (primaryLanguage.toLowerCase().startsWith('ta')) {
      candidates
        ..add('ta-IN')
        ..add('ta');
    } else {
      candidates
        ..add('en-US')
        ..add('en-IN')
        ..add('en-GB');
    }
    if (allowEnglishFallback &&
        !primaryLanguage.toLowerCase().startsWith('en')) {
      candidates
        ..add('en-US')
        ..add('en-IN');
    }

    var languageSet = false;
    for (final language in candidates) {
      try {
        await tts.setLanguage(language);
        languageSet = true;
        break;
      } catch (_) {}
    }
    if (!languageSet) {
      return false;
    }

    if (!kIsWeb) {
      try {
        await tts.awaitSpeakCompletion(true);
      } catch (_) {}
    }

    try {
      await tts.setVolume(1.0);
    } catch (_) {}

    try {
      await tts.setPitch(1.0);
    } catch (_) {}

    try {
      await tts.setSpeechRate(0.45);
    } catch (_) {}

    try {
      await tts.speak(text);
      return true;
    } catch (_) {
      // Ignore non-fatal TTS errors and keep app flow intact.
      return false;
    }
  }
}

class VoiceBazaarApp extends ConsumerWidget {
  const VoiceBazaarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return MaterialApp(
      title: 'உழவர் ட்ரேடு',
      theme: theme,
      home: const SplashScreen(),
      locale: const Locale('ta'),
      supportedLocales: const [Locale('ta')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initSplash();
  }

  Future<void> _initSplash() async {
    if (!kIsWeb) {
      await TamilTts.speak(
        flutterTts,
        "வணக்கம்! உழவர் ட்ரேடுக்கு வரவேற்கிறோம்",
      );
    }
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.agriculture,
              size: 100,
              color: Colors.green,
            ).animate().fade(duration: 1.seconds).scale(delay: 500.ms),
            const SizedBox(height: 20),
            Text(
              'உழவர் ட்ரேடு',
              style: GoogleFonts.notoSansTamil(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ).animate().fade(duration: 1.seconds),
          ],
        ),
      ),
    );
  }
}

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _readOptions();
  }

  Future<void> _readOptions() async {
    if (!kIsWeb) {
      await TamilTts.speak(
        flutterTts,
        "நீங்கள் விற்க வேண்டுமா, அல்லது வாங்க வேண்டுமா? திரையைத் தொடவும்.",
      );
    }
  }

  void _selectRole(bool isSeller) async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 100);
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isSeller ? const SellerDashboard() : const BuyerDiscovery(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('உழவர் ட்ரேடு - UzhavarTrade')),
      body: Column(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _selectRole(true),
              child: Container(
                width: double.infinity,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.agriculture, size: 80),
                    const SizedBox(height: 20),
                    Text(
                      'விற்கணும் (I Sell)',
                      style: GoogleFonts.notoSansTamil(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 2, thickness: 2),
          Expanded(
            child: InkWell(
              onTap: () => _selectRole(false),
              child: Container(
                width: double.infinity,
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart, size: 80),
                    const SizedBox(height: 20),
                    Text(
                      'வாங்கணும் (I Buy)',
                      style: GoogleFonts.notoSansTamil(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum VoiceState { listeningName, listeningPhone, confirming, registering }

enum VoiceLanguage { english, tamil }

class SellerVoiceOnboardingScreen extends StatefulWidget {
  const SellerVoiceOnboardingScreen({super.key});

  @override
  State<SellerVoiceOnboardingScreen> createState() =>
      _SellerVoiceOnboardingScreenState();
}

class _SellerVoiceOnboardingScreenState
    extends State<SellerVoiceOnboardingScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final Map<VoiceState, String> _stepSamplePaths = {};

  VoiceState _state = VoiceState.listeningName;
  VoiceLanguage _language = VoiceLanguage.english;
  bool _speechReady = false;
  bool _isListening = false;
  bool _isBusy = false;
  bool _isStartingListen = false;
  bool _isPrompting = false;
  bool _isListenWindowDone = false;
  String? _listenLocaleId;
  String? _activeCapturePath;
  Timer? _listenWindowTimer;
  Completer<void>? _listenCycleCompleter;
  String _lastRecognizedText = '';
  String _currentPrompt = '';
  String _status = 'Voice assistant is preparing...';

  @override
  void initState() {
    super.initState();
    _initializeAndAutoStart();
  }

  @override
  void dispose() {
    _listenWindowTimer?.cancel();
    _speech.stop();
    _tts.stop();
    _audioRecorder.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndAutoStart() async {
    if (!kIsWeb) {
      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        if (!mounted) return;
        setState(() {
          _status = _language == VoiceLanguage.tamil
              ? 'மைக்ரோஃபோன் அனுமதி தேவை.'
              : 'Microphone permission is required.';
        });
        return;
      }
    }

    final ready = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );

    await _resolveLocaleForLanguage();

    if (!mounted) return;
    setState(() {
      _speechReady = ready;
      _status = ready
          ? (_language == VoiceLanguage.tamil
                ? 'கேட்க தயாராக உள்ளது.'
                : 'Ready for voice input.')
          : (_language == VoiceLanguage.tamil
                ? 'வாய்ஸ் சேவை தொடங்கவில்லை. மீண்டும் முயற்சி செய்யுங்கள்.'
                : 'Speech service did not start. Please try again.');
    });

    if (!ready) return;
    await _startCurrentStatePrompt();
  }

  Future<void> _resolveLocaleForLanguage() async {
    try {
      final locales = await _speech.locales();
      if (_language == VoiceLanguage.tamil) {
        final tamil = locales
            .where((l) => l.localeId.toLowerCase().contains('ta'))
            .toList();
        _listenLocaleId = tamil.isNotEmpty ? tamil.first.localeId : null;
      } else {
        final english = locales
            .where((l) => l.localeId.toLowerCase().startsWith('en'))
            .toList();
        _listenLocaleId = english.isNotEmpty ? english.first.localeId : null;
      }
    } catch (_) {
      _listenLocaleId = null;
    }
  }

  String _promptForState(VoiceState state) {
    if (_language == VoiceLanguage.tamil) {
      switch (state) {
        case VoiceState.listeningName:
          return 'உங்கள் பெயர் என்ன?';
        case VoiceState.listeningPhone:
          return 'உங்கள் அலைபேசி எண் என்ன?';
        case VoiceState.confirming:
          return 'உங்கள் அனைத்து தகவல்களும் சரியா? தொடரலாமா?';
        case VoiceState.registering:
          return 'பதிவு செய்கிறோம்...';
      }
    }

    switch (state) {
      case VoiceState.listeningName:
        return 'What is your name?';
      case VoiceState.listeningPhone:
        return 'What is your phone number?';
      case VoiceState.confirming:
        return 'Are all your details correct? Shall I continue?';
      case VoiceState.registering:
        return 'Registering your details...';
    }
  }

  Future<void> _startCurrentStatePrompt() async {
    switch (_state) {
      case VoiceState.listeningName:
        await _askName();
        break;
      case VoiceState.listeningPhone:
        await _askPhone();
        break;
      case VoiceState.confirming:
        await _askConfirmation();
        break;
      case VoiceState.registering:
        break;
    }
  }

  void _onSpeechStatus(String status) {
    if (!_isListening) return;
    if (status.toLowerCase() != 'notlistening') return;
    if (_isStartingListen) return;
    if (_isListenWindowDone) return;

    unawaited(_completeListenWindow());
  }

  void _onSpeechError(dynamic error) {
    if (_isListenWindowDone) return;
    unawaited(_completeListenWindow());
  }

  Future<String> _createAudioPath(String prefix) async {
    if (kIsWeb) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return '$prefix-$now.webm';
    }

    final tempDir = await getTemporaryDirectory();
    const ext = 'wav';
    final now = DateTime.now().millisecondsSinceEpoch;
    return '${tempDir.path}/$prefix-$now.$ext';
  }

  Future<void> _startCaptureForStep() async {
    if (kIsWeb) {
      // On web, keep prompt-step capture disabled to avoid filesystem/path issues.
      _activeCapturePath = null;
      return;
    }

    try {
      final path = await _createAudioPath(_state.name);
      _activeCapturePath = path;

      if (kIsWeb) {
        await _audioRecorder.start(const RecordConfig(), path: path);
      } else {
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: path,
        );
      }
    } catch (_) {
      _activeCapturePath = null;
    }
  }

  Future<void> _completeListenWindow() async {
    if (_isListenWindowDone) return;
    _isListenWindowDone = true;

    _listenWindowTimer?.cancel();
    _listenWindowTimer = null;

    try {
      await _speech.stop();
    } catch (_) {}
    await _waitForSpeechIdle();
    final capturedPath = await _stopCaptureOnly();

    if (!mounted) return;
    setState(() {
      _isListening = false;
    });

    final recognized = _lastRecognizedText.trim();
    if (recognized.isEmpty) {
      setState(() {
        _status = _language == VoiceLanguage.tamil
            ? 'சரியாக பேசவும், எதுவும் கேட்கவில்லை'
            : 'Speak clearly, nothing was heard.';
      });
      await _queueNextPrompt(_startCurrentStatePrompt);
    } else {
      await _handleStepResult(recognized, capturedPath);
    }

    _listenCycleCompleter?.complete();
    _listenCycleCompleter = null;
  }

  Future<String?> _stopCaptureOnly() async {
    try {
      final stopped = await _audioRecorder.stop();
      return stopped ?? _activeCapturePath;
    } catch (_) {
      return _activeCapturePath;
    } finally {
      _activeCapturePath = null;
    }
  }

  Future<void> _waitForSpeechIdle() async {
    var tries = 0;
    while (_speech.isListening && tries < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      tries++;
    }
  }

  Future<void> _queueNextPrompt(Future<void> Function() action) async {
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await action();
  }

  Future<void> _listenForAnswer({bool fromPrompt = false}) async {
    if (_isBusy ||
        _isListening ||
        _isStartingListen ||
        (_isPrompting && !fromPrompt))
      return;
    if (!_speechReady) {
      setState(() {
        _status = _language == VoiceLanguage.tamil
            ? 'வாய்ஸ் சேவை தயாராக இல்லை. மீண்டும் முயற்சி செய்யுங்கள்.'
            : 'Speech service is not ready. Please try again.';
      });
      return;
    }

    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (!mounted) return;
        setState(() {
          _status = _language == VoiceLanguage.tamil
              ? 'மைக்ரோஃபோன் அனுமதி தேவை.'
              : 'Microphone permission is required.';
        });
        return;
      }
    }

    _isStartingListen = true;

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}

    await _waitForSpeechIdle();

    await _startCaptureForStep();

    if (!mounted) return;
    setState(() {
      _lastRecognizedText = '';
      _isListenWindowDone = false;
      _isListening = true;
      _status = _currentPrompt;
    });

    _listenCycleCompleter = Completer<void>();

    bool started = false;
    try {
      final primaryStarted = await _speech.listen(
        localeId: _listenLocaleId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 30),
        onResult: (result) async {
          final recognized = result.recognizedWords.trim();
          if (recognized.isNotEmpty) {
            _lastRecognizedText = recognized;
          }
        },
      );
      started = primaryStarted == true || _speech.isListening;
    } catch (_) {
      try {
        final fallbackStarted = await _speech.listen(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 30),
          onResult: (result) async {
            final recognized = result.recognizedWords.trim();
            if (recognized.isNotEmpty) {
              _lastRecognizedText = recognized;
            }
          },
        );
        started = fallbackStarted == true || _speech.isListening;
      } catch (_) {
        started = false;
      }
    } finally {
      _isStartingListen = false;
    }

    if (!started) {
      await _stopCaptureOnly();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _status = _language == VoiceLanguage.tamil
            ? 'கேட்கத் தொடங்க முடியவில்லை. மீண்டும் முயற்சி செய்யுங்கள்.'
            : 'Unable to start listening. Please try again.';
      });
      _listenCycleCompleter?.complete();
      _listenCycleCompleter = null;
      return;
    }

    _listenWindowTimer?.cancel();
    _listenWindowTimer = Timer(const Duration(seconds: 10), () {
      unawaited(_completeListenWindow());
    });

    await _listenCycleCompleter?.future;
  }

  Future<void> _promptStep({
    required VoiceState step,
    required String prompt,
  }) async {
    if (_isBusy || _isStartingListen) return;
    if (!mounted) return;
    setState(() {
      _state = step;
      _currentPrompt = prompt;
      _status = prompt;
      _isPrompting = true;
    });

    try {
      final selectedLanguage = _language == VoiceLanguage.tamil
          ? 'ta-IN'
          : 'en-US';
      if (kIsWeb) {
        unawaited(
          TamilTts.speak(
            _tts,
            prompt,
            primaryLanguage: selectedLanguage,
            allowEnglishFallback: _language == VoiceLanguage.english,
          ),
        );
      } else {
        await TamilTts.speak(
          _tts,
          prompt,
          primaryLanguage: selectedLanguage,
          allowEnglishFallback: _language == VoiceLanguage.english,
        );
      }
      await _listenForAnswer(fromPrompt: true);
    } finally {
      if (mounted) {
        setState(() {
          _isPrompting = false;
        });
      }
    }
  }

  Future<void> _handleStepResult(String text, String? capturedPath) async {
    if (_state == VoiceState.listeningName) {
      if (text.isEmpty) {
        setState(() {
          _status = _language == VoiceLanguage.tamil
              ? 'சரியாக பேசவும், எதுவும் கேட்கவில்லை'
              : 'Speak clearly, nothing was heard.';
        });
        await _queueNextPrompt(_startCurrentStatePrompt);
        return;
      }
      if (capturedPath != null && capturedPath.isNotEmpty) {
        _stepSamplePaths[VoiceState.listeningName] = capturedPath;
      }
      setState(() {
        _nameController.text = text;
        _status = _language == VoiceLanguage.tamil
            ? 'பெயர் பதிவு செய்யப்பட்டது: $text'
            : 'Name captured: $text';
      });
      await _queueNextPrompt(_askPhone);
      return;
    }

    if (_state == VoiceState.listeningPhone) {
      final digits = _extractPhoneDigits(text);
      if (digits.length < 8) {
        setState(() {
          _status = _language == VoiceLanguage.tamil
              ? 'எண்ணை தெளிவாக சொல்லுங்கள். மீண்டும் முயற்சி செய்யவும்.'
              : 'Phone number not clear. Please say it again.';
        });
        await _queueNextPrompt(_startCurrentStatePrompt);
        return;
      }
      if (capturedPath != null && capturedPath.isNotEmpty) {
        _stepSamplePaths[VoiceState.listeningPhone] = capturedPath;
      }
      setState(() {
        _phoneController.text = digits;
        _status = _language == VoiceLanguage.tamil
            ? 'மொபைல் எண் பதிவு செய்யப்பட்டது: $digits'
            : 'Phone captured: $digits';
      });
      await _queueNextPrompt(_askConfirmation);
      return;
    }

    if (_state == VoiceState.confirming) {
      if (_isYes(text)) {
        await _finalizeRegistration();
        return;
      }
      if (_isNo(text)) {
        setState(() {
          _nameController.clear();
          _phoneController.clear();
          _stepSamplePaths.clear();
          _state = VoiceState.listeningName;
          _status = _language == VoiceLanguage.tamil
              ? 'சரி, மீண்டும் பெயரிலிருந்து தொடங்கலாம்.'
              : 'Okay, restarting from name.';
        });
        await _queueNextPrompt(_askName);
        return;
      }

      setState(() {
        _status = _language == VoiceLanguage.tamil
            ? 'ஆமா அல்லது இல்லை என்று சொல்லுங்கள்.'
            : 'Please say yes or no.';
      });
      await _queueNextPrompt(_askConfirmation);
    }
  }

  String _extractPhoneDigits(String input) {
    final directDigits = RegExp(
      r'\d+',
    ).allMatches(input).map((m) => m.group(0)!).join();
    if (directDigits.length >= 8) {
      return directDigits;
    }

    final map = <String, String>{
      'zero': '0',
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'பூஜ்ஜியம்': '0',
      'பூஜ்யம்': '0',
      'ஒன்று': '1',
      'இரண்டு': '2',
      'மூன்று': '3',
      'நான்கு': '4',
      'ஐந்து': '5',
      'ஆறு': '6',
      'ஏழு': '7',
      'எட்டு': '8',
      'ஒன்பது': '9',
    };

    final words = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'));

    final buffer = StringBuffer();
    for (final word in words) {
      final digit = map[word];
      if (digit != null) {
        buffer.write(digit);
      }
    }
    return buffer.toString();
  }

  bool _isYes(String value) {
    final lower = value.toLowerCase();
    return lower.contains('aama') ||
        lower.contains('ஆம்') ||
        lower.contains('ஆமா') ||
        lower.contains('ஆமாம்') ||
        lower.contains('yes') ||
        lower.contains('சரி');
  }

  bool _isNo(String value) {
    final lower = value.toLowerCase();
    return lower.contains('illai') ||
        lower.contains('இல்லை') ||
        lower.contains('no');
  }

  Future<void> _askName() async {
    await _promptStep(
      step: VoiceState.listeningName,
      prompt: _promptForState(VoiceState.listeningName),
    );
  }

  Future<void> _askPhone() async {
    await _promptStep(
      step: VoiceState.listeningPhone,
      prompt: _promptForState(VoiceState.listeningPhone),
    );
  }

  Future<void> _askConfirmation() async {
    await _promptStep(
      step: VoiceState.confirming,
      prompt: _promptForState(VoiceState.confirming),
    );
  }

  Future<String?> _recordSample(String prefix, String prompt) async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      return null;
    }

    final path = await _createAudioPath(prefix);

    await TamilTts.speak(_tts, prompt);

    if (kIsWeb) {
      await _audioRecorder.start(const RecordConfig(), path: path);
    } else {
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    }

    await Future.delayed(const Duration(seconds: 3));
    final stopped = await _audioRecorder.stop();
    return stopped ?? path;
  }

  Future<void> _finalizeRegistration() async {
    if (_isBusy) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() {
        _status = _language == VoiceLanguage.tamil
            ? 'பெயரும் எண்ணும் தேவை.'
            : 'Name and phone are required.';
      });
      _askName();
      return;
    }

    setState(() {
      _isBusy = true;
      _state = VoiceState.registering;
      _status = _promptForState(VoiceState.registering);
    });

    try {
      final samples = <String>[];
      final nameSample = _stepSamplePaths[VoiceState.listeningName];
      final phoneSample = _stepSamplePaths[VoiceState.listeningPhone];
      if (nameSample != null && nameSample.isNotEmpty) {
        samples.add(nameSample);
      }
      if (phoneSample != null && phoneSample.isNotEmpty) {
        samples.add(phoneSample);
      }

      if (samples.length < 2) {
        final sample1 = await _recordSample(
          'reg1',
          'உங்கள் பெயரை மீண்டும் சொல்லுங்கள்.',
        );
        if (sample1 != null && sample1.isNotEmpty) {
          samples.add(sample1);
        }
      }
      if (samples.length < 2) {
        final sample2 = await _recordSample(
          'reg2',
          'உங்கள் குரலை இன்னொரு முறை சொல்லுங்கள்.',
        );
        if (sample2 != null && sample2.isNotEmpty) {
          samples.add(sample2);
        }
      }

      if (samples.length < 2) {
        throw Exception('Voice sample capture failed');
      }

      final response = await ApiService.register(
        name: name,
        phone: phone,
        audioFilePaths: samples.take(3).toList(),
      );

      if (!mounted) return;
      if (response['success'] == true) {
        final successText = _language == VoiceLanguage.tamil
            ? 'பதிவு முடிந்தது. விற்பனை பக்கத்திற்கு செல்கிறோம்.'
            : 'Registration complete. Opening seller dashboard.';
        await TamilTts.speak(
          _tts,
          successText,
          primaryLanguage: _language == VoiceLanguage.tamil ? 'ta-IN' : 'en-US',
          allowEnglishFallback: _language == VoiceLanguage.english,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SellerDashboard()),
        );
        return;
      }

      setState(() {
        _isBusy = false;
        _state = VoiceState.confirming;
        _status =
            (response['message'] ??
                    (_language == VoiceLanguage.tamil
                        ? 'பதிவு தோல்வி'
                        : 'Registration failed'))
                .toString();
      });
      await TamilTts.speak(
        _tts,
        _language == VoiceLanguage.tamil
            ? 'பதிவு செய்ய முடியவில்லை. மீண்டும் முயற்சி செய்யலாம்.'
            : 'Registration failed. Please try again.',
        primaryLanguage: _language == VoiceLanguage.tamil ? 'ta-IN' : 'en-US',
        allowEnglishFallback: _language == VoiceLanguage.english,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _state = VoiceState.confirming;
        _status = _language == VoiceLanguage.tamil
            ? 'பதிவு தோல்வி. மைக்ரோஃபோன் அல்லது சர்வர் இணைப்பை சரிபார்க்கவும்.'
            : 'Registration failed. Check microphone or server connection.';
      });
      await TamilTts.speak(
        _tts,
        _language == VoiceLanguage.tamil
            ? 'பதிவு தோல்வி. மீண்டும் முயற்சி செய்யலாம்.'
            : 'Registration failed. Please try again.',
        primaryLanguage: _language == VoiceLanguage.tamil ? 'ta-IN' : 'en-US',
        allowEnglishFallback: _language == VoiceLanguage.english,
      );
    }
  }

  Future<void> _repeatCurrentStep() async {
    switch (_state) {
      case VoiceState.listeningName:
        await _askName();
        break;
      case VoiceState.listeningPhone:
        await _askPhone();
        break;
      case VoiceState.confirming:
        await _askConfirmation();
        break;
      case VoiceState.registering:
        break;
    }
  }

  Future<void> _setLanguage(VoiceLanguage language) async {
    if (_language == language) return;
    setState(() {
      _language = language;
      _status = language == VoiceLanguage.tamil
          ? 'தமிழ் தேர்வு செய்யப்பட்டது.'
          : 'English selected.';
    });
    await _resolveLocaleForLanguage();
    await _queueNextPrompt(_startCurrentStatePrompt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _language == VoiceLanguage.tamil
              ? 'விற்பனை உள்நுழைவு'
              : 'Seller Voice Login',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Icon(
              _isListening ? Icons.graphic_eq : Icons.record_voice_over,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            if (_isListening)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 4),
              ),
            const SizedBox(height: 12),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansTamil(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('English'),
                  selected: _language == VoiceLanguage.english,
                  onSelected: (_) => _setLanguage(VoiceLanguage.english),
                ),
                ChoiceChip(
                  label: const Text('தமிழ்'),
                  selected: _language == VoiceLanguage.tamil,
                  onSelected: (_) => _setLanguage(VoiceLanguage.tamil),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _language == VoiceLanguage.tamil
                    ? 'விற்பனையாளர் பெயர்'
                    : 'Seller Name',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: _language == VoiceLanguage.tamil
                    ? 'அலைபேசி எண்'
                    : 'Phone Number',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      (_isBusy || _isListening || !_speechReady || _isPrompting)
                      ? null
                      : _repeatCurrentStep,
                  icon: const Icon(Icons.mic),
                  label: Text(
                    _language == VoiceLanguage.tamil ? 'பேசு' : 'Speak',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: (_isBusy || _isListening)
                      ? null
                      : _repeatCurrentStep,
                  icon: const Icon(Icons.replay),
                  label: Text(
                    _language == VoiceLanguage.tamil
                        ? 'மீண்டும் கேள்'
                        : 'Repeat Question',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: (_isBusy || _isListening)
                      ? null
                      : () {
                          setState(() {
                            _nameController.clear();
                            _phoneController.clear();
                            _stepSamplePaths.clear();
                            _status = _language == VoiceLanguage.tamil
                                ? 'மீண்டும் ஆரம்பிக்கிறோம்...'
                                : 'Restarting...';
                            _state = VoiceState.listeningName;
                          });
                          _askName();
                        },
                  icon: const Icon(Icons.restart_alt),
                  label: Text(
                    _language == VoiceLanguage.tamil
                        ? 'ஆரம்பத்திலிருந்து'
                        : 'Start Over',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

enum AuthRecordingTarget { registration, login }

class _SellerDashboardState extends State<SellerDashboard> {
  static const String _sessionBoxName = 'session';
  static const String _sessionIdKey = 'device_session_id';
  static const String _sessionPhoneKey = 'seller_phone';
  static const String _sessionNameKey = 'seller_name';

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _sellerNameController = TextEditingController();
  final TextEditingController _sellerPhoneController = TextEditingController();

  bool _isListening = false;
  bool _isAuthBusy = false;
  bool _isAuthRecording = false;

  String _text = "";
  String _authStatus = "Backend status not checked yet.";
  String _deviceSessionId = '';
  bool _sessionReady = false;
  AuthRecordingTarget? _activeRecordingTarget;
  String? _activeRecordingPath;
  final List<String> _registrationAudioPaths = [];
  String? _loginAudioPath;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _bootstrapZeroLoginSession();
    _checkBackendConnection();
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _audioRecorder.dispose();
    _sellerNameController.dispose();
    _sellerPhoneController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  Future<void> _bootstrapZeroLoginSession() async {
    final box = Hive.box(_sessionBoxName);

    var sessionId = box.get(_sessionIdKey)?.toString();
    if (sessionId == null || sessionId.isEmpty) {
      sessionId = 'device-${DateTime.now().millisecondsSinceEpoch}';
      await box.put(_sessionIdKey, sessionId);
    }

    final savedPhone = (box.get(_sessionPhoneKey) ?? '').toString();
    final savedName = (box.get(_sessionNameKey) ?? '').toString();

    if (!mounted) return;
    setState(() {
      _deviceSessionId = sessionId!;
      _sessionReady = true;
      if (savedPhone.isNotEmpty) {
        _sellerPhoneController.text = savedPhone;
      }
      if (savedName.isNotEmpty) {
        _sellerNameController.text = savedName;
      }
      _authStatus = savedPhone.isNotEmpty
          ? 'Zero-login active. Session restored.'
          : 'Zero-login active. Device session ready.';
    });
  }

  Future<void> _persistSessionProfile() async {
    final box = Hive.box(_sessionBoxName);
    final name = _sellerNameController.text.trim();
    final phone = _sellerPhoneController.text.trim();

    if (name.isNotEmpty) {
      await box.put(_sessionNameKey, name);
    }
    if (phone.isNotEmpty) {
      await box.put(_sessionPhoneKey, phone);
    }
  }

  Future<void> _checkBackendConnection() async {
    try {
      final response = await ApiService.health();
      final message = (response['message'] ?? 'Backend connected').toString();
      if (!mounted) return;
      setState(() {
        _authStatus = message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authStatus = 'Could not reach backend. Check IP and Flask server.';
      });
    }
  }

  Future<String> _createAudioPath(String prefix) async {
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now().millisecondsSinceEpoch;
    return '${tempDir.path}/$prefix-$now.wav';
  }

  Future<void> _toggleAuthRecording(AuthRecordingTarget target) async {
    if (_isAuthBusy) return;

    if (_isAuthRecording) {
      if (_activeRecordingTarget != target) {
        setState(() {
          _authStatus = 'Finish current recording before switching mode.';
        });
        return;
      }

      final stoppedPath = await _audioRecorder.stop();
      final savedPath = stoppedPath ?? _activeRecordingPath;

      if (!mounted) return;
      setState(() {
        _isAuthRecording = false;
        _activeRecordingPath = null;
        _activeRecordingTarget = null;
      });

      if (savedPath == null || savedPath.isEmpty) {
        setState(() {
          _authStatus = 'Recording failed. Please try again.';
        });
        return;
      }

      if (target == AuthRecordingTarget.registration) {
        if (_registrationAudioPaths.length >= 3) {
          setState(() {
            _authStatus =
                'Registration supports only 3 samples. Clear to re-record.';
          });
          return;
        }

        setState(() {
          _registrationAudioPaths.add(savedPath);
          _authStatus =
              'Registration sample ${_registrationAudioPaths.length} recorded.';
        });
      } else {
        setState(() {
          _loginAudioPath = savedPath;
          _authStatus = 'Login sample recorded.';
        });
      }

      return;
    }

    if (target == AuthRecordingTarget.registration &&
        _registrationAudioPaths.length >= 3) {
      setState(() {
        _authStatus = 'You already have 3 registration samples.';
      });
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      setState(() {
        _authStatus = 'Microphone permission denied for recording.';
      });
      return;
    }

    final path = await _createAudioPath(
      target == AuthRecordingTarget.registration ? 'register' : 'login',
    );

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    if (!mounted) return;
    setState(() {
      _isAuthRecording = true;
      _activeRecordingPath = path;
      _activeRecordingTarget = target;
      _authStatus = target == AuthRecordingTarget.registration
          ? 'Recording registration sample... tap again to stop.'
          : 'Recording login sample... tap again to stop.';
    });
  }

  Future<void> _registerSellerVoice() async {
    if (_isAuthBusy || _isAuthRecording) return;

    final name = _sellerNameController.text.trim();
    final phone = _sellerPhoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() {
        _authStatus = 'Enter seller name and phone first.';
      });
      return;
    }

    if (_registrationAudioPaths.length < 2 ||
        _registrationAudioPaths.length > 3) {
      setState(() {
        _authStatus = 'Record 2 or 3 samples before registering.';
      });
      return;
    }

    setState(() {
      _isAuthBusy = true;
      _authStatus = 'Registering voice profile...';
    });

    try {
      final response = await ApiService.register(
        name: name,
        phone: phone,
        audioFilePaths: List<String>.from(_registrationAudioPaths),
      );
      final success = response['success'] == true;

      if (!mounted) return;
      setState(() {
        _isAuthBusy = false;
        _authStatus = (response['message'] ?? 'Registration completed')
            .toString();
        if (success) {
          _registrationAudioPaths.clear();
        }
      });

      if (success) {
        await _persistSessionProfile();
        await TamilTts.speak(_tts, 'குரல் பதிவு வெற்றிகரமாக சேமிக்கப்பட்டது');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAuthBusy = false;
        _authStatus =
            'Registration request failed. Check backend IP and server.';
      });
    }
  }

  Future<void> _loginWithVoice() async {
    if (_isAuthBusy || _isAuthRecording) return;

    final samplePath = _loginAudioPath;
    if (samplePath == null || samplePath.isEmpty) {
      setState(() {
        _authStatus = 'Record a login sample first.';
      });
      return;
    }

    setState(() {
      _isAuthBusy = true;
      _authStatus = 'Authenticating voice...';
    });

    try {
      final response = await ApiService.login(
        audioFilePath: samplePath,
        phone: _sellerPhoneController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isAuthBusy = false;
        final message = (response['message'] ?? 'Login completed').toString();
        final score = response['confidence_score'];
        _authStatus = score == null ? message : '$message (score: $score)';
      });

      if (response['authenticated'] == true) {
        await TamilTts.speak(_tts, 'உள்நுழைவு வெற்றி');
      } else {
        await TamilTts.speak(_tts, 'குரல் சரிபார்ப்பு தோல்வி');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAuthBusy = false;
        _authStatus = 'Login request failed. Check backend connection.';
      });
    }
  }

  Widget _buildVoiceAuthPanel() {
    final isRecordingRegistration =
        _isAuthRecording &&
        _activeRecordingTarget == AuthRecordingTarget.registration;
    final isRecordingLogin =
        _isAuthRecording && _activeRecordingTarget == AuthRecordingTarget.login;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          'Voice Login (Backend)',
          style: GoogleFonts.notoSansTamil(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Samples: ${_registrationAudioPaths.length}/3, Login: ${_loginAudioPath == null ? 'No' : 'Ready'}',
          style: GoogleFonts.notoSansTamil(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _sessionReady
                  ? 'Session ID: $_deviceSessionId'
                  : 'Preparing device session...',
              style: GoogleFonts.notoSansTamil(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sellerNameController,
            onChanged: (_) => unawaited(_persistSessionProfile()),
            decoration: const InputDecoration(
              labelText: 'Seller Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sellerPhoneController,
            keyboardType: TextInputType.phone,
            onChanged: (_) => unawaited(_persistSessionProfile()),
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _isAuthBusy
                    ? null
                    : () => _toggleAuthRecording(
                        AuthRecordingTarget.registration,
                      ),
                icon: Icon(isRecordingRegistration ? Icons.stop : Icons.mic),
                label: Text(
                  isRecordingRegistration
                      ? 'Stop Register Sample'
                      : 'Record Register Sample',
                ),
              ),
              OutlinedButton(
                onPressed: _isAuthBusy || _isAuthRecording
                    ? null
                    : () {
                        setState(() {
                          _registrationAudioPaths.clear();
                          _authStatus = 'Registration samples cleared.';
                        });
                      },
                child: const Text('Clear Samples'),
              ),
              ElevatedButton(
                onPressed: _isAuthBusy || _isAuthRecording
                    ? null
                    : _registerSellerVoice,
                child: Text(_isAuthBusy ? 'Please wait...' : 'Register Voice'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _isAuthBusy
                    ? null
                    : () => _toggleAuthRecording(AuthRecordingTarget.login),
                icon: Icon(
                  isRecordingLogin ? Icons.stop : Icons.record_voice_over,
                ),
                label: Text(
                  isRecordingLogin
                      ? 'Stop Login Sample'
                      : 'Record Login Sample',
                ),
              ),
              ElevatedButton(
                onPressed: _isAuthBusy || _isAuthRecording
                    ? null
                    : _loginWithVoice,
                child: Text(_isAuthBusy ? 'Please wait...' : 'Login Voice'),
              ),
              OutlinedButton(
                onPressed: _isAuthBusy ? null : _checkBackendConnection,
                child: const Text('Check Backend'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _authStatus,
              style: GoogleFonts.notoSansTamil(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _listen() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) return;

      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        await TamilTts.speak(_tts, "கேட்கிறேன்... பேசுங்கள்");

        _speech.listen(
          onResult: (val) {
            setState(() {
              _text = val.recognizedWords;
            });
            if (val.finalResult) {
              _processIntent(_text);
            }
          },
          localeId: 'ta_IN',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _processIntent(String text) async {
    if (text.isEmpty) return;

    String? product;
    String? priceStr;

    if (text.contains("தக்காளி")) {
      product = "தக்காளி";
    } else if (text.contains("உருளை")) {
      product = "உருளைக்கிழங்கு";
    }

    RegExp regex = RegExp(r'\d+');
    var matches = regex.allMatches(text);
    if (matches.isNotEmpty) {
      priceStr = matches.first.group(0);
    }

    if (product != null && priceStr != null) {
      var box = Hive.box('products');
      box.add({"name": product, "price": "$priceStr/கிலோ"});
      await TamilTts.speak(
        _tts,
        "$product $priceStr ரூபாய்க்கு சேர்க்கப்பட்டது.",
      );
      setState(() {
        _isListening = false;
        _speech.stop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var box = Hive.box('products');

    return Scaffold(
      appBar: AppBar(title: const Text('விற்பனை பக்கம்')),
      body: Column(
        children: [
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _listen,
            child:
                CircleAvatar(
                      radius: 60,
                      backgroundColor: _isListening
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                      child: const Icon(
                        Icons.mic,
                        size: 60,
                        color: Colors.white,
                      ),
                    )
                    .animate(target: _isListening ? 1 : 0)
                    .scale(end: const Offset(1.2, 1.2)),
          ),
          const SizedBox(height: 20),
          Text(
            "தட்டி பேசுங்கள்:",
            style: GoogleFonts.notoSansTamil(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '"தக்காளி 20 ரூபாய்க்கு விற்கணும்"',
            style: GoogleFonts.notoSansTamil(fontSize: 16),
          ),
          const SizedBox(height: 20),
          if (_text.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "குரல்: $_text",
                style: GoogleFonts.notoSansTamil(fontSize: 18),
              ),
            ),
          _buildVoiceAuthPanel(),
          const SizedBox(height: 20),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box products, _) {
                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    var prod = products.getAt(index);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.inventory_2_outlined,
                          size: 30,
                        ),
                        title: Text(
                          prod['name'],
                          style: GoogleFonts.notoSansTamil(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          "₹${prod['price']}",
                          style: GoogleFonts.notoSansTamil(fontSize: 18),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            box.deleteAt(index);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BuyerDiscovery extends StatefulWidget {
  const BuyerDiscovery({super.key});

  @override
  State<BuyerDiscovery> createState() => _BuyerDiscoveryState();
}

class _BuyerDiscoveryState extends State<BuyerDiscovery> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _searchQuery = "";

  void _listen() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) return;

      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        await TamilTts.speak(_tts, "என்ன வேணும்? பேசுங்கள்");

        _speech.listen(
          onResult: (val) {
            setState(() {
              _searchQuery = val.recognizedWords;
            });
            if (val.finalResult) {
              _handleSearch(_searchQuery);
            }
          },
          localeId: 'ta_IN',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _handleSearch(String query) async {
    if (query.isEmpty) return;

    var box = Hive.box('products');
    int count = 0;
    for (var i = 0; i < box.length; i++) {
      var p = box.getAt(i);
      if (query.contains(p['name'].split(' ')[0])) {
        count++;
      }
    }

    if (count > 0) {
      await TamilTts.speak(_tts, "$count பொருட்கள் கிடைக்கின்றன");
    } else {
      await TamilTts.speak(_tts, "மன்னிக்கவும், இப்போது கிடைக்கவில்லை");
    }

    setState(() {
      _isListening = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    var box = Hive.box('products');

    return Scaffold(
      appBar: AppBar(title: const Text('வாங்கும் பக்கம்')),
      body: Column(
        children: [
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _listen,
            child:
                CircleAvatar(
                      radius: 60,
                      backgroundColor: _isListening
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                      child: const Icon(
                        Icons.mic,
                        size: 60,
                        color: Colors.white,
                      ),
                    )
                    .animate(target: _isListening ? 1 : 0)
                    .scale(end: const Offset(1.2, 1.2)),
          ),
          const SizedBox(height: 20),
          Text(
            "தட்டி பேசுங்கள்:",
            style: GoogleFonts.notoSansTamil(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '"காய்கறி காட்டு"',
            style: GoogleFonts.notoSansTamil(fontSize: 16),
          ),
          const SizedBox(height: 20),
          if (_searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "தேடல்: $_searchQuery",
                style: GoogleFonts.notoSansTamil(fontSize: 18),
              ),
            ),
          const SizedBox(height: 10),
          const Divider(),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box products, _) {
                var filtered = products.values
                    .where(
                      (p) =>
                          _searchQuery.isEmpty ||
                          p['name'].toString().contains(
                            _searchQuery.split(' ')[0],
                          ),
                    )
                    .toList();

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    var prod = filtered[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.shopping_basket_outlined,
                          size: 30,
                        ),
                        title: Text(
                          prod['name'],
                          style: GoogleFonts.notoSansTamil(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          "₹${prod['price']}",
                          style: GoogleFonts.notoSansTamil(fontSize: 18),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.call),
                          label: const Text("தொடர்பு கொள்"),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
