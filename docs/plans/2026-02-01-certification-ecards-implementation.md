# Certification eCards Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a digital certification wallet with agency-branded cards, stack navigation, and image export/share capabilities.

**Architecture:** Feature-based structure under `lib/features/certifications/`. Reuses existing `certificationListNotifierProvider` for data. New widgets for card rendering, new service for image export. Dashboard integration via new widget card.

**Tech Stack:** Flutter, Riverpod, share_plus (already installed), RepaintBoundary for image capture

---

## Task 1: Add Agency Brand Colors to Enum

**Files:**
- Modify: `lib/core/constants/enums.dart:110-126`

**Step 1: Add color imports and brand color getters**

At the top of `enums.dart`, ensure `dart:ui` is imported for `Color`:

```dart
import 'dart:ui' show Color;
```

Then modify the `CertificationAgency` enum to add color getters:

```dart
/// Certification agencies
enum CertificationAgency {
  padi('PADI'),
  ssi('SSI'),
  naui('NAUI'),
  sdi('SDI'),
  tdi('TDI'),
  gue('GUE'),
  raid('RAID'),
  bsac('BSAC'),
  cmas('CMAS'),
  iantd('IANTD'),
  psai('PSAI'),
  other('Other');

  final String displayName;
  const CertificationAgency(this.displayName);

  /// Primary brand color for the agency
  Color get primaryColor => switch (this) {
    CertificationAgency.padi => const Color(0xFF004990),
    CertificationAgency.ssi => const Color(0xFF1a237e),
    CertificationAgency.naui => const Color(0xFF1b5e20),
    CertificationAgency.sdi => const Color(0xFF0d47a1),
    CertificationAgency.tdi => const Color(0xFF4a148c),
    CertificationAgency.gue => const Color(0xFF424242),
    CertificationAgency.raid => const Color(0xFFb71c1c),
    CertificationAgency.bsac => const Color(0xFF1565c0),
    CertificationAgency.cmas => const Color(0xFF00695c),
    CertificationAgency.iantd => const Color(0xFF283593),
    CertificationAgency.psai => const Color(0xFF2e7d32),
    CertificationAgency.other => const Color(0xFF00838f),
  };

  /// Secondary/gradient end color for the agency
  Color get secondaryColor => switch (this) {
    CertificationAgency.padi => const Color(0xFF0066CC),
    CertificationAgency.ssi => const Color(0xFF42a5f5),
    CertificationAgency.naui => const Color(0xFF43a047),
    CertificationAgency.sdi => const Color(0xFF1976d2),
    CertificationAgency.tdi => const Color(0xFF7b1fa2),
    CertificationAgency.gue => const Color(0xFF757575),
    CertificationAgency.raid => const Color(0xFFe53935),
    CertificationAgency.bsac => const Color(0xFF42a5f5),
    CertificationAgency.cmas => const Color(0xFF26a69a),
    CertificationAgency.iantd => const Color(0xFF5c6bc0),
    CertificationAgency.psai => const Color(0xFF66bb6a),
    CertificationAgency.other => const Color(0xFF26c6da),
  };
}
```

**Step 2: Verify build succeeds**

Run: `flutter analyze lib/core/constants/enums.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/core/constants/enums.dart
git commit -m "feat(certifications): add brand colors to CertificationAgency enum"
```

---

## Task 2: Create the Single eCard Widget

**Files:**
- Create: `lib/features/certifications/presentation/widgets/certification_ecard.dart`

**Step 1: Create the eCard widget file**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';

/// A credit card-style widget displaying a certification
class CertificationEcard extends StatelessWidget {
  final Certification certification;
  final String diverName;
  final bool showBack;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Standard credit card aspect ratio (CR80: 85.6mm x 53.98mm)
  static const double aspectRatio = 1.586;

