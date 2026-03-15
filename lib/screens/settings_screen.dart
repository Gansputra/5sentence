import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import '../models/api_key_model.dart';
import '../services/tts_service.dart';
import '../config/theme_config.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storageService = StorageService();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  
  List<ApiKey> _savedKeys = [];
  bool _obscureText = true;

  List<Map<String, String>> _voices = [];
  Map<String, String>? _selectedVoice;
  bool _isVoicesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
    _loadTtsVoices();
  }

  Future<void> _loadTtsVoices() async {
    setState(() => _isVoicesLoading = true);
    try {
      final voicesData = await TtsService().getVoices();
      final selected = await TtsService().getSelectedVoice();
      
      // Convert to List<Map<String, String>> once
      final allVoices = voicesData.map((v) => Map<String, String>.from(v.cast<String, String>())).toList();
      
      // Filter for English voices
      var enVoices = allVoices.where((v) => v['locale']?.startsWith('en') ?? false).toList();
      
      final finalVoices = enVoices.isNotEmpty ? enVoices : allVoices;

      // Find the matching instance in finalVoices for _selectedVoice to satisfy DropdownButton equality
      Map<String, String>? matchingSelected;
      if (selected != null) {
        try {
          matchingSelected = finalVoices.firstWhere(
            (v) => v['name'] == selected['name'] && v['locale'] == selected['locale']
          );
        } catch (_) {
          // If not found in filtered list, add it to the list so dropdown doesn't crash
          finalVoices.insert(0, selected);
          matchingSelected = selected;
        }
      }
      
      setState(() {
        _voices = finalVoices;
        _selectedVoice = matchingSelected;
        _isVoicesLoading = false;
      });
    } catch (e) {
      setState(() => _isVoicesLoading = false);
      print("Error loading voices: $e");
    }
  }

  Future<void> _loadKeys() async {
    final keys = await _storageService.getAllApiKeys();
    setState(() {
      _savedKeys = keys;
    });
  }

  Future<void> _saveNewKey() async {
    final key = _apiKeyController.text.trim();
    final name = _nameController.text.trim();
    
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("API Key cannot be empty")),
      );
      return;
    }

    await _storageService.saveApiKey(key, name: name.isEmpty ? null : name);
    _apiKeyController.clear();
    _nameController.clear();
    await _loadKeys();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("API Key saved!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings & UI", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader(theme, "App Theme", Icons.palette_outlined),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppTheme.themes.map((appTheme) {
                final isSelected = themeNotifier.value == appTheme.name;
                return InkWell(
                  onTap: () async {
                    await _storageService.setTheme(appTheme.name);
                    themeNotifier.value = appTheme.name;
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: appTheme.seedColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: appTheme.seedColor.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: isSelected 
                          ? Icon(Icons.check, color: appTheme.brightness == Brightness.dark ? Colors.white : Colors.black)
                          : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appTheme.name,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 32),
            
            _buildSectionHeader(theme, "TTS Voice Settings", Icons.record_voice_over),
            const SizedBox(height: 16),
            if (_isVoicesLoading)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<Map<String, String>>(
                value: _selectedVoice,
                decoration: InputDecoration(
                  labelText: "Select English Voice",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.spatial_audio_off),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                hint: const Text("Default System Voice"),
                items: _voices.map((voiceMap) {
                  return DropdownMenuItem<Map<String, String>>(
                    value: voiceMap,
                    child: Text(
                      "${voiceMap['name']} (${voiceMap['locale']})",
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value != null) {
                    await TtsService().setVoice(value);
                    setState(() => _selectedVoice = value);
                    TtsService().speak("This is a sample of the selected voice.");
                  }
                },
              ),
            
            const SizedBox(height: 32),
            
            _buildSectionHeader(theme, "Add New API Key", Icons.add_link),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Key Name (Optional)",
                hintText: "e.g. My Primary Key",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: "Gemini API Key",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saveNewKey,
              icon: const Icon(Icons.save),
              label: const Text("Save Key"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            
            const SizedBox(height: 40),
            
            _buildSectionHeader(theme, "Saved API Keys", Icons.vpn_key),
            const SizedBox(height: 16),
            if (_savedKeys.isEmpty)
              Center(
                child: Text(
                  "No keys saved yet.",
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _savedKeys.length,
                itemBuilder: (context, index) {
                  final apiKey = _savedKeys[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: apiKey.isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                        width: apiKey.isActive ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      title: Text(apiKey.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        "${apiKey.key.substring(0, 8)}...",
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!apiKey.isActive)
                            TextButton(
                              onPressed: () async {
                                await _storageService.setActiveKey(apiKey.id);
                                _loadKeys();
                              },
                              child: const Text("Set Active"),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "Active",
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () async {
                              await _storageService.deleteKey(apiKey.id);
                              _loadKeys();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      opacity: 0.05,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
