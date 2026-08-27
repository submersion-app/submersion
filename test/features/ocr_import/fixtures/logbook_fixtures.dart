import 'dart:ui';

import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';

/// Fixture geometry mimics the five real sample pages from the spec
/// (docs/superpowers/specs/2026-07-06-ocr-logbook-import-design.md,
/// "Reference: sample pages").
OcrTextBlock block(
  String text,
  double l,
  double t, {
  double w = 80,
  double h = 12,
}) => OcrTextBlock(text: text, boundingBox: Rect.fromLTWH(l, t, w, h));

OcrResult _page(List<OcrTextBlock> blocks) =>
    OcrResult(blocks: blocks, imageSize: const Size(1180, 1450));

/// Sample 1: PADI blue page, handwritten, imperial (Hawaii 2006).
/// Values sit ABOVE the printed labels in the Z-diagram; pressures use
/// "3K" shorthand; units are implied by the "60 ft" visibility.
OcrResult padiHandwrittenImperial() => _page([
  block('Dive No.', 60, 20, w: 90, h: 16),
  block('66', 170, 14, w: 50, h: 20),
  block('Date', 320, 20, w: 60, h: 16),
  block("6 Feb '06", 390, 10, w: 140, h: 22),
  block('Location', 60, 80, w: 100, h: 16),
  block("O'ahu - pipe", 180, 72, w: 220, h: 24),
  block('Time IN', 80, 140, w: 70, h: 14),
  block('10:00A', 70, 170, w: 90, h: 22),
  block('Time OUT', 220, 140, w: 80, h: 14),
  block('10:32', 220, 170, w: 80, h: 22),
  block('bar/psi START', 420, 140, w: 80, h: 28),
  block('3K', 430, 180, w: 50, h: 26),
  block('bar/psi END', 420, 250, w: 80, h: 28),
  block('1600', 425, 290, w: 70, h: 26),
  block('Weight', 240, 260, w: 70, h: 14),
  block('6', 250, 290, w: 20, h: 22),
  block('69', 595, 200, w: 45, h: 30),
  block('DEPTH', 600, 240, w: 70, h: 14),
  block('32', 730, 255, w: 50, h: 28),
  block('BOTTOM TIME', 720, 290, w: 110, h: 14),
  block('73', 340, 580, w: 40, h: 18),
  block('Bottom', 390, 592, w: 60, h: 12),
  block('Visibility', 60, 650, w: 90, h: 16),
  block('60 ft', 170, 645, w: 70, h: 22),
  block('Comments', 60, 800, w: 110, h: 20),
  block('HOLY', 60, 850, w: 120, h: 40),
  block('WE SAW', 300, 850, w: 200, h: 40),
  block('A HUMPBACK WHALE', 60, 910, w: 400, h: 40),
  block(
    'First we saw the whales at a distance from the boat.',
    60,
    970,
    w: 700,
    h: 30,
  ),
  // Template chrome / noise:
  block('SI', 600, 60, w: 20, h: 10),
  block(':39', 640, 55, w: 40, h: 20),
  block('5m/15ft stop', 900, 180, w: 90, h: 10),
  block('RNT', 880, 230, w: 40, h: 14),
  block('ABT', 880, 260, w: 40, h: 14),
  block('TBT', 880, 290, w: 40, h: 14),
  block('MULTI-LEVEL DIVE', 640, 400, w: 160, h: 14),
  block('For use with The Wheel only.', 640, 430, w: 200, h: 12),
  block('Certification No.', 60, 1300, w: 140, h: 14),
]);

