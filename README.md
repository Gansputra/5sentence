# 5Sentence

5Sentence is a professional language learning application designed to help users master English vocabulary through contextual AI-generated sentences and interactive pronunciation practice.

## Core Features

- **Contextual Sentence Generation**: Generates 5 high-quality English sentences for any word using the Gemini AI model, complete with accurate Indonesian translations.
- **Interactive Pronunciation Practice**: Advanced Speech-to-Text integration that provides real-time pronunciation scoring and feedback to improve speaking skills.
- **Smart Vocabulary Management**: Locally stores generated words with bilingual definitions (English and Indonesian) for persistent learning.
- **IPA Phonetics Integration**: Provides International Phonetic Alphabet (IPA) symbols for vocabulary to ensure correct pronunciation.
- **Multimodal Learning**: Built-in Text-to-Speech (TTS) functionality for listening practice and local speech recognition for active learning.
- **Professional Export Options**: Supports capturing study cards as high-resolution images or structured PDF documents for offline archiving and sharing.
- **Offline Access**: Once generated, all vocabulary, sentences, and phonetics are accessible without an internet connection.
- **Secure API Management**: Securely store and manage multiple Gemini API keys locally with model selection capabilities (Gemini 1.5 Flash, etc.).

## Technical Architecture

- **Framework**: Flutter (Cross-platform)
- **Database**: Hive (High-performance local storage)
- **AI Integration**: Google Gemini API
- **Design System**: Material 3 with Glassmorphism aesthetics
- **Reliability**: Robust JSON parsing and repair mechanisms for stable AI interactions

## Getting Started

1. Clone the repository.
2. Run `flutter pub get`.
3. Obtain a Gemini API Key from Google AI Studio.
4. Input your API Key into the application settings.
5. Enter a word and begin learning.

Produced by Gansputra.
