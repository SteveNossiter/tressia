import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/project_module.dart';
import '../providers/app_state.dart';
import '../widgets/dialogs/glass_dialog.dart';

/// Full-screen session dashboard with timer, recording, notes, cancel/no-show
class SessionDashboard extends ConsumerStatefulWidget {
  final Session session;
  const SessionDashboard({Key? key, required this.session}) : super(key: key);
  @override
  _SessionDashboardState createState() => _SessionDashboardState();
}

class _SessionDashboardState extends ConsumerState<SessionDashboard> {
  late Session _session;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _sessionFinished = false;
  bool _recordingWasUsed = false;
  final _notesCtrl = TextEditingController();

  // Previous sessions for the same client
  List<Session> _previousSessions = [];

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _notesCtrl.text = _session.therapistNotes;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _elapsedSeconds++);
    });
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) _recordingWasUsed = true;
    });
  }

  void _toggleTimer() {
    if (_timer != null && _timer!.isActive) {
      _timer?.cancel();
      setState(() {});
    } else {
      if (_elapsedSeconds == 0) {
        // First start - prompt for recording
        _promptStartRecording();
      } else {
        _startTimer();
        setState(() {});
      }
    }
  }

  void _promptStartRecording() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Start Session',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Would you like to start recording audio now?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startTimer();
              setState(() {});
            },
            child: const Text('Timer Only'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _isRecording = true;
              _recordingWasUsed = true;
              _startTimer();
              setState(() {});
            },
            child: const Text('Start Recording'),
          ),
        ],
      ),
    );
  }

  void _finishSession() {
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _sessionFinished = true;
      _isProcessing = true;
    });

    // Simulate transcription & translation processing
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        String transcript = "";
        String summary = "";
        String report = "";

        if (_recordingWasUsed) {
          transcript =
              "THERAPIST: How did it feel to work with the clay today?\nCLIENT: It was really grounding. When I was shaping it, I felt like I could actually focus on something instead of my racing thoughts.\nTHERAPIST: What did you notice about the form you created?\nCLIENT: I made it rounded and smooth. I think I wanted something that felt safe and contained. The texture really helped me stay present.";
          summary =
              "Client explored tactile art-making with clay as a grounding exercise. Reported reduced anxiety during creative process. Symbolic content reflects desire for safety and containment.";
          report =
              "--- SESSION REPORT ---\n\nART THERAPY CLINICAL SUMMARY:\nClient engaged with clay-based art therapy intervention. Significant therapeutic benefit observed from sensory engagement with tactile materials.\n\nART PROCESSES & OBSERVATIONS:\n1. Medium: Air-dry clay, hand-building technique.\n2. Symbolic content: Rounded, contained form — indicative of safety-seeking.\n3. Verbal processing: Client connected physical sensations to emotional regulation.\n\nGOALS ADDRESSED:\n1. Sensory grounding in high-anxiety states.\n2. Self-regulation through creative expression.\n\nPLAN:\nContinue clay work alongside watercolour exploration. Introduce visual journaling between sessions.";
        }

        final updated = _session.copyWith(
          status: SessionStatus.completed,
          durationMinutes: (_elapsedSeconds / 60).ceil(),
          therapistNotes: _notesCtrl.text,
          isTranscribed: _recordingWasUsed,
          transcriptText: transcript,
          aiSummary: summary,
          clinicalReport: report,
        );
        ref.read(sessionsProvider.notifier).updateSession(updated);
        setState(() {
          _session = updated;
          _isProcessing = false;
        });
      }
    });
  }

  void _cancelSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Cancel Session',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Would you like to reschedule this session?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // No — send cancellation
              Navigator.pop(ctx);
              final updated = _session.copyWith(
                status: SessionStatus.cancelled,
              );
              ref.read(sessionsProvider.notifier).updateSession(updated);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Session cancelled. Confirmation sent to client/coordinator.',
                  ),
                ),
              );
              Navigator.pop(context);
            },
            child: Text(
              'No, Cancel It',
              style: GoogleFonts.outfit(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null && mounted) {
                final rescheduled = _session.copyWith(
                  date: d,
                  status: SessionStatus.scheduled,
                );
                ref.read(sessionsProvider.notifier).updateSession(rescheduled);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Session rescheduled to ${DateFormat('d MMM yyyy').format(d)}. Confirmation sent.',
                    ),
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Yes, Reschedule'),
          ),
        ],
      ),
    );
  }

  void _markNoShow() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Mark as No Show',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will record the session as missed and notify the client/coordinator that the scheduled appointment was not attended.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(ctx);
              final updated = _session.copyWith(status: SessionStatus.noShow);
              ref.read(sessionsProvider.notifier).updateSession(updated);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Session marked as no show. Notification sent to client/coordinator.',
                  ),
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Confirm No Show'),
          ),
        ],
      ),
    );
  }

  void _deleteSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Session permanently?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will permanently remove this session and all associated notes from the database. This action cannot be undone.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(sessionsProvider.notifier).removeSession(_session.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session deleted permanently.')),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0)
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projects = ref.watch(projectsProvider);
    final client = projects.firstWhere(
      (p) => p.id == _session.clientId,
      orElse: () => projects.first,
    );
    _previousSessions =
        ref
            .watch(sessionsProvider)
            .where(
              (s) =>
                  s.clientId == _session.clientId &&
                  s.id != _session.id &&
                  s.status == SessionStatus.completed,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final totalSeconds = _session.durationMinutes * 60;
    final progress = totalSeconds > 0
        ? (_elapsedSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Session Dashboard',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_sessionFinished) ...[
            TextButton.icon(
              onPressed: _deleteSession,
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              label: Text(
                'Delete',
                style: GoogleFonts.outfit(color: Colors.red),
              ),
            ),
            TextButton.icon(
              onPressed: _cancelSession,
              icon: const Icon(
                Icons.cancel_outlined,
                size: 18,
                color: Colors.red,
              ),
              label: Text(
                'Reschedule', // Changed from Cancel to Reschedule as it opens reschedule dialog
                style: GoogleFonts.outfit(color: Colors.red),
              ),
            ),
            TextButton.icon(
              onPressed: _markNoShow,
              icon: const Icon(
                Icons.person_off_outlined,
                size: 18,
                color: Colors.orange,
              ),
              label: Text(
                'No Show',
                style: GoogleFonts.outfit(color: Colors.orange),
              ),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client header
            _buildClientHeader(client, theme),
            const SizedBox(height: 20),

            // Timer section
            _buildTimerSection(theme, progress),
            const SizedBox(height: 20),

            // Recording controls
            if (!_sessionFinished) _buildRecordingControls(theme),
            if (_sessionFinished) _buildPostSessionInfo(theme),
            const SizedBox(height: 20),

            // Previous session notes (expandable)
            _buildPreviousSessionsPanel(theme),
            const SizedBox(height: 20),

            // Notes section
            _buildNotesSection(theme),
            const SizedBox(height: 20),

            // Photos section
            _buildPhotosSection(theme),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildClientHeader(Project client, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withValues(alpha: 0.12),
            theme.primaryColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
            child: Text(
              '${client.firstName.isNotEmpty ? client.firstName[0] : '?'}${client.lastName.isNotEmpty ? client.lastName[0] : ''}',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.clientName,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${client.clientCode}  •  ${client.clientType}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('EEEE, d MMM').format(_session.date),
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_session.startTime != null)
                Text(
                  _session.startTime!.format(context),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: theme.hintColor,
                  ),
                ),
              Text(
                '${_session.durationMinutes} min planned',
                style: GoogleFonts.outfit(fontSize: 11, color: theme.hintColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSection(ThemeData theme, double progress) {
    final remaining = (_session.durationMinutes * 60) - _elapsedSeconds;
    final isOvertime = remaining < 0;
    final timerColor = isOvertime
        ? Colors.red
        : (_isRecording ? Colors.green : theme.primaryColor);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: timerColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          // Circular progress timer
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(timerColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(_elapsedSeconds),
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: timerColor,
                      ),
                    ),
                    if (_isRecording)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'RECORDING',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      )
                    else if (_sessionFinished)
                      Text(
                        'COMPLETED',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          letterSpacing: 1.5,
                        ),
                      )
                    else
                      Text(
                        'READY',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: theme.hintColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isOvertime && !_sessionFinished)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Session overtime by ${_formatDuration(-remaining)}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            )
          else if (!_sessionFinished)
            Text(
              '${_formatDuration(remaining.clamp(0, 999999))} remaining',
              style: GoogleFonts.outfit(fontSize: 13, color: theme.hintColor),
            ),

          const SizedBox(height: 20),
          // Dedicated Start/Stop controls
          if (!_sessionFinished)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleTimer,
                  icon: Icon(
                    _timer != null && _timer!.isActive
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    _timer != null && _timer!.isActive ? 'Pause' : 'Start',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _timer != null && _timer!.isActive
                        ? Colors.grey
                        : theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                if (_elapsedSeconds > 0) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _finishSession,
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('Finish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRecordingControls(ThemeData theme) {
    return Stack(
      children: [
        // Underlying controls — dimmed
        Opacity(
          opacity: 0.35,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recording',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Microphone',
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          value: 'System Default',
                          items:
                              [
                                    'System Default',
                                    'Built-in Microphone',
                                    'External Mic',
                                    'Bluetooth Headset',
                                  ]
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(
                                        m,
                                        style: GoogleFonts.outfit(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: null, // disabled
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.grey,
                            disabledBackgroundColor: Colors.grey.shade400,
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(Icons.mic_off, size: 28),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.phone_iphone,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Use your phone as a companion — open this session on the mobile app to record from your device microphone.',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: theme.hintColor,
                            ),
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
        // "Coming Soon" overlay badge
        Positioned.fill(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_off_rounded, size: 28, color: theme.hintColor),
                  const SizedBox(height: 8),
                  Text(
                    'Recording — Coming Soon',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'API integration pending',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostSessionInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Session Complete',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isProcessing)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Processing audio... Transcribing and generating summary.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            if (!_recordingWasUsed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: theme.hintColor),
                    const SizedBox(width: 8),
                    Text(
                      'No audio dialogue was recorded for this session.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: theme.hintColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            if (_session.aiSummary.isNotEmpty) ...[
              Text(
                'AI Summary',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _session.aiSummary,
                style: GoogleFonts.outfit(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 12),
            ],
            if (_session.clinicalReport.isNotEmpty) ...[
              Text(
                'Clinical Report',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _session.clinicalReport,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_session.transcriptText.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showFullTranscript(theme),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('View Word-for-Word Transcription'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            Text(
              'You can continue adding notes below. Recording is no longer available.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: theme.hintColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviousSessionsPanel(ThemeData theme) {
    if (_previousSessions.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showPreviousSessionsPane(theme),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.history, color: theme.primaryColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous Sessions (${_previousSessions.length})',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Review notes, summaries, and action points',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 16, color: theme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreviousSessionsPane(ThemeData theme) {
    showGlassDialog(
      context,
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Session History',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _previousSessions.length,
          itemBuilder: (ctx, i) {
            final s = _previousSessions[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context); // Close history
                  showGlassDialog(
                    context,
                    SessionDashboard(session: s),
                  ); // Open specific session in viewing mode
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              DateFormat('d MMM yyyy').format(s.date),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (s.generalMood.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s.generalMood,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (s.aiSummary.isNotEmpty) ...[
                        Text(
                          'Clinical Summary',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.aiSummary,
                          style: GoogleFonts.outfit(fontSize: 13, height: 1.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (s.therapistNotes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Notes available',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotesSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Session Notes',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  final updated = _session.copyWith(
                    therapistNotes: _notesCtrl.text,
                  );
                  ref.read(sessionsProvider.notifier).updateSession(updated);
                  setState(() => _session = updated);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Notes saved')));
                },
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Add session notes here...',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Photos',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add photos of client's work, assessments, or session materials.",
            style: GoogleFonts.outfit(fontSize: 12, color: theme.hintColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (Theme.of(context).platform == TargetPlatform.iOS ||
                  Theme.of(context).platform == TargetPlatform.android) ...[
                _photoButton(Icons.camera_alt, 'Take Photo', theme),
                const SizedBox(width: 12),
                _photoButton(Icons.photo_library, 'From Gallery', theme),
              ] else ...[
                _photoButton(Icons.upload_file, 'Add from File', theme),
              ],
              const SizedBox(width: 12),
              _photoButton(
                Icons.qr_code_scanner,
                'Mobile Sync',
                theme,
                isSpecial: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'On mobile/tablet: Use the camera directly. On desktop: Photos can be uploaded from the companion mobile app or file picker.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoButton(
    IconData icon,
    String label,
    ThemeData theme, {
    bool isSpecial = false,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isSpecial) {
            _showMobileSyncQR(theme);
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label — file picker integration pending')),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSpecial
                ? theme.primaryColor.withValues(alpha: 0.05)
                : null,
            border: Border.all(
              color: isSpecial
                  ? theme.primaryColor
                  : theme.dividerColor.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: theme.primaryColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: isSpecial ? theme.primaryColor : theme.hintColor,
                  fontWeight: isSpecial ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMobileSyncQR(ThemeData theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Center(
          child: Text(
            'Mobile Companion Sync',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=tressia://session/sync-123',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Scan this with your phone or tablet to instantly sync this session.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Frictionless photo capture and audio streaming enabled upon sync.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFullTranscript(ThemeData theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.description_outlined, color: theme.primaryColor),
            const SizedBox(width: 12),
            Text(
              'Full Transcription',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              _session.transcriptText,
              style: GoogleFonts.outfit(fontSize: 13, height: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