  const CertificationEcard({
    super.key,
    required this.certification,
    required this.diverName,
    this.showBack = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            final rotate = Tween(begin: 1.0, end: 0.0).animate(animation);
            return AnimatedBuilder(
              animation: rotate,
              builder: (context, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(rotate.value * 3.14159),
                child: child,
              ),
              child: child,
            );
          },
          child: showBack ? _buildBack(context) : _buildFront(context),
        ),
      ),
    );
  }

  Widget _buildFront(BuildContext context) {
    final agency = certification.agency;
    final primaryColor = agency.primaryColor;
    final secondaryColor = agency.secondaryColor;

    return Container(
      key: const ValueKey('front'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative wave pattern
          Positioned.fill(child: _buildWavePattern()),
          // Card content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Agency name
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      agency.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (certification.isExpired)
                      _buildStatusBadge('EXPIRED', Colors.red)
                    else if (certification.expiresWithin(90))
                      _buildStatusBadge('EXPIRING', Colors.orange),
                  ],
                ),
                const Spacer(),
                // Certification name
                Text(
                  certification.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (certification.level != null)
                  Text(
                    certification.level!.displayName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 16),
                // Bottom row: diver name, card number, date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            diverName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (certification.cardNumber != null)
                            Text(
                              certification.cardNumber!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (certification.issueDate != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ISSUED',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            DateFormat('MM/yy').format(certification.issueDate!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack(BuildContext context) {
    // If photo exists, show it; otherwise show generated back
    if (certification.photoBack != null) {
      return Container(
        key: const ValueKey('back'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(
          certification.photoBack!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildGeneratedBack(context),
        ),
      );
    }
    return _buildGeneratedBack(context);
  }

  Widget _buildGeneratedBack(BuildContext context) {
    final agency = certification.agency;

    return Container(
      key: const ValueKey('back'),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Magnetic stripe
          Container(
            height: 40,
            margin: const EdgeInsets.only(top: 24),
            color: Colors.grey[800],
          ),
          const Spacer(),
          // Info section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (certification.instructorName != null) ...[
                  Text(
                    'Instructor: ${certification.instructorName}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
                if (certification.instructorNumber != null)
                  Text(
                    'Instructor #: ${certification.instructorNumber}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Certified by ${agency.displayName}',
                  style: TextStyle(
                    color: agency.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWavePattern() {
    return CustomPaint(
      painter: _WavePatternPainter(),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Paints a subtle wave/bubble pattern on the card
class _WavePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    // Draw some decorative circles
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.2),
      size.width * 0.3,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.8),
      size.width * 0.25,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

**Step 2: Verify build succeeds**

Run: `flutter analyze lib/features/certifications/presentation/widgets/certification_ecard.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/certifications/presentation/widgets/certification_ecard.dart
git commit -m "feat(certifications): create CertificationEcard widget with agency branding"
```

---

## Task 3: Create the Card Stack Widget

**Files:**
- Create: `lib/features/certifications/presentation/widgets/certification_ecard_stack.dart`

**Step 1: Create the stack widget**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard.dart';

/// A stacked view of certification cards with swipe navigation
class CertificationEcardStack extends StatefulWidget {
  final List<Certification> certifications;
  final String diverName;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;
  final ValueChanged<Certification>? onCardTap;
  final ValueChanged<Certification>? onCardLongPress;

  const CertificationEcardStack({
    super.key,
    required this.certifications,
    required this.diverName,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.onCardTap,
    this.onCardLongPress,
  });

  @override
  State<CertificationEcardStack> createState() => _CertificationEcardStackState();
}

class _CertificationEcardStackState extends State<CertificationEcardStack> {
  late int _currentIndex;
  late PageController _pageController;
  final Map<int, bool> _showBack = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.certifications.length - 1);
    _pageController = PageController(
      initialPage: _currentIndex,
      viewportFraction: 0.85,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      // Reset flip state when changing cards
      _showBack.clear();
    });
    widget.onIndexChanged?.call(index);
  }

  void _toggleFlip(int index) {
    setState(() {
      _showBack[index] = !(_showBack[index] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.certifications.isEmpty) {
      return const _EmptyState();
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.certifications.length,
            itemBuilder: (context, index) {
              final cert = widget.certifications[index];
              final isActive = index == _currentIndex;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: isActive ? 16 : 32,
                ),
                child: Transform.scale(
                  scale: isActive ? 1.0 : 0.9,
                  child: CertificationEcard(
                    certification: cert,
                    diverName: widget.diverName,
                    showBack: _showBack[index] ?? false,
                    onTap: () {
                      if (isActive) {
                        _toggleFlip(index);
                      } else {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      }
                      widget.onCardTap?.call(cert);
                    },
                    onLongPress: () => widget.onCardLongPress?.call(cert),
                  ),
                ),
              );
            },
          ),
        ),
        // Page indicator
        if (widget.certifications.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _PageIndicator(
              count: widget.certifications.length,
              currentIndex: _currentIndex,
              onDotTap: (index) {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final ValueChanged<int>? onDotTap;

  const _PageIndicator({
    required this.count,
    required this.currentIndex,
    this.onDotTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return GestureDetector(
          onTap: () => onDotTap?.call(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.card_membership_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No certifications yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first certification to see it here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Verify build succeeds**

Run: `flutter analyze lib/features/certifications/presentation/widgets/certification_ecard_stack.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/certifications/presentation/widgets/certification_ecard_stack.dart
git commit -m "feat(certifications): create CertificationEcardStack with swipe navigation"
```

---

## Task 4: Create the Wallet Page

**Files:**
- Create: `lib/features/certifications/presentation/pages/certification_wallet_page.dart`

**Step 1: Create the wallet page**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard_stack.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_share_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Full-screen wallet view of certification cards
class CertificationWalletPage extends ConsumerStatefulWidget {
  const CertificationWalletPage({super.key});

  @override
  ConsumerState<CertificationWalletPage> createState() =>
      _CertificationWalletPageState();
}

class _CertificationWalletPageState
    extends ConsumerState<CertificationWalletPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final certificationsAsync = ref.watch(certificationListNotifierProvider);
    final diverAsync = ref.watch(currentDiverProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Certification Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Certification',
            onPressed: () => context.push('/certifications/new'),
          ),
        ],
      ),
      body: certificationsAsync.when(
        data: (certifications) {
          final diverName = diverAsync.valueOrNull?.firstName ?? 'Diver';

          return CertificationEcardStack(
            certifications: certifications,
            diverName: diverName,
            onIndexChanged: (index) {
              setState(() => _currentIndex = index);
            },
            onCardLongPress: (cert) => _showCardOptions(context, cert),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load certifications: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(certificationListNotifierProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: certificationsAsync.maybeWhen(
        data: (certs) => certs.isNotEmpty
            ? FloatingActionButton(
                onPressed: () => _showShareSheet(context, certs[_currentIndex]),
                child: const Icon(Icons.share),
              )
            : null,
        orElse: () => null,
      ),
    );
  }

  void _showCardOptions(BuildContext context, Certification cert) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _showShareSheet(context, cert);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                context.push('/certifications/${cert.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                context.push('/certifications/${cert.id}/edit');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShareSheet(BuildContext context, Certification cert) {
    final diverName =
        ref.read(currentDiverProvider).valueOrNull?.firstName ?? 'Diver';

    showModalBottomSheet(
      context: context,
      builder: (context) => CertificationShareSheet(
        certification: cert,
        diverName: diverName,
      ),
    );
  }
}
```

**Step 2: Verify build succeeds**

Run: `flutter analyze lib/features/certifications/presentation/pages/certification_wallet_page.dart`
Expected: No issues found (may show error for missing CertificationShareSheet - that's Task 6)

**Step 3: Commit**

```bash
git add lib/features/certifications/presentation/pages/certification_wallet_page.dart
git commit -m "feat(certifications): create CertificationWalletPage with full-screen stack"
```

---

## Task 5: Create Card Renderer Service

**Files:**
- Create: `lib/features/certifications/presentation/services/certification_card_renderer.dart`

**Step 1: Create the renderer service**

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard.dart';

/// Service for rendering certification cards to images
class CertificationCardRenderer {
  /// Renders the eCard widget to a PNG image
  ///
  /// Returns the image as bytes suitable for sharing
  static Future<Uint8List?> renderCard({
    required Certification certification,
    required String diverName,
    bool showBack = false,
  }) async {
    // Card dimensions (2x for retina)
    const double width = 1012;
    const double height = width / CertificationEcard.aspectRatio;

    final widget = MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: CertificationEcard(
              certification: certification,
              diverName: diverName,
              showBack: showBack,
            ),
          ),
        ),
      ),
    );

    return _renderWidget(widget, Size(width, height));
  }

  /// Renders a formal certificate-style image
  static Future<Uint8List?> renderCertificate({
    required Certification certification,
    required String diverName,
  }) async {
    const double width = 1200;
    const double height = 800;

    final widget = MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: _CertificateView(
              certification: certification,
              diverName: diverName,
            ),
          ),
        ),
      ),
    );

    return _renderWidget(widget, const Size(width, height));
  }

  static Future<Uint8List?> _renderWidget(Widget widget, Size size) async {
    final repaintBoundary = RenderRepaintBoundary();

    final renderView = RenderView(
      view: ui.PlatformDispatcher.instance.views.first,
      child: RenderPositionedBox(
        alignment: Alignment.center,
        child: repaintBoundary,
      ),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        devicePixelRatio: 1.0,
      ),
    );

    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    final buildOwner = BuildOwner(focusManager: FocusManager());

    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: widget,
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final image = await repaintBoundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }
}

/// Certificate-style formal view for export
class _CertificateView extends StatelessWidget {
  final Certification certification;
  final String diverName;

  const _CertificateView({
    required this.certification,
    required this.diverName,
  });

  @override
  Widget build(BuildContext context) {
    final agency = certification.agency;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: agency.primaryColor, width: 8),
      ),
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Agency header
          Text(
            agency.displayName,
            style: TextStyle(
              color: agency.primaryColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 32),
          // Certificate statement
          Text(
            'This certifies that',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          // Diver name
          Text(
            diverName.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'has successfully completed training as',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          // Certification name
          Text(
            certification.name,
            style: TextStyle(
              color: agency.primaryColor,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (certification.level != null)
            Text(
              certification.level!.displayName,
              style: TextStyle(
                color: agency.secondaryColor,
                fontSize: 20,
              ),
            ),
          const SizedBox(height: 32),
          // Details row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (certification.cardNumber != null) ...[
                _DetailColumn(label: 'Card Number', value: certification.cardNumber!),
                const SizedBox(width: 48),
              ],
              if (certification.issueDate != null)
                _DetailColumn(
                  label: 'Date Issued',
                  value: DateFormat.yMMMd().format(certification.issueDate!),
                ),
            ],
          ),
          const Spacer(),
          // Footer
          Text(
            'Submersion Dive Log',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailColumn extends StatelessWidget {
  final String label;
  final String value;

  const _DetailColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
```

**Step 2: Verify build succeeds**

Run: `flutter analyze lib/features/certifications/presentation/services/certification_card_renderer.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/certifications/presentation/services/certification_card_renderer.dart
git commit -m "feat(certifications): create CertificationCardRenderer for image export"
```

---

## Task 6: Create Share Sheet Widget

**Files:**
- Create: `lib/features/certifications/presentation/widgets/certification_share_sheet.dart`

**Step 1: Create the share sheet**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/services/certification_card_renderer.dart';

/// Bottom sheet for sharing certification as image
class CertificationShareSheet extends StatefulWidget {
  final Certification certification;
  final String diverName;

  const CertificationShareSheet({
    super.key,
    required this.certification,
    required this.diverName,
  });

  @override
  State<CertificationShareSheet> createState() => _CertificationShareSheetState();
}

class _CertificationShareSheetState extends State<CertificationShareSheet> {
  bool _isExporting = false;
  String? _error;

  Future<void> _shareAsCard() async {
    setState(() {
      _isExporting = true;
      _error = null;
    });

    try {
      final imageBytes = await CertificationCardRenderer.renderCard(
        certification: widget.certification,
        diverName: widget.diverName,
      );

      if (imageBytes == null) {
        throw Exception('Failed to render card');
      }

      await _shareImage(imageBytes, 'certification_card.png');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _shareAsCertificate() async {
    setState(() {
      _isExporting = true;
      _error = null;
    });

    try {
      final imageBytes = await CertificationCardRenderer.renderCertificate(
        certification: widget.certification,
        diverName: widget.diverName,
      );

      if (imageBytes == null) {
        throw Exception('Failed to render certificate');
      }

      await _shareImage(imageBytes, 'certification.png');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _shareImage(List<int> bytes, String filename) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes);

    if (mounted) {
      Navigator.pop(context);
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      text: '${widget.certification.name} - ${widget.certification.agency.displayName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share Certification',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.certification.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _ShareOption(
              icon: Icons.credit_card,
              title: 'Share as Card',
              subtitle: 'Beautiful branded card image',
              isLoading: _isExporting,
              onTap: _isExporting ? null : _shareAsCard,
            ),
            const SizedBox(height: 12),
            _ShareOption(
              icon: Icons.article_outlined,
              title: 'Share as Certificate',
              subtitle: 'Formal certificate document',
              isLoading: _isExporting,
              onTap: _isExporting ? null : _shareAsCertificate,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.chevron_right, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Verify build succeeds**

Run: `flutter analyze lib/features/certifications/presentation/widgets/certification_share_sheet.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/certifications/presentation/widgets/certification_share_sheet.dart
git commit -m "feat(certifications): create CertificationShareSheet for export options"
```

---

## Task 7: Add Wallet Route to Router

**Files:**
- Modify: `lib/core/router/app_router.dart:396-427`

**Step 1: Add import for wallet page**

Near the top imports (around line 16), add:

```dart
import 'package:submersion/features/certifications/presentation/pages/certification_wallet_page.dart';
```

**Step 2: Add wallet route**

Inside the certifications GoRoute routes array (after line 404, before the `new` route), add:

```dart
              GoRoute(
                path: 'wallet',
                name: 'certificationWallet',
                builder: (context, state) => const CertificationWalletPage(),
              ),
```

**Step 3: Verify build succeeds**

Run: `flutter analyze lib/core/router/app_router.dart`
Expected: No issues found

**Step 4: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(certifications): add wallet route to app router"
```

---

## Task 8: Create Dashboard Wallet Widget

**Files:**
- Create: `lib/features/certifications/presentation/widgets/certification_wallet_card.dart`

**Step 1: Create the dashboard widget**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';

/// Dashboard card showing a mini certification wallet preview
class CertificationWalletCard extends ConsumerWidget {
  const CertificationWalletCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificationsAsync = ref.watch(certificationListNotifierProvider);

    return certificationsAsync.when(
      data: (certifications) => _CertificationWalletCardContent(
        certifications: certifications,
      ),
      loading: () => const _LoadingCard(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _CertificationWalletCardContent extends StatelessWidget {
  final List<Certification> certifications;

  const _CertificationWalletCardContent({required this.certifications});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Count warnings
    final expiredCount = certifications.where((c) => c.isExpired).length;
    final expiringCount = certifications.where((c) => c.expiresWithin(90) && !c.isExpired).length;
    final warningCount = expiredCount + expiringCount;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/certifications/wallet'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.card_membership,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Certification Wallet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (warningCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: expiredCount > 0
                            ? colorScheme.error
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$warningCount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Card preview stack
              if (certifications.isEmpty)
                _EmptyWalletPreview()
              else
                _MiniCardStack(certifications: certifications),
              const SizedBox(height: 12),
              // Footer
              Row(
                children: [
                  Text(
                    certifications.isEmpty
                        ? 'Add your first certification'
                        : '${certifications.length} certification${certifications.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCardStack extends StatelessWidget {
  final List<Certification> certifications;

  const _MiniCardStack({required this.certifications});

  @override
  Widget build(BuildContext context) {
    // Show up to 3 cards stacked
    final displayCerts = certifications.take(3).toList();

    return SizedBox(
      height: 80,
      child: Stack(
        children: [
          for (int i = displayCerts.length - 1; i >= 0; i--)
            Positioned(
              left: i * 16.0,
              top: i * 4.0,
              child: _MiniCard(
                certification: displayCerts[i],
                isTop: i == 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final Certification certification;
  final bool isTop;

  const _MiniCard({
    required this.certification,
    this.isTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final agency = certification.agency;

    return Container(
      width: 120,
      height: 75,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [agency.primaryColor, agency.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: agency.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            agency.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            certification.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyWalletPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_card,
              color: theme.colorScheme.outline,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to add',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Verify build succeeds**

Run: `flutter analyze lib/features/certifications/presentation/widgets/certification_wallet_card.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/certifications/presentation/widgets/certification_wallet_card.dart
git commit -m "feat(certifications): create CertificationWalletCard dashboard widget"
```

---

## Task 9: Add Wallet Widget to Dashboard

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart`

**Step 1: Add import**

After line 15 (existing imports), add:

```dart
import 'package:submersion/features/certifications/presentation/widgets/certification_wallet_card.dart';
```

**Step 2: Add wallet card to dashboard layout**

Inside the Column children (around line 55, after PersonalRecordsCard), add:

```dart
                // Certification Wallet
                const CertificationWalletCard(),
                const SizedBox(height: 16),
```

**Step 3: Add invalidation for certifications refresh**

In the `onRefresh` callback (around line 37), add:

```dart
            ref.invalidate(certificationListNotifierProvider);
```

You'll also need to add the import at the top:

```dart
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
```

**Step 4: Verify build succeeds**

Run: `flutter analyze lib/features/dashboard/presentation/pages/dashboard_page.dart`
Expected: No issues found

**Step 5: Commit**

```bash
git add lib/features/dashboard/presentation/pages/dashboard_page.dart
git commit -m "feat(dashboard): add certification wallet card"
```

---

## Task 10: Add Wallet Button to Certifications List Page

**Files:**
- Modify: `lib/features/certifications/presentation/pages/certification_list_page.dart`

**Step 1: Read the file to find the AppBar actions**

Look for the AppBar in the certification list page and add a wallet button.

**Step 2: Add wallet icon button to AppBar actions**

Add this icon button alongside existing actions:

```dart
IconButton(
  icon: const Icon(Icons.wallet),
  tooltip: 'Wallet View',
  onPressed: () => context.push('/certifications/wallet'),
),
```

**Step 3: Verify build succeeds**

Run: `flutter analyze lib/features/certifications/presentation/pages/certification_list_page.dart`
Expected: No issues found

**Step 4: Commit**

```bash
git add lib/features/certifications/presentation/pages/certification_list_page.dart
git commit -m "feat(certifications): add wallet button to list page"
```

---

## Task 11: Update REMAINING_TASKS.md

**Files:**
- Modify: `REMAINING_TASKS.md`

**Step 1: Mark tasks as complete**

Find the eCards section and update:

```markdown
### 8.2 Digital Cards (eCards)
| Feature | Status | Notes |
|---------|--------|-------|
| eCard wallet | Done | Display certs in wallet format |

**Tasks:**
- [x] Certification wallet view (card-style UI)
- [x] Export cert card as image (shareable)
```

**Step 2: Commit**

```bash
git add REMAINING_TASKS.md
git commit -m "docs: mark certification eCards tasks as complete"
```

---

## Task 12: Manual Testing

**No files to modify - testing only**

**Step 1: Run the app**

Run: `flutter run -d macos`

**Step 2: Test wallet view**

1. Navigate to Dashboard - verify wallet card appears
2. Tap wallet card - verify wallet page opens
3. Swipe between cards - verify smooth animation
4. Tap card - verify flip animation
5. Long-press card - verify options menu

**Step 3: Test sharing**

1. Tap share FAB - verify share sheet appears
2. Select "Share as Card" - verify image generates and share sheet opens
3. Select "Share as Certificate" - verify formal certificate generates

**Step 4: Test from certifications page**

1. Navigate to Certifications
2. Tap wallet icon in AppBar
3. Verify wallet opens

---

Plan complete and saved to `docs/plans/2026-02-01-certification-ecards-implementation.md`.

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?