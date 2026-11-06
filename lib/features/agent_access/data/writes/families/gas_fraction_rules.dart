/// A gas fraction on the wire as the percent the store holds, to a tenth of
/// a percent so 0.32 reads back as 0.32. Null stays null.
double? percentOf(Object? fraction) =>
    fraction is num ? (fraction * 1000).roundToDouble() / 10 : null;