/// Sample 2: PADI Open Water training page, printed template, metric.
OcrResult padiTrainingMetric() => _page([
  block('Dive No.', 60, 60, w: 70, h: 14),
  block('Date', 300, 60, w: 50, h: 14),
  block('05/14/2023', 360, 55, w: 120, h: 18),
  block('Visibility', 480, 100, w: 80, h: 14),
  block('20', 570, 95, w: 30, h: 18),
  block('Location', 60, 120, w: 90, h: 16),
  block('Pinnacle, Sodwana Bay', 160, 115, w: 260, h: 20),
  block('24', 500, 136, w: 30, h: 16),
  block('Air', 560, 140, w: 40, h: 12),
  block('25', 500, 196, w: 30, h: 16),
  block('Bottom', 560, 200, w: 60, h: 12),
  block('Weight', 700, 120, w: 60, h: 14),
  block('11', 700, 150, w: 30, h: 20),
  block('11.1m', 110, 440, w: 70, h: 20),
  block('DEPTH', 120, 470, w: 60, h: 12),
  block('45min', 250, 470, w: 80, h: 20),
  block('TIME', 260, 500, w: 50, h: 12),
  block('Start psi/bar', 430, 560, w: 100, h: 14),
  block('200 bar', 540, 555, w: 80, h: 18),
  block('End psi/bar', 430, 590, w: 100, h: 14),
  block('70 bar', 540, 585, w: 70, h: 18),
  block('Comments', 40, 820, w: 100, h: 16),
  block('First dive in the ocean!', 150, 818, w: 300, h: 22),
  // Template chrome / noise:
  block('Skills Completed', 60, 700, w: 140, h: 14),
  block('Predive safety check', 60, 720, w: 160, h: 12),
  block('Verification Signature', 60, 1250, w: 180, h: 14),
  block('616757', 620, 1295, w: 90, h: 20),
  block('Certification No', 500, 1300, w: 120, h: 14),
]);

/// Sample 3 layout: generic third-party template (values invented).
OcrResult genericThirdParty() => _page([
  block('Dive #', 60, 40, w: 60, h: 14),
  block('102', 130, 36, w: 40, h: 18),
  block('Date', 300, 40, w: 50, h: 14),
  block('03/07/2024', 360, 36, w: 110, h: 18),
  block('Location', 60, 90, w: 90, h: 14),
  block('Blue Corner', 160, 86, w: 160, h: 18),
  block('Max', 80, 300, w: 50, h: 12),
  block('28m', 140, 298, w: 40, h: 16),
  block('Start', 600, 380, w: 50, h: 12),
  block('210 bar', 600, 400, w: 70, h: 16),
  block('End', 600, 430, w: 40, h: 12),
  block('60 bar', 600, 450, w: 60, h: 16),
  block('Nitrox', 600, 520, w: 60, h: 12),
  block('32 %', 670, 518, w: 40, h: 16),
]);

/// Sample 4 layout: typewriter-style boxed template (values invented).
OcrResult typewriterBoxed() => _page([
  block('Location/Site Name:', 60, 180, w: 220, h: 16),
  block('Chac Mool Cenote', 400, 178, w: 200, h: 18),
  block('Country/Region:', 60, 220, w: 220, h: 16),
  block('Mexico', 400, 218, w: 80, h: 18),
  block('Time In', 300, 320, w: 70, h: 12),
  block('9:40', 300, 340, w: 50, h: 16),
  block('Time Out', 600, 320, w: 80, h: 12),
  block('10:31', 600, 340, w: 50, h: 16),
  block('Water Temp Bottom :', 60, 360, w: 180, h: 14),
  block('25', 400, 358, w: 30, h: 16),
  block('Max Depth', 400, 380, w: 90, h: 12),
  block('12', 410, 400, w: 30, h: 16),
  block('Bottom Time :', 500, 470, w: 110, h: 14),
  block('51 min', 620, 468, w: 60, h: 16),
]);

/// Adversarial: ONLY template-chrome fields that must never leak.
OcrResult certificationTrap() => _page([
  block('Certification No.', 60, 100, w: 140, h: 14),
  block('616757', 210, 96, w: 90, h: 18),
  block('Bottom Time To Date', 60, 200, w: 170, h: 14),
  block('48:30', 240, 196, w: 60, h: 18),
  block('Cumulative Time', 60, 240, w: 140, h: 14),
  block('52:10', 210, 236, w: 60, h: 18),
]);
