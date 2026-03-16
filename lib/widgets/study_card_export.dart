import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sentence_pair.dart';
import '../config/theme_config.dart';

class StudyCardExport extends StatelessWidget {
  final String word;
  final List<SentencePair> sentences;
  final AppTheme theme;

  const StudyCardExport({
    super.key,
    required this.word,
    required this.sentences,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(1080, 1920), devicePixelRatio: 3.0),
      child: Theme(
        data: AppTheme.getThemeData(theme),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: 1080,
            height: 1920,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.seedColor,
                  theme.seedColor.withOpacity(0.9),
                  theme.seedColor.withOpacity(0.8),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Decorative Background Elements
                Positioned(
                  top: -150,
                  right: -150,
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 300,
                  left: -100,
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(60.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "WORD OF THE DAY",
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.7),
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                word.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 80,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.auto_stories,
                            size: 90,
                            color: Colors.white,
                          ),
                        ],
                      ),

                      const SizedBox(height: 60),

                      // Use Column instead of ListView for static capture
                      ...sentences.asMap().entries.map((entry) {
                        final index = entry.key;
                        final pair = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 30.0),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(32),
                            opacity: 0.15,
                            blur: 15,
                            borderRadius: BorderRadius.circular(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.white.withOpacity(
                                        0.2,
                                      ),
                                      child: Text(
                                        "${index + 1}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: Text(
                                        pair.english,
                                        style: GoogleFonts.inter(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.only(left: 72),
                                  child: Text(
                                    pair.indonesian,
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const Spacer(),

                      // Branding
                      Center(
                        child: Column(
                          children: [
                            Text(
                              "Created with 5Sentence App",
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 6,
                              width: 120,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
