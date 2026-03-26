import 'dart:typed_data';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart'
    show BuildContext, ScaffoldMessenger, SnackBar, Text, debugPrint;
import '../models/clinic_settings.dart';
import '../models/project_module.dart';

class DocumentGenerator {
  static Future<void> generateAndPrintDocument({
    required BuildContext context,
    required String title,
    required String generatedContent,
    required ClinicSettings settings,
    required Project clientProject,
  }) async {
    final pdf = pw.Document();
    pw.MemoryImage? logoImage;

    if (settings.base64Logo != null && settings.base64Logo!.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(settings.base64Logo!);
        logoImage = pw.MemoryImage(bytes);
      } catch (e) {
        print("Failed to decode logo bytes: \$e");
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Letterhead
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 100,
                    height: 100,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  )
                else
                  pw.Text(
                    settings.clinicName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (logoImage != null)
                      pw.Text(
                        settings.clinicName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    if (settings.address.isNotEmpty) pw.Text(settings.address),
                    if (settings.phone.isNotEmpty)
                      pw.Text("Ph: ${settings.phone}"),
                    if (settings.email.isNotEmpty) pw.Text(settings.email),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),

            // Client Meta
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Client Ref: ${clientProject.clientId}"),
                pw.Text("Type: ${clientProject.clientType}"),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Therapist ID: ${clientProject.assignedTherapistIds.firstOrNull ?? 'unassigned'}"),
                pw.Text("Date: ${DateTime.now().toString().split(" ")[0]}"),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 16),

            // Content
            pw.Text(
              generatedContent,
              style: const pw.TextStyle(lineSpacing: 1.5),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${title}_${clientProject.clientId}.pdf',
    );
  }

  /// Generates a blank letterhead with clinic branding
  static Future<void> generateBlankLetterhead({
    required BuildContext context,
    required ClinicSettings settings,
  }) async {
    final pdf = pw.Document();
    pw.MemoryImage? logoImage;

    if (settings.base64Logo != null && settings.base64Logo!.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(settings.base64Logo!);
        logoImage = pw.MemoryImage(bytes);
      } catch (e) {
        debugPrint("Failed to decode logo bytes: \$e");
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              // Letterhead Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 100,
                      height: 100,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Text(
                      settings.clinicName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (logoImage != null)
                        pw.Text(
                          settings.clinicName,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if (settings.address.isNotEmpty)
                        pw.Text(settings.address),
                      if (settings.phone.isNotEmpty)
                        pw.Text("Ph: ${settings.phone}"),
                      if (settings.email.isNotEmpty) pw.Text(settings.email),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.Spacer(),
              // Footer
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  "${settings.clinicName} • ${settings.address} • ${settings.phone}",
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Blank_Letterhead_\${settings.clinicName}.pdf',
    );
  }

  /// Synthesizes Rambles into a format
  static Future<String> generateSmartReport(
    List<String> rawRambles,
    String reportType,
  ) async {
    final combined = rawRambles.join("\n\n---\n\n");
    // Since we are generating documents natively, we could use the existing Gemini API key.
    // For an MVP, we can reuse the generative model directly if we expose it, or just use a specialized prompt here.
    // For now we will return placeholder text simulating the result to maintain compilation until we add a direct `String -> String` pipeline to the Gateway.

    // Simulating delay for AI processing
    await Future.delayed(const Duration(seconds: 2));

    if (reportType == 'SOAP') {
      return "S: Client reports feeling fewer anxiety spikes this week.\n\nO: Client appeared calm, engaged well in CBT exercises.\n\nA: Progressing steadily according to treatment plan.\n\nP: Continue exposure therapy next session. Recommended daily journaling.";
    } else if (reportType == 'NDIS') {
      return "NDIS Progress Report Summary\n\n1. Goals Addressed\n- Emotional regulation (Goal 1)\n- Social participation (Goal 2)\n\n2. Outcomes\nClient has demonstrated a 30% reduction in negative outbursts...\n\n3. Recommendations\nContinue current cadence. Recommend funding rollover for next cycle.";
    } else {
      return "General Summary:\n\$combined";
    }
  }
}
