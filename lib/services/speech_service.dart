// =============================================
// Speech Service — DISABLED (Trial Version)
//
// Voice recording and speech-to-text features
// are planned for a future release.
// This stub maintains compile-time compatibility.
// =============================================

class SpeechService {
  static bool _hasPermission = false;

  static Future<bool> init() async {
    _hasPermission = false;
    return false;
  }

  static Future<void> startListening(Function(String) onResult) async {
    // Disabled in trial
  }

  static Future<void> stopListening() async {
    // Disabled in trial
  }

  static bool get isListening => false;
}

/// A model to hold Ramble entries (retained for data model compatibility)
class RambleEntry {
  final String id;
  final String content;
  final DateTime date;
  final String creatorId;
  final bool isGeneral;
  final String? clientId;

  RambleEntry({
    required this.id,
    required this.content,
    required this.date,
    required this.creatorId,
    this.isGeneral = true,
    this.clientId,
  });
}
