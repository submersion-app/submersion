import 'package:submersion/features/equipment/figure/domain/figure_view.dart';

/// An anchor point on the mannequin where a type of gear sits.
///
/// Coordinates are in figure space (see `figure_space.dart`) as the viewer
/// sees them. "Left" and "right" name the diver's own side: on the front view
/// the diver's left is on the viewer's left, and on the back view it is on the
/// viewer's right, which is why the back-view `...Left` zones carry the larger
/// x and are the mirrored ones there.
///
/// A piece is authored for the unmirrored twin of a pair; a zone with
/// [mirrored] set has the painter flip that piece about x = 100. The camera
/// arm has no twin: its strobe piece is authored on the viewer's left and
/// flipped to sit beside the camera in the right hand.
///
/// Back-view anchors sit where their gear shows beside the tank, which
/// covers the centre line from the shoulders to the waist.
enum FigureZone {
  // Front, head.
  head(FigureView.front, 100, 22),
  face(FigureView.front, 100, 40),
  hud(FigureView.front, 118, 36),
  maskStrap(FigureView.front, 128, 42),
  mouth(FigureView.front, 100, 58),
  // Front, torso.
  octo(FigureView.front, 120, 110),
  chestClipLeft(FigureView.front, 80, 100),
  chestClipRight(FigureView.front, 120, 100, mirrored: true),
  chest(FigureView.front, 100, 120),
  torsoFront(FigureView.front, 100, 140),
  suit(FigureView.front, 58, 110),
  underlayer(FigureView.front, 142, 110, capacity: 2),
  stageLeft(FigureView.front, 62, 160),
  stageRight(FigureView.front, 138, 160, mirrored: true),
  // Front, arms and hands.
  wristLeft(FigureView.front, 53, 186),
  wristRight(FigureView.front, 147, 186, mirrored: true),
  hands(FigureView.front, 53, 204),
  handLeft(FigureView.front, 53, 222),
  handRight(FigureView.front, 147, 222, mirrored: true),
  cameraArm(FigureView.front, 178, 258, capacity: 2, mirrored: true),
  console(FigureView.front, 62, 230),
  // Front, waist and legs.
  waist(FigureView.front, 100, 198),
  hipLeft(FigureView.front, 74, 206),
  hipRight(FigureView.front, 126, 206, mirrored: true),
  thighLeft(FigureView.front, 78, 250),
  thighRight(FigureView.front, 122, 250, mirrored: true),
  dpv(FigureView.front, 100, 280),
  calfLeft(FigureView.front, 76, 300),
  ankles(FigureView.front, 100, 335),
  feet(FigureView.front, 100, 352),
  fins(FigureView.front, 100, 380),
  // Back.
  tankValve(FigureView.back, 100, 74, capacity: 2),
  backTank(FigureView.back, 100, 130, capacity: 2),
  wing(FigureView.back, 126, 150),
  backplate(FigureView.back, 118, 176),
  trimRight(FigureView.back, 76, 176),
  trimLeft(FigureView.back, 124, 176, mirrored: true),
  buttDRing(FigureView.back, 100, 214),
  sidemountRight(FigureView.back, 60, 160),
  sidemountLeft(FigureView.back, 140, 160, mirrored: true);

  const FigureZone(
    this.view,
    this.anchorX,
    this.anchorY, {
    this.capacity = 1,
    this.mirrored = false,
  });

  final FigureView view;
  final double anchorX;
  final double anchorY;

  /// How many items the zone holds before the next candidate is tried.
  final int capacity;

  /// Whether a piece placed here is flipped about the centre line.
  final bool mirrored;
}
