import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Printable EduTrack documents (COR, transcript, class schedule, profile):
/// the web's "Print / Save as PDF". Opens the system print dialog, which
/// can also save the PDF.
class PrintableDoc {
  PrintableDoc({required this.title, required this.subtitle, required this.badge, this.info = const [], this.sections = const [], this.signatures = const []});

  /// File name shown in the print dialog.
  final String title;

  /// Office line under "EDUTRACK UNIVERSITY".
  final String subtitle;

  /// Dark document-type badge, e.g. "Official Certificate of Registration".
  final String badge;

  /// Label/value pairs in the gray box under the header.
  final List<(String, String)> info;
  final List<DocSection> sections;

  /// (name on the line, caption) pairs; an empty name leaves a blank line.
  final List<(String, String)> signatures;

  pw.Document build() {
    final doc = pw.Document(title: title, author: 'EduTrack SIS');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('EDUTRACK UNIVERSITY', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                pw.SizedBox(height: 2),
                pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  color: PdfColors.grey900,
                  child: pw.Text(
                    badge.toUpperCase(),
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          pw.Divider(height: 24),
          if (info.isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  for (final (label, value) in info)
                    pw.SizedBox(
                      width: 240,
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: '$label: ',
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                            ),
                            pw.TextSpan(
                              text: value,
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          for (final section in sections) ...[
            pw.SizedBox(height: 14),
            if (section.heading != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(section.heading!, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ),
            if (section.rows.isNotEmpty || section.headers.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headers: section.headers.isEmpty ? null : section.headers,
                data: [...section.rows, if (section.footer != null) section.footer!],
                headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              ),
            if (section.note != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(section.note!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ),
          ],
          if (signatures.isNotEmpty) ...[
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                for (final (name, caption) in signatures)
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 180,
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.7))),
                        child: pw.Center(
                          child: pw.Text(name.isEmpty ? ' ' : name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(caption, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
              ],
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text('System-generated document · EduTrack SIS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ),
        ],
      ),
    );
    return doc;
  }

  /// Opens the print / save-as-PDF dialog.
  Future<void> print() => Printing.layoutPdf(name: title, onLayout: (_) => build().save());
}

class DocSection {
  const DocSection({this.heading, this.headers = const [], this.rows = const [], this.footer, this.note});
  final String? heading;
  final List<String> headers;
  final List<List<String>> rows;
  final List<String>? footer;
  final String? note;
}
