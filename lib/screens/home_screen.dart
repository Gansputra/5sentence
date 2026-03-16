import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';
import '../models/sentence_pair.dart';
import '../models/vocabulary.dart';
import '../models/api_key_model.dart';
import 'settings_screen.dart';
import 'vocabulary_screen.dart';
import '../services/tts_service.dart';
import '../config/theme_config.dart';
import '../widgets/study_card_export.dart';
import '../services/speech_service.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _wordController = TextEditingController();
  bool _isLoading = false;
  List<SentencePair> _sentences = [];
  final GeminiService _geminiService = GeminiService();
  final StorageService _storageService = StorageService();
  final DatabaseService _dbService = DatabaseService();

  List<ApiKey> _apiKeys = [];
  ApiKey? _activeKey;
  
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
  }

  Future<void> _loadApiKeys() async {
    final keys = await _storageService.getAllApiKeys();
    ApiKey? active;
    try {
      active = keys.firstWhere((k) => k.isActive);
    } catch (_) {
      active = keys.isNotEmpty ? keys.first : null;
    }
    
    setState(() {
      _apiKeys = keys;
      _activeKey = active;
    });

    if (active == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set your Gemini API Key in Settings to start.'),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.blueAccent,
          ),
        );
      });
    }
  }

  Future<void> _checkApiKey() async {
    // This is now handled by _loadApiKeys
  }

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  String? _selectedModelName = AppConstants.models.keys.first;

  void _validateAndGenerate() {
    final input = _wordController.text.trim();

    if (input.isEmpty || 
        input.contains(' ') || 
        !RegExp(r'^[a-zA-Z]+$').hasMatch(input)) {
      _showAlertDialog("Input must be a single valid English word.");
      return;
    }

    if (_selectedModelName == null) return;

    _generateSentences(input);
  }

  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid Input'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateSentences(String word) async {
    final key = await _storageService.getActiveKey();
    if (key == null || key.isEmpty) {
      _showApiKeyMissingDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _sentences = [];
    });

    try {
      final modelId = AppConstants.models[_selectedModelName]!;
      final response = await _geminiService.generateContent(word, modelId);
      
      setState(() {
        _sentences = response.sentences;
        _isLoading = false;
      });

      // Save vocabulary to local database
      // We attach the 5 sentences to ALL vocabulary words generated in this session 
      // so they all have context.
      for (var vocab in response.vocabulary) {
        final vocabWithSentences = Vocabulary(
          id: vocab.id,
          word: vocab.word.trim(), // Clean up any spaces
          ipa: vocab.ipa,
          meaning: vocab.meaning,
          meaningId: vocab.meaningId,
          category: vocab.category,
          sentences: response.sentences,
        );
        await _dbService.insertVocabulary(vocabWithSentences);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Saved ${response.vocabulary.length} new words to your vocabulary!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const VocabularyScreen())
              ),
            ),
          ),
        );
      }
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('UI Error Catch: $e');
      
      final errorStr = e.toString();
      if (errorStr.contains('API Key is missing')) {
        _showApiKeyMissingDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${errorStr.replaceAll('Exception: ', '')}"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _validateAndGenerate,
            ),
          ),
        );
      }
    }
  }

  void _showApiKeyMissingDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.key_off_rounded, color: Colors.amber, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                "API Key Required",
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "To use the sentence generator, you need to provide your own Gemini API key in the settings.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Later", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("Go to Settings", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
      ),
    );
  }

  Future<void> _exportAsImage() async {
    if (_sentences.isEmpty) return;

    final themeName = themeNotifier.value;
    final currentTheme = AppTheme.themes.firstWhere((t) => t.name == themeName);

    // Create the widget we want to screenshot
    final exportWidget = StudyCardExport(
      word: _wordController.text.trim(),
      sentences: _sentences,
      theme: currentTheme,
    );

    setState(() => _isLoading = true);

    try {
      final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
        exportWidget,
        delay: const Duration(milliseconds: 200),
        targetSize: const Size(1080, 1920),
      );

      if (imageBytes != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/study_card.png').create();
        await imagePath.writeAsBytes(imageBytes);

        await Share.shareXFiles(
          [XFile(imagePath.path)],
          text: 'Check out my new vocabulary word: ${_wordController.text.trim()}!',
        );
      }
    } catch (e) {
      print("Export error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to export image: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportAsPdf() async {
    if (_sentences.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.interRegular();
      final fontBold = await PdfGoogleFonts.outfitBold();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Vocabulary Study Note", style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.grey700)),
                  pw.SizedBox(height: 8),
                  pw.Text(_wordController.text.trim().toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 36, color: PdfColors.teal)),
                  pw.SizedBox(height: 32),
                  pw.Divider(),
                  pw.SizedBox(height: 32),
                  ..._sentences.asMap().entries.map((entry) {
                    final index = entry.key;
                    final pair = entry.value;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 24),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("${index + 1}. ", style: pw.TextStyle(font: fontBold, fontSize: 16)),
                              pw.Expanded(child: pw.Text(pair.english, style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold))),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20),
                            child: pw.Text(pair.indonesian, style: pw.TextStyle(font: font, fontSize: 14, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                          ),
                        ],
                      ),
                    );
                  }),
                  pw.Spacer(),
                  pw.Divider(),
                  pw.SizedBox(height: 8),
                  pw.Center(child: pw.Text("Created with 5Sentence App", style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey500))),
                ],
              ),
            );
          },
        ),
      );

      await Printing.sharePdf(bytes: await pdf.save(), filename: 'study_note_${_wordController.text.trim()}.pdf');
    } catch (e) {
      print("PDF Export error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to export PDF: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Export Sentences",
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.image_outlined, color: Colors.blue),
              ),
              title: const Text("Export as Study Card (Image)"),
              subtitle: const Text("Perfect for Instagram Stories or gallery"),
              onTap: () {
                Navigator.pop(context);
                _exportAsImage();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
              ),
              title: const Text("Export as Study Note (PDF)"),
              subtitle: const Text("Good for printing or long-term archiving"),
              onTap: () {
                Navigator.pop(context);
                _exportAsPdf();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getFeedbackMessage(double score) {
    if (score >= 1.0) return "Perfection! You sound like a native speaker! 🌟";
    if (score >= 0.8) return "Excellent! Almost perfect, keep it up! 🚀";
    if (score >= 0.5) return "Good job! You're clearly getting there. 💪";
    if (score >= 0.3) return "Keep trying! Focus on the rhythm. 🎧";
    return "Don't give up! Look at the sentence and try again. ❤️";
  }

  void _showPracticeDialog(SentencePair pair) {
    String recognizedText = "";
    bool isListening = false;
    double score = 0.0;
    final speechService = SpeechService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Practice Pronunciation",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    pair.english,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (recognizedText.isNotEmpty) ...[
                  Text(
                    "You said:",
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recognizedText,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Score: ",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "${(score * 100).toInt()}%",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: score > 0.8 
                            ? Colors.green 
                            : score > 0.5 
                              ? Colors.orange 
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (score > 0.8 ? Colors.green : score > 0.5 ? Colors.orange : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getFeedbackMessage(score),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: score > 0.8 ? Colors.green : score > 0.5 ? Colors.orange : Colors.red,
                      ),
                    ),
                  ).animate(key: ValueKey(score)).fadeIn().scale(begin: const Offset(0.9, 0.9)),
                ],
                const SizedBox(height: 40),
                GestureDetector(
                  onTapDown: (_) async {
                    await speechService.startListening(
                      onResult: (text) {
                        setModalState(() {
                          recognizedText = text;
                          score = speechService.getSimilarity(recognizedText, pair.english);
                        });
                      },
                      onListeningStateChanged: (listening) {
                        setModalState(() => isListening = listening);
                      },
                    );
                  },
                  onTapUp: (_) async {
                    await speechService.stopListening();
                    setModalState(() => isListening = false);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isListening 
                            ? theme.colorScheme.errorContainer 
                            : theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                          boxShadow: isListening ? [
                            BoxShadow(
                              color: theme.colorScheme.error.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ] : [],
                        ),
                        child: Icon(
                          isListening ? Icons.mic : Icons.mic_none,
                          size: 32,
                          color: isListening 
                            ? theme.colorScheme.error 
                            : theme.colorScheme.primary,
                        ),
                      ).animate(target: isListening ? 1 : 0)
                        .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 200.ms)
                        .boxShadow(end: BoxShadow(color: theme.colorScheme.error.withOpacity(0.3), blurRadius: 20)),
                      const SizedBox(height: 12),
                      Text(
                        isListening ? "Listening..." : "Hold to Speak",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          color: isListening ? theme.colorScheme.error : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _copyToClipboard() {
    if (_sentences.isEmpty) return;
    final text = _sentences.asMap().entries.map((e) => "${e.key + 1}. ${e.value.english}\n   (${e.value.indonesian})").join('\n\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copied sentences and translations!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Word to 5 Sentences",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
            _loadApiKeys(); // Refresh keys when returning from settings
          },
          tooltip: "Settings",
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_stories),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VocabularyScreen()),
              );
            },
            tooltip: "Vocabulary",
          ),
          if (_sentences.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_all),
              onPressed: _copyToClipboard,
              tooltip: "Copy All Sentences",
            ),
          if (_sentences.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _showExportOptions,
              tooltip: "Export Sentences",
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _wordController,
              decoration: InputDecoration(
                labelText: "Enter English Word",
                hintText: "e.g. Serendipity",
                prefixIcon: const Icon(Icons.abc),
                suffixIcon: _wordController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.volume_up_rounded),
                      onPressed: () => TtsService().speak(_wordController.text.trim()),
                      tooltip: "Listen",
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              onChanged: (_) => setState(() {}),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 16),

            if (_apiKeys.isNotEmpty) ...[
              DropdownButtonFormField<ApiKey>(
                value: _activeKey,
                decoration: InputDecoration(
                  labelText: "Active API Key",
                  prefixIcon: const Icon(Icons.key),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                items: _apiKeys.map((k) {
                  return DropdownMenuItem(
                    value: k,
                    child: Text(k.name),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value != null) {
                    await _storageService.setActiveKey(value.id);
                    setState(() => _activeKey = value);
                  }
                },
              ).animate().fadeIn(duration: 400.ms, delay: 50.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 16),
            ],

            DropdownButtonFormField<String>(
              value: _selectedModelName,
              decoration: InputDecoration(
                labelText: "Select Stable Model",
                prefixIcon: const Icon(Icons.auto_awesome),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              items: AppConstants.models.keys.map((name) {
                return DropdownMenuItem(
                  value: name,
                  child: Text(name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedModelName = value;
                });
              },
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: (_isLoading || _wordController.text.trim().isEmpty || _selectedModelName == null)
                  ? null
                  : _validateAndGenerate,
              icon: _isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                : const Icon(Icons.bolt),
              label: Text(
                _isLoading ? "Generating..." : "Generate Sentences",
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),

            const SizedBox(height: 16),
            Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('https://www.linkedin.com/in/ganang-putra/');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                      children: [
                        const TextSpan(text: "Made By "),
                        TextSpan(
                          text: "Gansputra",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

            if (_sentences.isNotEmpty && !_isLoading) ...[
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    "Results ($_selectedModelName)",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _validateAndGenerate,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Regenerate"),
                  ),
                ],
              ).animate().fadeIn(),
              const SizedBox(height: 8),
              Text(
                "Tap a card to reveal Indonesian translation",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 12),
              ..._sentences.asMap().entries.map((entry) {
                int idx = entry.key;
                SentencePair pair = entry.value;
                return _buildSentenceCard(idx + 1, pair);
              }),
            ],

            if (_isLoading)
               Padding(
                padding: const EdgeInsets.only(top: 64.0),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      "Requesting Gemini AI...",
                      style: GoogleFonts.outfit(
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(),
          ],
        ),
      ),
    );
  }

  Widget _buildSentenceCard(int number, SentencePair pair) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      child: GlassContainer(
        opacity: pair.isTranslated ? 0.2 : 0.08,
        borderRadius: BorderRadius.circular(16),
        blur: 10,
        border: Border.all(
          color: pair.isTranslated ? theme.colorScheme.primary.withOpacity(0.5) : theme.colorScheme.outlineVariant.withOpacity(0.2),
          width: pair.isTranslated ? 2 : 1,
        ),
        child: InkWell(
        onTap: () {
          setState(() {
            pair.isTranslated = !pair.isTranslated;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: pair.isTranslated ? theme.colorScheme.primary : theme.colorScheme.primaryContainer,
                    child: Text(
                      number.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: pair.isTranslated ? theme.colorScheme.onPrimary : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      pair.english,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.volume_up_rounded,
                      color: theme.colorScheme.primary.withOpacity(0.7),
                      size: 20,
                    ),
                    onPressed: () => TtsService().speak(pair.english),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: "Listen",
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.mic_none_rounded,
                      color: theme.colorScheme.secondary.withOpacity(0.7),
                      size: 20,
                    ),
                    onPressed: () => _showPracticeDialog(pair),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: "Practice",
                  ),
                ],
              ),
              if (pair.isTranslated)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0, left: 40.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primaryContainer),
                    ),
                    child: Text(
                      pair.indonesian,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: -0.1, end: 0),
                ),
            ],
          ),
        ),
      ),
    ),
  ).animate().fadeIn(delay: (number * 100).ms).slideX(begin: 0.1, end: 0);
}
}
