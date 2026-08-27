import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/ridge_regression.dart';

// Expected values computed exactly with python3 fractions (plan Task 9):
//   A: 20 obs of y=5 on one feature, prior 0, lambda 2 -> 100/22
//   B: 10 obs x=[1,1] y=6, priors [5,-0.5], lambda [2,2]
//      -> [250/44, 8/44]; deviations from priors are equal (0.681818...)
//   C: x=[[1,0],[0,1],[1,1]], y=[1,2,3.5], prior 0, lambda 0.5
//      -> [1.095238..., 1.761904...]
//   D: weight-0 row ignored -> 10/3
void main() {
  test('n=0 returns the priors exactly', () {
    final b = RidgeRegression.solve(
      x: const [],
      y: const [],
      weights: const [],
      prior: const [3.5, -1.0],
      lambda: const [2.0, 2.0],
    );
    expect(b, [3.5, -1.0]);
  });

  test('consistent observations dominate a weak prior', () {
    final b = RidgeRegression.solve(
      x: List.generate(20, (_) => [1.0]),
      y: List.filled(20, 5.0),
      weights: List.filled(20, 1.0),
      prior: const [0.0],
      lambda: const [2.0],
    );
    expect(b.single, closeTo(4.545454545, 1e-9));
  });

  test('perfectly correlated features: sum is data-driven, split follows '
      'priors', () {
    final b = RidgeRegression.solve(
      x: List.generate(10, (_) => [1.0, 1.0]),
      y: List.filled(10, 6.0),
      weights: List.filled(10, 1.0),
      prior: const [5.0, -0.5],
      lambda: const [2.0, 2.0],
    );
    expect(b[0], closeTo(5.681818181, 1e-9));
    expect(b[1], closeTo(0.181818181, 1e-9));
    // Both coefficients deviate from their priors by the same amount.
    expect(b[0] - 5.0, closeTo(b[1] + 0.5, 1e-9));
  });

  test('known 2x2 system matches the hand-computed solution', () {
    final b = RidgeRegression.solve(
      x: const [
        [1.0, 0.0],
        [0.0, 1.0],
        [1.0, 1.0],
      ],
      y: const [1.0, 2.0, 3.5],
      weights: const [1.0, 1.0, 1.0],
      prior: const [0.0, 0.0],
      lambda: const [0.5, 0.5],
    );
    expect(b[0], closeTo(1.095238095, 1e-9));
    expect(b[1], closeTo(1.761904761, 1e-9));
  });

  test('a weight-0 observation has no influence', () {
    final b = RidgeRegression.solve(
      x: const [
        [1.0],
        [1.0],
        [1.0],
      ],
      y: const [5.0, 5.0, 100.0],
      weights: const [1.0, 1.0, 0.0],
      prior: const [0.0],
      lambda: const [1.0],
    );
    expect(b.single, closeTo(10.0 / 3.0, 1e-9));
  });
}
