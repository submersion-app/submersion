// Contact sheet for tuning the dive card photo crop.
//
// For every JPEG or PNG in a folder, draws one row: the whole photo with the
// centred strip (grey) and the chosen strip (orange) outlined, then the card
// as a centred crop, then the card as the app would crop it. Photos with
// people tags are not covered: the tags live in the database, and they
// decide the crop on their own anyway.
//
// Run:
//   dart run tool/card_crop_contact_sheet.dart <folder> [--aspect 4]
//       [--limit 40] [--out <file.jpg>]
//
// --aspect is the card's width / height (the detailed dive card is roughly
// 3.5 to 5 wide). The sheet goes to the system temp folder unless --out
// names a file.
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:submersion/features/dive_log/domain/card_photo/card_crop_alignment.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo_tuning.dart';
import 'package:submersion/features/dive_log/domain/card_photo/row_interest_scores.dart';

const _cardWidth = 480;
const _thumbHeight = 160;
const _gap = 12;
const _labelHeight = 20;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/card_crop_contact_sheet.dart <folder> '
      '[--aspect 4] [--limit 40] [--out <file.jpg>]',
    );
    exitCode = 64;
    return;
  }
  final folder = Directory(args.first);
  final aspect = double.parse(_option(args, '--aspect') ?? '4');
  final limit = int.parse(_option(args, '--limit') ?? '40');
  final out =
      _option(args, '--out') ??
      p.join(Directory.systemTemp.path, 'card_crop_contact_sheet.jpg');

  final files = folder.listSync(recursive: true).whereType<File>().where((f) {
    final ext = p.extension(f.path).toLowerCase();
    return ext == '.jpg' || ext == '.jpeg' || ext == '.png';
  }).toList()..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    stderr.writeln('No JPEG or PNG files in ${folder.path}');
    exitCode = 66;
    return;
  }

  final cardHeight = (_cardWidth / aspect).round();
  final rows = <img.Image>[];
  var moved = 0;
  for (final file in files.take(limit)) {
    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) {
      stderr.writeln('Skipped (cannot decode): ${file.path}');
      continue;
    }
    final photo = img.bakeOrientation(decoded);
    final scores = _rowScores(photo);
    final alignY = cardCropAlignmentY(
      imageAspect: photo.width / photo.height,
      cardAspect: aspect,
      rowScores: scores,
    );
    if (alignY != 0) moved++;
    rows.add(
      _row(
        photo,
        cardHeight: cardHeight,
        alignY: alignY,
        label:
            '${p.basename(file.path)}  '
            'y=${alignY.toStringAsFixed(2)}'
            '${scores == null ? '  (nothing to analyse)' : ''}',
      ),
    );
    stdout.writeln('${p.basename(file.path)}: ${alignY.toStringAsFixed(2)}');
  }

  if (rows.isEmpty) {
    stderr.writeln('No decodable JPEG or PNG files in ${folder.path}');
    exitCode = 65;
    return;
  }

  final width = rows.map((r) => r.width).reduce((a, b) => a > b ? a : b);
  final height = rows.fold<int>(0, (sum, r) => sum + r.height + _gap) + _gap;
  final sheet = img.Image(width: width + 2 * _gap, height: height)
    ..clear(img.ColorRgb8(32, 32, 40));
  var y = _gap;
  for (final r in rows) {
    img.compositeImage(sheet, r, dstX: _gap, dstY: y);
    y += r.height + _gap;
  }
  await File(out).writeAsBytes(img.encodeJpg(sheet, quality: 88));
  stdout.writeln(
    '\n${rows.length} photos, $moved moved off centre. Sheet: $out',
  );
}

String? _option(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

/// The row scores the app works from: the photo fitted inside the analysis
/// size, as the app's small decode is.
List<double>? _rowScores(img.Image photo) {
  const box = CardPhotoTuning.analysisSize;
  final small = photo.width >= photo.height
      ? img.copyResize(
          photo,
          width: box,
          interpolation: img.Interpolation.average,
        )
      : img.copyResize(
          photo,
          height: box,
          interpolation: img.Interpolation.average,
        );
  final rgba = Uint8List.fromList(
    small.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba),
  );
  return rowInterestScores(rgba, small.width, small.height);
}

img.Image _row(
  img.Image photo, {
  required int cardHeight,
  required double alignY,
  required String label,
}) {
  final thumb = img.copyResize(photo, height: _thumbHeight);
  final centred = _card(photo, cardHeight, 0);
  final chosen = _card(photo, cardHeight, alignY);

  // The strips on the thumbnail, in its own pixels.
  final scaledHeight = photo.height * _cardWidth / photo.width;
  final stripShare = (cardHeight / scaledHeight).clamp(0.0, 1.0);
  void outline(double align, img.Color colour) {
    final stripPx = stripShare * thumb.height;
    final top = ((thumb.height - stripPx) * (align + 1) / 2).round();
    img.drawRect(
      thumb,
      x1: 1,
      y1: top,
      x2: thumb.width - 2,
      y2: (top + stripPx).round() - 1,
      color: colour,
      thickness: 2,
    );
  }

  outline(0, img.ColorRgb8(170, 170, 170));
  if (alignY != 0) outline(alignY, img.ColorRgb8(255, 140, 0));

  final width = thumb.width + _gap + _cardWidth + _gap + _cardWidth;
  final height =
      _labelHeight + (thumb.height > cardHeight ? thumb.height : cardHeight);
  final row = img.Image(width: width, height: height)
    ..clear(img.ColorRgb8(32, 32, 40));
  img.drawString(
    row,
    label,
    font: img.arial14,
    x: 0,
    y: 2,
    color: img.ColorRgb8(230, 230, 230),
  );
  img.compositeImage(row, thumb, dstX: 0, dstY: _labelHeight);
  img.compositeImage(
    row,
    centred,
    dstX: thumb.width + _gap,
    dstY: _labelHeight,
  );
  img.compositeImage(
    row,
    chosen,
    dstX: thumb.width + _gap + _cardWidth + _gap,
    dstY: _labelHeight,
  );
  return row;
}

/// [photo] covering a card [_cardWidth] x [cardHeight], placed vertically by
/// [alignY] as Flutter's Alignment would.
img.Image _card(img.Image photo, int cardHeight, double alignY) {
  final scaleW = _cardWidth / photo.width;
  final scaleH = cardHeight / photo.height;
  final scale = scaleW > scaleH ? scaleW : scaleH;
  final scaled = img.copyResize(
    photo,
    width: (photo.width * scale).ceil(),
    height: (photo.height * scale).ceil(),
    interpolation: img.Interpolation.average,
  );
  final x = ((scaled.width - _cardWidth) / 2).round();
  final y = ((scaled.height - cardHeight) * (alignY + 1) / 2).round();
  return img.copyCrop(
    scaled,
    x: x,
    y: y,
    width: _cardWidth,
    height: cardHeight,
  );
}
