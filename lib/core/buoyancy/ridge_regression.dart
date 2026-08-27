/// Weighted ridge regression toward a prior, via normal equations.
///
/// Solves argmin_b  sum_i w_i (y_i - x_i . b)^2
///               + sum_j lambda_j (b_j - prior_j)^2
/// i.e. (X^T W X + diag(lambda)) b = X^T W y + diag(lambda) prior,
/// with Gaussian elimination and partial pivoting. Feature counts here are
/// tens at most, so the dense O(p^3) solve is effectively free.
class RidgeRegression {
  static List<double> solve({
    required List<List<double>> x,
    required List<double> y,
    required List<double> weights,
    required List<double> prior,
    required List<double> lambda,
  }) {
    final p = prior.length;
    assert(lambda.length == p);
    assert(x.length == y.length && y.length == weights.length);

    // Normal matrix A = X^T W X + diag(lambda); RHS = X^T W y + lambda*prior.
    final a = List.generate(p, (_) => List.filled(p + 1, 0.0));
    for (var j = 0; j < p; j++) {
      a[j][j] = lambda[j];
      a[j][p] = lambda[j] * prior[j];
    }
    for (var i = 0; i < x.length; i++) {
      final w = weights[i];
      if (w == 0) continue;
      final row = x[i];
      for (var j = 0; j < p; j++) {
        if (row[j] == 0) continue;
        final wj = w * row[j];
        for (var k = 0; k < p; k++) {
          a[j][k] += wj * row[k];
        }
        a[j][p] += wj * y[i];
      }
    }

    // Gaussian elimination with partial pivoting on the augmented matrix.
    for (var col = 0; col < p; col++) {
      var pivot = col;
      for (var r = col + 1; r < p; r++) {
        if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
      }
      if (a[pivot][col].abs() < 1e-12) {
        // Cannot happen with lambda > 0; guard anyway.
        throw StateError('Singular normal matrix at column $col');
      }
      if (pivot != col) {
        final tmp = a[col];
        a[col] = a[pivot];
        a[pivot] = tmp;
      }
      for (var r = col + 1; r < p; r++) {
        final factor = a[r][col] / a[col][col];
        if (factor == 0) continue;
        for (var k = col; k <= p; k++) {
          a[r][k] -= factor * a[col][k];
        }
      }
    }
    final b = List.filled(p, 0.0);
    for (var row = p - 1; row >= 0; row--) {
      var sum = a[row][p];
      for (var k = row + 1; k < p; k++) {
        sum -= a[row][k] * b[k];
      }
      b[row] = sum / a[row][row];
    }
    return b;
  }
}
