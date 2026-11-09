/// Tuning for the photo behind a dive card, kept in one place so the crop
/// and the readability overlay can be adjusted against real dive photos.
///
/// The crop weights are starting guesses, not measured values.
abstract final class CardPhotoTuning {
  /// Whether the crop looks at the photo's pixels when no people are
  /// tagged on it. Off, such a photo is centred.
  static const usePixelAnalysis = true;

  /// The longest side of the decode the pixel analysis reads.
  static const analysisSize = 64;

  /// Pixels darker than this (Rec. 709 luma, 0..1) are sensor noise and
  /// score nothing.
  static const minLuma = 0.04;

  /// Below this share of usable pixels the frame is black water or a
  /// blown-out shot, and the crop stays centred.
  static const minUsableShare = 0.05;

  /// Weight of local brightness change (texture, outlines).
  static const detailWeight = 1.0;

  /// Weight of a pixel's distance from the photo's mean colour (a strobe-lit
  /// subject against blue-green water).
  static const colourWeight = 0.6;

  /// No pixel scores above this, so a few extreme ones cannot decide.
  static const pixelScoreCap = 0.6;

  /// How much a strip at the very top or bottom is discounted against one
  /// in the middle (0 = no pull to the centre).
  static const centrePull = 0.2;

  /// The best strip must beat the centred one by this share, or the crop
  /// stays centred.
  static const minGainOverCentre = 0.15;

  /// The overlay opacity a diver can choose, per theme, and its step.
  static const overlayMin = 0.2;
  static const overlayMax = 0.95;
  static const overlayStep = 0.05;

  /// How the overlay's opacity varies from the card's top to its bottom
  /// around the chosen value: a little lighter at the top, a little heavier
  /// at the bottom, as the map background's gradient is.
  static const overlayShape = [-0.15, -0.07, 0.07, 0.15];

  /// The overlay's opacities, top to bottom, for a chosen [opacity].
  static List<double> overlayAlphas(double opacity) => [
    for (final offset in overlayShape) (opacity + offset).clamp(0.0, 1.0),
  ];

  /// How long the photo takes to fade in once it is ready.
  static const fadeIn = Duration(milliseconds: 250);

  /// How many of a dive's photos a card tries before it gives up on photos
  /// and shows the map or the attribute colour instead.
  static const maxPhotoAttempts = 3;
}
