// =============================================
// Gemini Voice Gateway — DISABLED (Trial Version)
//
// Recording & AI transcription features are planned
// for a future release with proper API configuration.
// This stub exists to maintain compile-time compatibility.
// =============================================
import '../models/project_module.dart';

class GeminiVoiceGateway {
  GeminiVoiceGateway();

  /// Disabled — returns empty result for trial build.
  Future<Map<String, dynamic>> processVoiceToProject(
    String rawTranscript,
    List<Project> activeProjects, {
    String? targetClientId,
  }) async {
    return {
      'matchedProjectId': null,
      'suggestedTasks': <Map<String, dynamic>>[],
      'milestoneUpdates': <String>[],
      'disabled': true,
      'message': 'AI processing is not available in the trial version.',
    };
  }
}
