import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_model_memo.dart';

void main() {
  test('an equal key reuses the model; a new one composes again', () {
    final memo = FigureModelMemo();
    var composed = 0;
    final list = <Object>[];
    FigureModel compose() {
      composed++;
      return composeFigure(const []);
    }

    final first = memo.of((list, 'a'), compose);
    final again = memo.of((list, 'a'), compose);
    expect(identical(first, again), isTrue);
    expect(composed, 1);
    memo.of((list, 'b'), compose);
    expect(composed, 2);
    memo.of((<Object>[], 'b'), compose);
    expect(composed, 3, reason: 'a new list is a new key');
  });
}
