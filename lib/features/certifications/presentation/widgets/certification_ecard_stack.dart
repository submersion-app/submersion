import 'package:flutter/material.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard.dart';

/// A swipeable stack of certification e-cards with peeking adjacent cards.
///
/// Displays multiple certifications in a horizontal page view with visual
/// feedback for the active card, flip-to-back functionality, and page
/// indicator dots.
class CertificationEcardStack extends StatefulWidget {
  /// The list of certifications to display.
  final List<Certification> certifications;

  /// The name of the diver holding these certifications.
  final String diverName;

  /// The initial card index to display (default: 0).
  final int initialIndex;

  /// Callback when the current card index changes.
  final ValueChanged<int>? onIndexChanged;

  /// Callback when a card is tapped.
  final ValueChanged<Certification>? onCardTap;

  /// Callback when a card is long-pressed.
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
  State<CertificationEcardStack> createState() =>
      _CertificationEcardStackState();
}

class _CertificationEcardStackState extends State<CertificationEcardStack> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, bool> _flippedCards = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.certifications.isEmpty ? 0 : widget.certifications.length - 1,
    );
    _pageController = PageController(
      initialPage: _currentIndex,
      viewportFraction: 0.85,
    );
  }

  @override
  void didUpdateWidget(CertificationEcardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset flipped cards when certifications change
    if (oldWidget.certifications != widget.certifications) {
      _flippedCards.clear();
      // Ensure current index is valid
      if (_currentIndex >= widget.certifications.length) {
        _currentIndex = widget.certifications.isEmpty
            ? 0
            : widget.certifications.length - 1;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    widget.onIndexChanged?.call(index);
  }

  void _navigateToPage(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleCardTap(int index, Certification certification) {
    if (index == _currentIndex) {
      // Toggle flip on active card
      setState(() {
        _flippedCards[index] = !(_flippedCards[index] ?? false);
      });
      widget.onCardTap?.call(certification);
    } else {
      // Navigate to tapped card
      _navigateToPage(index);
    }
  }

  void _handleCardLongPress(Certification certification) {
    widget.onCardLongPress?.call(certification);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.certifications.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.certifications.length,
            itemBuilder: (context, index) {
              return _buildCard(context, index);
            },
          ),
        ),
        if (widget.certifications.length > 1) ...[
          const SizedBox(height: 16),
          _buildPageIndicator(context),
        ],
      ],
    );
  }

  Widget _buildCard(BuildContext context, int index) {
    final certification = widget.certifications[index];
    final isActive = index == _currentIndex;
    final isFlipped = _flippedCards[index] ?? false;

    return ListenableBuilder(
      listenable: _pageController,
      builder: (context, child) {
        double scale = 0.9;
        double verticalMargin = 32.0;

        if (_pageController.position.haveDimensions) {
          final page = _pageController.page ?? _currentIndex.toDouble();
          final difference = (page - index).abs();
          scale = 1.0 - (difference * 0.1).clamp(0.0, 0.1);
          verticalMargin = 16.0 + (difference * 16.0).clamp(0.0, 16.0);
        } else if (isActive) {
          scale = 1.0;
          verticalMargin = 16.0;
        }

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: verticalMargin),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: CertificationEcard(
        certification: certification,
        diverName: widget.diverName,
        showBack: isFlipped,
        onTap: () => _handleCardTap(index, certification),
        onLongPress: () => _handleCardLongPress(certification),
      ),
    );
  }

  Widget _buildPageIndicator(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.certifications.length, (index) {
        final isActive = index == _currentIndex;
        return GestureDetector(
          onTap: () => _navigateToPage(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive ? theme.colorScheme.primary : Colors.transparent,
              border: Border.all(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: 1.5,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_membership,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No certifications yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first certification to see it here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
