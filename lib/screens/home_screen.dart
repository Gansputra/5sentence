import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';
import '../services/gemini_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _wordController = TextEditingController();
  String? _selectedModel;
  bool _isLoading = false;
  List<String> _sentences = [];
  final GeminiService _geminiService = GeminiService();

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  String? _selectedModelName = AppConstants.models.keys.first;

  void _validateAndGenerate() {
    final input = _wordController.text.trim();

    // Validation
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
    setState(() {
      _isLoading = true;
      _sentences = [];
    });

    try {
      final modelId = AppConstants.models[_selectedModelName]!;
      final results = await _geminiService.generateSentences(word, modelId);
      setState(() {
        _sentences = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('UI Error Catch: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString().replaceAll('Exception: ', '')}"),
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

  void _copyToClipboard() {
    if (_sentences.isEmpty) return;
    final text = _sentences.asMap().entries.map((e) => "${e.key + 1}. ${e.value}").join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copied to clipboard!")),
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
        actions: [
          if (_sentences.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_all),
              onPressed: _copyToClipboard,
              tooltip: "Copy All Sentences",
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input TextField
            TextField(
              controller: _wordController,
              decoration: InputDecoration(
                labelText: "Enter English Word",
                hintText: "e.g. Serendipity",
                prefixIcon: const Icon(Icons.abc),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              onChanged: (_) => setState(() {}),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 16),

            // New Dropdown Selector
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

            // Generate Button
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
              const SizedBox(height: 12),
              ..._sentences.asMap().entries.map((entry) {
                int idx = entry.key;
                String sentence = entry.value;
                return _buildSentenceCard(idx + 1, sentence);
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
                      "Requesting Gemini 2.5 Flash...",
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

  Widget _buildSentenceCard(int number, String text) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                number.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (number * 100).ms).slideX(begin: 0.1, end: 0);
  }
}
