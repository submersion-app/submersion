import 'package:submersion/features/equipment/figure/domain/figure_model.dart';

/// Keeps the last composed figure while its inputs are unchanged, so a
/// rebuild for a highlight flash reuses the same model object (and with it
/// the label layout the widget caches against it).
///
/// The key is whatever the caller's inputs compare by: a record of the item
/// list (compared by identity), the arrangement, and the locale, for
/// example.
class FigureModelMemo {
  Object? _key;
  FigureModel? _model;

  FigureModel of(Object key, FigureModel Function() compose) {
    final cached = _model;
    if (cached != null && key == _key) return cached;
    _key = key;
    return _model = compose();
  }
}
