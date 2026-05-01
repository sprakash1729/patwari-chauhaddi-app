import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PdfResult {
  final File file;
  final String downloadUrl;

  PdfResult({required this.file, required this.downloadUrl});
}

class PdfGenerator {
  static TextSpan _filled(String? text, double fontSize, {bool isBold = false}) {
    return TextSpan(
      text: ' ${text ?? ''} ', // Add padding so the underline extends slightly past the word
      style: TextStyle(
        color: Colors.black,
        fontSize: fontSize * 3.0, // Match the scale used in the painter
        fontFamily: 'NotoSansDevanagari',
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        height: 1.5,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted, // Gives the fill-in-the-blank look
      ),
    );
  }

  static TextSpan _static(String text, double fontSize, {bool isBold = false}) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        fontSize: fontSize * 3.0,
        fontFamily: 'NotoSansDevanagari',
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        height: 1.5,
      ),
    );
  }

  static Future<PdfBitmap> _drawHindiText(
    InlineSpan textSpan,
    double width,
    TextAlign alignment,
  ) async {
    // Increase resolution (scale) for crisp text rendering in the PDF
    final double scale = 3.0;

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
      textAlign: alignment,
    );

    textPainter.layout(minWidth: width * scale, maxWidth: width * scale);

    final pWidth = textPainter.width > 0 ? textPainter.width : 1.0;
    final pHeight = textPainter.height > 0 ? textPainter.height : 1.0;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final image = await picture.toImage(pWidth.ceil(), pHeight.ceil());

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return PdfBitmap(bytes);
  }

  static Future<PdfResult> generateAndUploadChaturseema({
    required Map<String, dynamic> data,
  }) async {
    // 1. Create a new PDF document
    final PdfDocument document = PdfDocument();
    document.pageSettings.margins.all = 40;
    final PdfPage page = document.pages.add();
    final Size pageSize = page.getClientSize();

    DateTime date;
    try {
      date = (data['createdAt'] as dynamic).toDate();
    } catch (_) {
      date = DateTime.now();
    }
    final String dateStr = DateFormat('dd/MM/yyyy').format(date);

    final String sanitizedKhasra = data['khasraNumber'].toString().replaceAll('/', '_');
    final String fileName = 'chaturseema_$sanitizedKhasra.pdf';

    // Construct expected public URL for QR Code
    final String bucket = FirebaseStorage.instance.bucket;
    final String path = Uri.encodeComponent('patwari-data/$fileName');
    final String publicUrl = 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$path?alt=media';

    double currentY = 0;

    // Header: QR Code
    final QrPainter qrPainter = QrPainter(
      data: publicUrl,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      color: const ui.Color(0xFF000000),
      emptyColor: const ui.Color(0xFFFFFFFF),
    );
    final ui.Image qrUiImage = await qrPainter.toImage(240);
    final ByteData? qrByteData = await qrUiImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List qrBytes = qrByteData!.buffer.asUint8List();
    final PdfBitmap qrPdfImage = PdfBitmap(qrBytes);

    page.graphics.drawImage(qrPdfImage, Rect.fromLTWH(0, currentY, 80, 80));

    // Title: Chaturseema
    final titleBmp = await _drawHindiText(TextSpan(children: [_static('चतुर्सीमा', 24, isBold: true)]), pageSize.width, TextAlign.center);
    final titleY = currentY + (80 - (titleBmp.height / 3.0)) / 2;
    page.graphics.drawImage(titleBmp, Rect.fromLTWH(0, titleY, pageSize.width, titleBmp.height / 3.0));

    currentY += 85;

    // S.No. and Date
    final snoBmp = await _drawHindiText(TextSpan(children: [_static('क्र.........', 13)]), 200, TextAlign.left);
    page.graphics.drawImage(snoBmp, Rect.fromLTWH(0, currentY, 200, snoBmp.height / 3.0));

    final dateBmp = await _drawHindiText(TextSpan(children: [_static('दिनांक- ', 13), _filled(dateStr, 13)]), 200, TextAlign.right);
    page.graphics.drawImage(dateBmp, Rect.fromLTWH(pageSize.width - 200, currentY, 200, dateBmp.height / 3.0));
    currentY += (snoBmp.height / 3.0) + 10;

    // Location Line
    final locBmp = await _drawHindiText(TextSpan(children: [
      _static('ग्राम ', 14, isBold: true), _filled(data['village'], 14, isBold: true),
      _static(' प.ह.न. ', 14, isBold: true), _filled(data['halkaNumber']?.toString(), 14, isBold: true),
      _static(' रा.नि.मं.- ', 14, isBold: true), _filled(data['riCircle'], 14, isBold: true),
      _static(' तहसील व जिला कोरबा (छ.ग.)', 14, isBold: true),
    ]), pageSize.width, TextAlign.center);
    page.graphics.drawImage(locBmp, Rect.fromLTWH(0, currentY, pageSize.width, locBmp.height / 3.0));
    currentY += (locBmp.height / 3.0) + 10;
    
    page.graphics.drawLine(PdfPens.black, Offset(0, currentY), Offset(pageSize.width, currentY));
    currentY += 15;

    // Main Paragraph
    final String residentOf = data['residentOf'] ?? data['village'];
    final String areaUnitHindi = data['areaUnit'] == 'Acre' ? 'एकड़' : 'हेक्टेयर';
    
    final mainParBmp = await _drawHindiText(TextSpan(children: [
      _static('खातेदार श्री/श्रीमती ', 13), _filled(data['applicantName'], 13, isBold: true),
      _static(' पिता/पति ', 13), _filled(data['relationName'], 13, isBold: true),
      _static(' जाति ', 13), _filled(data['caste'], 13, isBold: true),
      _static(' निवासी ', 13), _filled(residentOf, 13, isBold: true),
      _static(' के ग्राम ', 13), _filled(data['village'], 13, isBold: true),
      _static(' प.ह.न. ', 13), _filled(data['halkaNumber']?.toString(), 13, isBold: true),
      _static(' रा.नि.मं. ', 13), _filled(data['riCircle'], 13, isBold: true),
      _static(' तहसील कोरबा जिला कोरबा (छ.ग.) स्थित भूमि खसरा नंबर ', 13), _filled(data['khasraNumber']?.toString(), 13, isBold: true),
      _static(' रकबा ', 13), _filled('${data['area']} $areaUnitHindi', 13, isBold: true),
      _static(' भूमि में से पूर्ण/आंशिक रकबा ', 13), _filled('${data['area']} $areaUnitHindi', 13, isBold: true),
      _static(' भूमि की चतुर्सीमा चाही गयी है जिसका जानकारी निम्नानुसार है।', 13),
    ]), pageSize.width, TextAlign.justify);
    page.graphics.drawImage(mainParBmp, Rect.fromLTWH(0, currentY, pageSize.width, mainParBmp.height / 3.0));
    currentY += (mainParBmp.height / 3.0) + 15;

    // Compass Drawing Logic (Repositioned & Resized)
    double compassCenterY = currentY + 30; // Aligned with the start of boundary map
    double compassX = 40.0;
    
    page.graphics.drawEllipse(Rect.fromLTWH(compassX - 12, compassCenterY - 12, 24, 24), pen: PdfPens.black);
    page.graphics.drawLine(PdfPens.black, Offset(compassX, compassCenterY - 16), Offset(compassX, compassCenterY + 16));
    page.graphics.drawLine(PdfPens.black, Offset(compassX - 16, compassCenterY), Offset(compassX + 16, compassCenterY));
    
    final nBmp = await _drawHindiText(TextSpan(children: [_static('N', 10, isBold: true)]), 20, TextAlign.center);
    final sBmp = await _drawHindiText(TextSpan(children: [_static('S', 10, isBold: true)]), 20, TextAlign.center);
    final wBmp = await _drawHindiText(TextSpan(children: [_static('W', 10, isBold: true)]), 20, TextAlign.center);
    final eBmp = await _drawHindiText(TextSpan(children: [_static('E', 10, isBold: true)]), 20, TextAlign.center);

    page.graphics.drawImage(nBmp, Rect.fromLTWH(compassX - 10, compassCenterY - 30, 20, nBmp.height / 3.0));
    page.graphics.drawImage(sBmp, Rect.fromLTWH(compassX - 10, compassCenterY + 14, 20, sBmp.height / 3.0));
    page.graphics.drawImage(wBmp, Rect.fromLTWH(compassX - 30, compassCenterY - (wBmp.height / 3.0)/2, 20, wBmp.height / 3.0));
    page.graphics.drawImage(eBmp, Rect.fromLTWH(compassX + 10, compassCenterY - (eBmp.height / 3.0)/2, 20, eBmp.height / 3.0));

    // Boundary Map Layout (Centered)
    double centerX = pageSize.width / 2;
    double boxWidth = 140;
    double boxHeight = 70;
    double colWidth = 120; // Fixed col width for text

    final northBmp = await _drawHindiText(TextSpan(children: [
      _static('उत्तर में\n', 12, isBold: true), _filled(data['boundaryNorth'], 12, isBold: true),
    ]), colWidth, TextAlign.center);
    final southBmp = await _drawHindiText(TextSpan(children: [
      _static('दक्षिण में\n', 12, isBold: true), _filled(data['boundarySouth'], 12, isBold: true),
    ]), colWidth, TextAlign.center);
    final eastBmp = await _drawHindiText(TextSpan(children: [
      _static('पूर्व में\n', 12, isBold: true), _filled(data['boundaryEast'], 12, isBold: true),
    ]), colWidth, TextAlign.center);
    final westBmp = await _drawHindiText(TextSpan(children: [
      _static('पश्चिम में\n', 12, isBold: true), _filled(data['boundaryWest'], 12, isBold: true),
    ]), colWidth, TextAlign.center);
    
    final centerBmp = await _drawHindiText(TextSpan(children: [
      _static('खसरा नं.- ', 12, isBold: true), _filled(data['khasraNumber']?.toString(), 12, isBold: true),
      _static('\nरकबा- ', 12, isBold: true), _filled('${data['area']} $areaUnitHindi', 12, isBold: true),
    ]), boxWidth - 10, TextAlign.center);

    // Draw North (Perfectly centered above box)
    page.graphics.drawImage(northBmp, Rect.fromLTWH(centerX - (colWidth / 2), currentY, colWidth, northBmp.height / 3.0));
    currentY += (northBmp.height / 3.0) + 10;

    // Draw Box
    final rowY = currentY;
    final centerBoxRect = Rect.fromLTWH(centerX - (boxWidth / 2), rowY, boxWidth, boxHeight);
    page.graphics.drawRectangle(bounds: centerBoxRect, pen: PdfPens.black);
    final centerY = rowY + (boxHeight - (centerBmp.height / 3.0)) / 2;
    page.graphics.drawImage(centerBmp, Rect.fromLTWH(centerX - (boxWidth / 2) + 5, centerY, boxWidth - 10, centerBmp.height / 3.0));

    // Draw West & East
    final westY = rowY + (boxHeight - (westBmp.height / 3.0)) / 2;
    page.graphics.drawImage(westBmp, Rect.fromLTWH(centerX - (boxWidth / 2) - 80 - colWidth + 80, westY, colWidth, westBmp.height / 3.0));

    final eastY = rowY + (boxHeight - (eastBmp.height / 3.0)) / 2;
    page.graphics.drawImage(eastBmp, Rect.fromLTWH(centerX + (boxWidth / 2) + 20, eastY, colWidth, eastBmp.height / 3.0));

    currentY += boxHeight + 10;

    // Draw South
    page.graphics.drawImage(southBmp, Rect.fromLTWH(centerX - (colWidth / 2), currentY, colWidth, southBmp.height / 3.0));
    currentY += (southBmp.height / 3.0) + 15;

    // Footer Paragraph
    final footerBmp = await _drawHindiText(TextSpan(children: [
      _static('उपरोक्त भूमि का चतुर्सीमा आवेदक/खातेदार ', 13), _filled(data['applicantName'], 13, isBold: true),
      _static(' पिता / पति ', 13), _filled(data['relationName'], 13, isBold: true),
      _static(' जाति ', 13), _filled(data['caste'], 13, isBold: true),
      _static(' निवासी ', 13), _filled(residentOf, 13, isBold: true),
      _static(' एवं निम्न हस्ताक्षरित गवाह के बताये अनुसार तैयार किया गया है।', 13),
    ]), pageSize.width, TextAlign.justify);
    page.graphics.drawImage(footerBmp, Rect.fromLTWH(0, currentY, pageSize.width, footerBmp.height / 3.0));
    currentY += (footerBmp.height / 3.0) + 15;

    // Tip Section
    final tipHeaderBmp = await _drawHindiText(TextSpan(children: [_static('टीप :-', 13, isBold: true)]), pageSize.width, TextAlign.left);
    page.graphics.drawImage(tipHeaderBmp, Rect.fromLTWH(0, currentY, pageSize.width, tipHeaderBmp.height / 3.0));
    currentY += (tipHeaderBmp.height / 3.0) + 5;

    final String tip1 = '1. आवेदक एवं गवाह के बताए अनुसार उक्त भूमि पूर्व में किसी के पास बिक्री / गिरवी या अधिया में नहीं दिया गया है तथा किसी भी प्रकार का कोई विवाद या न्यायालनीय प्रकरण लंबित नहीं है। उक्त भूमि शासकीय भूमि नहीं है एवं किसी भी संस्था द्वारा अर्जित नहीं है।';
    final String tip2 = '2. किसी भी प्रकार के विवाद की स्थिति में उक्त चतुर्सीमा परिवर्तनशील होगा एवं समस्त जवाबदारी खातेदार/भूमिस्वामी की होगी।';
    
    final tipIndent = 20.0;
    final tipWidth = pageSize.width - tipIndent;
    
    final tip1Bmp = await _drawHindiText(TextSpan(children: [_static(tip1, 12)]), tipWidth, TextAlign.justify);
    page.graphics.drawImage(tip1Bmp, Rect.fromLTWH(tipIndent, currentY, tipWidth, tip1Bmp.height / 3.0));
    currentY += (tip1Bmp.height / 3.0) + 5;
    
    final tip2Bmp = await _drawHindiText(TextSpan(children: [_static(tip2, 12)]), tipWidth, TextAlign.justify);
    page.graphics.drawImage(tip2Bmp, Rect.fromLTWH(tipIndent, currentY, tipWidth, tip2Bmp.height / 3.0));
    currentY += (tip2Bmp.height / 3.0) + 15;

    // Signatures
    final signColWidth = pageSize.width / 3;
    final signatureStartY = currentY;

    // Col 1: Applicant & Witnesses
    final appSign1 = await _drawHindiText(TextSpan(children: [_static('आवेदक के नाम', 12, isBold: true)]), signColWidth, TextAlign.center);
    final appSign2 = await _drawHindiText(TextSpan(children: [_filled(data['applicantName'], 12)]), signColWidth, TextAlign.center);
    page.graphics.drawImage(appSign1, Rect.fromLTWH(0, signatureStartY, signColWidth, appSign1.height / 3.0));
    page.graphics.drawImage(appSign2, Rect.fromLTWH(0, signatureStartY + 25, signColWidth, appSign2.height / 3.0));
    
    final witSignHeader = await _drawHindiText(TextSpan(children: [_static('गवाह का नाम व हस्ताक्षर', 12, isBold: true)]), signColWidth, TextAlign.center);
    page.graphics.drawImage(witSignHeader, Rect.fromLTWH(0, signatureStartY + 60, signColWidth, witSignHeader.height / 3.0));
    
    final wit1 = await _drawHindiText(TextSpan(children: [_static('1. ................', 12)]), signColWidth, TextAlign.left);
    final wit2 = await _drawHindiText(TextSpan(children: [_static('2. ................', 12)]), signColWidth, TextAlign.left);
    page.graphics.drawImage(wit1, Rect.fromLTWH(10, signatureStartY + 85, signColWidth - 10, wit1.height / 3.0));
    page.graphics.drawImage(wit2, Rect.fromLTWH(10, signatureStartY + 110, signColWidth - 10, wit2.height / 3.0));

    // Col 2: Father/Husband
    final relHeader = await _drawHindiText(TextSpan(children: [_static('पिता/पति का नाम', 12, isBold: true)]), signColWidth, TextAlign.center);
    final relName = await _drawHindiText(TextSpan(children: [_filled(data['relationName'], 12)]), signColWidth, TextAlign.center);
    page.graphics.drawImage(relHeader, Rect.fromLTWH(signColWidth, signatureStartY, signColWidth, relHeader.height / 3.0));
    page.graphics.drawImage(relName, Rect.fromLTWH(signColWidth, signatureStartY + 25, signColWidth, relName.height / 3.0));

    // Col 3: Patwari Signature
    final patSign1 = await _drawHindiText(TextSpan(children: [_static('हस्ताक्षर', 12, isBold: true)]), signColWidth, TextAlign.center);
    page.graphics.drawImage(patSign1, Rect.fromLTWH(signColWidth * 2, signatureStartY, signColWidth, patSign1.height / 3.0));
    
    final patSign2 = await _drawHindiText(TextSpan(children: [_static('हस्ताक्षर', 12, isBold: true)]), signColWidth, TextAlign.center);
    page.graphics.drawImage(patSign2, Rect.fromLTWH(signColWidth * 2, signatureStartY + 60, signColWidth, patSign2.height / 3.0));
    
    final String patwariName = data['patwariName'] ?? '';
    double patY = signatureStartY + 85;
    if (patwariName.isNotEmpty) {
      final patNameBmp = await _drawHindiText(TextSpan(children: [_filled(patwariName, 12, isBold: true)]), signColWidth, TextAlign.center);
      page.graphics.drawImage(patNameBmp, Rect.fromLTWH(signColWidth * 2, patY, signColWidth, patNameBmp.height / 3.0));
      patY += (patNameBmp.height / 3.0) + 5;
    }
    
    final patTitleBmp = await _drawHindiText(TextSpan(children: [_static('पटवारी / राजस्व निरीक्षक', 12, isBold: true)]), signColWidth, TextAlign.center);
    page.graphics.drawImage(patTitleBmp, Rect.fromLTWH(signColWidth * 2, patY, signColWidth, patTitleBmp.height / 3.0));

    // Save and upload
    final List<int> bytes = await document.save();
    document.dispose();

    final Directory output = await getTemporaryDirectory();
    final File file = File('${output.path}/$fileName');
    await file.writeAsBytes(bytes);

    final Reference storageRef = FirebaseStorage.instance.ref().child('patwari-data').child(fileName);
    final UploadTask uploadTask = storageRef.putFile(file);
    final TaskSnapshot taskSnapshot = await uploadTask;
    final String actualDownloadUrl = await taskSnapshot.ref.getDownloadURL();

    return PdfResult(file: file, downloadUrl: actualDownloadUrl);
  }

  static Future<void> sharePdf(File file, String khasra) async {
    await Share.shareXFiles([XFile(file.path)], text: 'Chaturseema for Khasra $khasra');
  }
}
