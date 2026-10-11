part of 'dive_trend_chart.dart';

/// The readout, tap, axis-title and break-band overlay builders of
/// [DiveTrendChart], split out to keep the chart file within the size
/// guideline.
extension _DiveTrendChartTouch on _DiveTrendChartState {
  LineTouchData _touchData(
    BuildContext context,
    List<LineChartBarData> bars,
    List<String> seriesLabels,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final dataBar = bars.first;
    final secondaryBars = _secondaryBarStart < 0
        ? const <LineChartBarData>[]
        : bars.sublist(_secondaryBarStart);
    return LineTouchData(
      // Generous, so the readout follows the pointer anywhere over the plot
      // rather than only within a few pixels of a dot.
      touchSpotThreshold: 1000,
      // Full-height hover line. fl_chart's default stops at the touched spot,
      // so for a series sitting near zero it is a few pixels tall and reads as
      // no line at all.
      getTouchLineStart: (_, _) => double.negativeInfinity,
      getTouchLineEnd: (_, _) => double.infinity,
      // Highlight the touched point on the data series only. The band bounds
      // and the fitted overlays would each contribute their own dot and line,
      // stacking several markers on one touch.
      getTouchedSpotIndicator: (barData, spotIndexes) {
        if (_pointerInBreak != null ||
            (!identical(barData, dataBar) &&
                !secondaryBars.any((b) => identical(b, barData)))) {
          return List<TouchedSpotIndicatorData?>.filled(
            spotIndexes.length,
            null,
          );
        }
        return defaultTouchedIndicators(barData, spotIndexes);
      },
      touchCallback: (event, response) {
        _pointerAxisX = response?.touchChartCoordinate.dx;
        if (event is! FlTapUpEvent) return;
        final onDiveSelected = widget.onDiveSelected;
        if (onDiveSelected == null) return;
        // A tap on a band names the gap; it opens no dive.
        if (_pointerInBreak != null) return;
        // Every series reports its own nearest spot, so the first one
        // listed need not be the touched one: take the nearest of all.
        final spot = nearestTouchedDataSpot(
          response?.lineBarSpots ?? const [],
          (barIndex) =>
              barIndex == 0 ||
              (_secondaryBarStart >= 0 &&
                  barIndex >= _secondaryBarStart &&
                  barIndex - _secondaryBarStart < _drawnSecondary.length),
        );
        if (spot == null) return;
        final diveId = _diveIdForSpot(spot.barIndex, spot.spotIndex);
        if (diveId != null) onDiveSelected(diveId);
      },
      touchTooltipData: LineTouchTooltipData(
        // Wide enough for a labelled row such as "Rolling avg 85 psi/min"
        // without wrapping. Narrower readouts still size to their content;
        // this is only a cap, matching the dive profile chart.
        maxContentWidth: 320,
        getTooltipColor: (_) => colorScheme.inverseSurface,
        // Above the plot rather than over it: the bubble used to land on the
        // very point it was describing.
        showOnTopOfTheChartBoxArea: true,
        tooltipMargin: 0,
        fitInsideHorizontally: true,
        fitInsideVertically: false,
        getTooltipItems: (touchedSpots) {
          if (touchedSpots.isEmpty) return const <LineTooltipItem?>[];
          // Matches the dive profile chart's readout: monospace with tabular
          // figures so the value column lines up between rows.
          final style = TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 14,
            color: colorScheme.onInverseSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          );
          final format = DateFormat(widget.dateFormat.pattern);
          final gap = _pointerInBreak;
          if (gap != null) {
            return [
              for (var i = 0; i < touchedSpots.length; i++)
                i == 0
                    ? LineTooltipItem(
                        context.l10n.insights_trend_gap_noDives(
                          format.format(gap.start),
                          format.format(gap.end),
                        ),
                        style,
                      )
                    : null,
            ];
          }
          final date = _scale.toDate(touchedSpots.first.x);

          return [
            for (var i = 0; i < touchedSpots.length; i++)
              if (i == 0)
                LineTooltipItem(
                  format.format(date),
                  style,
                  children: [
                    for (final spot in touchedSpots)
                      TextSpan(
                        text:
                            '\n${DiveProfileChart.tooltipRowText(spot.barIndex < seriesLabels.length ? seriesLabels[spot.barIndex] : '', widget.valueFormatter?.call(spot.y) ?? spot.y.toStringAsFixed(1), _DiveTrendChartState._tooltipLabelWidth, _DiveTrendChartState._tooltipValueWidth)}',
                        style: style,
                      ),
                  ],
                  textAlign: TextAlign.start,
                )
              else
                null,
          ];
        },
      ),
    );
  }

  FlTitlesData _titles(
    BuildContext context,
    DateAxis dateAxis,
    ChartAxis yAxis,
  ) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          // fl_chart samples this interval to decide where to ask for a
          // label. Leaving it null lets fl_chart pick its own values, which
          // then never match a nominated tick and the axis renders blank.
          interval: dateAxis.labelInterval,
          getTitlesWidget: (value, meta) {
            final label = dateAxis.labelFor(value, step: meta.appliedInterval);
            if (label == null) return const Text('');
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: widget.yAxisLabel != null
            ? Text(
                widget.yAxisLabel!,
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
        axisNameSize: _yAxisNameSize,
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 50,
          interval: yAxis.interval,
          getTitlesWidget: (value, meta) {
            final formatter = widget.yAxisFormatter ?? widget.valueFormatter;
            return Text(
              formatter?.call(value) ?? value.toStringAsFixed(0),
              style: Theme.of(context).textTheme.bodySmall,
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  /// The hatched bands over the plot, one per visible collapsed gap, with
  /// their lengths under the x axis (issue #3251).
  Widget _breakBands(
    BuildContext context,
    double visibleMin,
    double visibleMax,
    double plotWidth,
    double height,
  ) {
    final theme = Theme.of(context);
    final plot = Rect.fromLTWH(
      trendChartPlotInsets.left + _yAxisNameSize,
      0,
      plotWidth,
      height - trendChartPlotInsets.bottom,
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          key: const ValueKey('trend-break-bands'),
          painter: TrendBreakBandPainter(
            bands: TrendBreakBandPainter.layout(
              breaks: _scale.breaks,
              visibleMin: visibleMin,
              visibleMax: visibleMax,
              plot: plot,
              labelOf: (b) => trendGapLengthLabel(b.start, b.end, context.l10n),
            ),
            plot: plot,
            hatch: theme.colorScheme.outline.withValues(alpha: 0.6),
            // Opaque, so the band hides anything drawn under it and reads
            // the same on every card surface.
            fill: theme.colorScheme.surfaceContainerHighest,
            labelStyle: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}
