import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_card_photo.dart';

/// The front face of the certification card.
///
/// Shows the uploaded front photo when the diver captured one, otherwise a
/// generated card in the issuing agency's colours.
class CertificationEcardFront extends StatelessWidget {
  /// The certification to display.
  final Certification certification;

  /// The name of the diver holding this certification.
  final String diverName;

  const CertificationEcardFront({
    super.key,
    required this.certification,
    required this.diverName,
  });

  @override
  Widget build(BuildContext context) {
    final photo = certification.photoFront;
    if (photo != null) {
      return CertificationCardPhoto(
        bytes: photo,
        badge: _buildStatusBadge(context),
        infoLines: _buildInfoLines(),
      );
    }
    return _buildGeneratedFront(context);
  }

  /// Lines repeated over a photographed card.
  ///
  /// The scrim covers the part of a physical card that prints the holder's name
  /// and number, so repeating them here loses nothing and keeps the text legible
  /// when the photo is dim or blurry.
  List<String> _buildInfoLines() {
    final cardNumber = certification.cardNumber;

    // certificationTitle, not the raw name: a stored name that merely repeats
    // agency and level would otherwise render as "PADI - PADI : Open Water".
    final headline = [
      certification.agency.displayName,
      certificationTitle(certification),
    ].where((value) => value.isNotEmpty).join('  -  ');

    final detail = [
      diverName.toUpperCase(),
      if (cardNumber != null && cardNumber.isNotEmpty) cardNumber,
    ].where((value) => value.isNotEmpty).join('  -  ');

    return [if (headline.isNotEmpty) headline, if (detail.isNotEmpty) detail];
  }

  Widget _buildGeneratedFront(BuildContext context) {
    final agency = certification.agency;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          CertificationCardPhoto.borderRadius,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [agency.primaryColor, agency.secondaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: agency.primaryColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative wave pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _WavePatternPainter(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeader(context),
                // Flexible so the hero is what gives way when a long name, a
                // level and a full field grid all compete for a CR80 card on a
                // narrow phone. The header and grid are the facts a dive
                // operator reads, so they keep their intrinsic height.
                Flexible(child: _buildHero()),
                _buildFieldGrid(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            certification.agency.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        _buildStatusBadge(context) ?? const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildHero() {
    final subtitle = certificationSubtitle(certification);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            certificationTitle(certification),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Only when the title above is a custom name -- otherwise it already
        // contains the certification.
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// The labelled facts a dive operator checks at check-in.
  ///
  /// Cells with no value are dropped rather than rendered blank, and the
  /// remaining cells reflow two per row, so a bare certification produces a
  /// tighter card instead of a grid of holes.
  Widget _buildFieldGrid(BuildContext context) {
    final cells = _buildFieldCells(context);
    if (cells.isEmpty) return const SizedBox.shrink();

    final rows = <List<_CardField>>[];
    for (var i = 0; i < cells.length; i += 2) {
      rows.add(cells.sublist(i, (i + 2).clamp(0, cells.length)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 10),
          color: Colors.white.withValues(alpha: 0.25),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final cell in rows[i])
                Expanded(child: _buildFieldCell(cell)),
              // Keep a lone cell in the left column instead of stretching it.
              if (rows[i].length == 1) const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ],
    );
  }

  List<_CardField> _buildFieldCells(BuildContext context) {
    final l10n = context.l10n;
    final dateFormat = DateFormat.yMMM();
    final cardNumber = certification.cardNumber;

    return [
      if (diverName.trim().isNotEmpty)
        _CardField(
          label: l10n.certifications_ecard_label_diver,
          value: diverName.toUpperCase(),
        ),
      if (cardNumber != null && cardNumber.isNotEmpty)
        _CardField(
          label: l10n.certifications_ecard_label_cardNumber,
          value: cardNumber,
        ),
      if (certification.issueDate != null)
        _CardField(
          label: l10n.certifications_ecard_label_issued,
          value: dateFormat.format(certification.issueDate!),
        ),
      if (certification.expiryDate != null)
        _CardField(
          label: l10n.certifications_ecard_label_validUntil,
          value: dateFormat.format(certification.expiryDate!),
          valueColor: _expiryColor(),
        ),
    ];
  }

  /// Tints the expiry value to match the status badge.
  ///
  /// These are the badge's literal colours rather than [ColorScheme] roles,
  /// because the card sits on an agency gradient, not on a theme surface. The
  /// lighter shades keep the text legible against a dark gradient.
  Color _expiryColor() {
    if (certification.isExpired) return Colors.red.shade200;
    if (certification.expiresWithin(90)) return Colors.orange.shade200;
    return Colors.white;
  }

  Widget _buildFieldCell(_CardField field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          field.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          field.value,
          style: TextStyle(
            color: field.valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// The expiry status chip, or null when the certification is current.
  ///
  /// Returns null rather than an empty box so the photo branch can decide
  /// whether to position anything at all.
  Widget? _buildStatusBadge(BuildContext context) {
    if (certification.isExpired) {
      return _badge(
        context.l10n.certifications_ecard_statusBadge_expired,
        Colors.red,
      );
    }

    if (certification.expiresWithin(90)) {
      return _badge(
        context.l10n.certifications_ecard_statusBadge_expiring,
        Colors.orange,
      );
    }

    return null;
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// One labelled fact on the generated card front.
class _CardField {
  final String label;
  final String value;
  final Color valueColor;

  const _CardField({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });
}

/// Custom painter for decorative wave pattern on the card.
class _WavePatternPainter extends CustomPainter {
  final Color color;

  _WavePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw decorative circles at various positions
    final circles = [
      (Offset(size.width * 0.85, size.height * 0.2), size.width * 0.25),
      (Offset(size.width * 0.95, size.height * 0.6), size.width * 0.18),
      (Offset(size.width * 0.1, size.height * 0.9), size.width * 0.15),
      (Offset(size.width * 0.75, size.height * 0.85), size.width * 0.12),
    ];

    for (final (offset, radius) in circles) {
      canvas.drawCircle(offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
