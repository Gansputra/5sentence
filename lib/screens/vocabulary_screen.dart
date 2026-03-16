import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/vocabulary.dart';
import '../services/database_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../models/sentence_pair.dart';
import '../config/theme_config.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Vocabulary> _vocabularyList = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadVocabulary();
  }

  Future<void> _loadVocabulary() async {
    setState(() => _isLoading = true);
    final list = await _dbService.getAllVocabulary();
    setState(() {
      _vocabularyList = list;
      _isLoading = false;
    });
  }

  List<Vocabulary> get _filteredList {
    if (_searchQuery.isEmpty) return _vocabularyList;
    return _vocabularyList.where((v) => 
      v.word.contains(_searchQuery.toLowerCase()) || 
      v.meaning.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      v.category.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "My Vocabulary",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _showClearDialog(),
            tooltip: "Clear All",
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search words or categories...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredList.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredList.length,
                      itemBuilder: (context, index) {
                        final vocab = _filteredList[index];
                        return _buildVocabCard(vocab, index);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildVocabCard(Vocabulary vocab, int index) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.transparent,
      child: GlassContainer(
        opacity: 0.08,
        borderRadius: BorderRadius.circular(16),
        blur: 10,
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                vocab.word,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.volume_up_rounded,
                color: theme.colorScheme.primary.withOpacity(0.7),
                size: 20,
              ),
              onPressed: () => TtsService().speak(vocab.word),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "Listen",
            ),
          ],
        ),
        onTap: () {
          if (vocab.sentences.isNotEmpty) {
            _showDetailDialog(vocab);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No saved sentences for this word.")),
            );
          }
        },
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              vocab.meaning,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (vocab.meaningId.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                vocab.meaningId,
                style: GoogleFonts.inter(
                  fontSize: 13, 
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                vocab.category,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () async {
            await _dbService.deleteVocabularyByWord(vocab.word);
            _loadVocabulary();
          },
        ),
      ),
    ),
  ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05, end: 0);
}

  void _showDetailDialog(Vocabulary vocab) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vocab.word,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        vocab.meaning,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (vocab.meaningId.isNotEmpty)
                        Text(
                          vocab.meaningId,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    vocab.category,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: vocab.sentences.length,
                itemBuilder: (context, index) {
                  final pair = vocab.sentences[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${index + 1}.",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pair.english,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up_rounded, size: 18),
                              onPressed: () => TtsService().speak(pair.english),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.mic_none_rounded, size: 18),
                              onPressed: () => _showPracticeDialog(pair),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 28, top: 4),
                          child: Text(
                            pair.indonesian,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1, end: 0);
                },
              ),
            ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            "No vocabulary yet",
            style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text("Generate some sentences to start building your list!"),
        ],
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All Vocabulary?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _dbService.clearAll();
              Navigator.pop(context);
              _loadVocabulary();
            }, 
            child: const Text("Clear", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}
