import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/domain/practice/leitner.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_gallery_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_write_feedback.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The fewest species practice can make a fair round from.
const kPracticeMinSpecies = 4;

/// Naming the diver's own animals (issue #5027): a session of up to ten
/// rounds, each one of their confirmed crops and four names. Every answer is
/// saved as it is given, so leaving mid-session keeps what was answered.
class SpeciesPracticePage extends ConsumerStatefulWidget {
  const SpeciesPracticePage({super.key, this.random, this.now});

  /// Fixed in tests; a fresh generator otherwise.
  final Random? random;

  /// The clock answers are stamped with.
  final DateTime Function()? now;

  @override
  ConsumerState<SpeciesPracticePage> createState() =>
      _SpeciesPracticePageState();
}

class _Round {
  const _Round({
    required this.speciesId,
    required this.crop,
    required this.choices,
  });

  final String speciesId;
  final SpeciesCrop crop;
  final List<String> choices;
}

class _SpeciesPracticePageState extends ConsumerState<SpeciesPracticePage> {
  late final Random _random = widget.random ?? Random();
  List<_Round>? _rounds;

  /// The name picked in each round answered so far, by round index.
  Map<int, String> _picks = const {};
  int _index = 0;
  bool _scientific = false;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final poolAsync = ref.watch(speciesPracticePoolProvider);
    final statesAsync = ref.watch(speciesPracticeStatesProvider);
    final seenAsync = ref.watch(seenSpeciesProvider);
    final failure = [
      poolAsync,
      statesAsync,
      seenAsync,
    ].where((a) => a.hasError).firstOrNull;
    if (failure != null) return _failed(context, failure.error!);
    final pool = poolAsync.value;
    final states = statesAsync.value;
    final seen = seenAsync.value;
    final ready = pool != null && states != null && seen != null;
    final bySpecies = {
      for (final e in seen ?? const <SeenSpecies>[]) e.species.id: e,
    };
    if (ready) _rounds ??= _newSession(pool, states, bySpecies);
    final rounds = _rounds;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.marineLife_practice_title)),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : rounds == null
          ? _notEnough(context)
          : _index >= rounds.length
          ? _summary(context, rounds, bySpecies)
          : _round(context, rounds, bySpecies),
    );
  }

  /// A session, or null when too few species can be asked about.
  List<_Round>? _newSession(
    Map<String, List<SpeciesCrop>> pool,
    Map<String, PracticeState> states,
    Map<String, SeenSpecies> bySpecies,
  ) {
    final eligible = [
      for (final entry in pool.entries)
        if (entry.value.isNotEmpty && bySpecies.containsKey(entry.key))
          entry.key,
    ];
    if (eligible.length < kPracticeMinSpecies) return null;
    final categoryOf = <String, SpeciesCategory>{
      for (final id in eligible) id: bySpecies[id]!.species.category,
    };
    final ids = pickPracticeSession(
      pool: eligible,
      states: states,
      now: _now,
      random: _random,
    );
    return [
      for (final id in ids)
        _Round(
          speciesId: id,
          crop: pool[id]![_random.nextInt(pool[id]!.length)],
          choices: [
            id,
            ...pickDistractors(
              answer: id,
              categoryOf: categoryOf,
              random: _random,
            ),
          ]..shuffle(_random),
        ),
    ];
  }

  String _name(SeenSpecies? entry) {
    if (entry == null) return '';
    final common = entry.species.localizedCommonName(context.l10n);
    final scientific = entry.species.scientificName;
    return _scientific && scientific != null && scientific.isNotEmpty
        ? scientific
        : common;
  }

  /// Whether an answer is being saved: the choices wait until it is.
  bool _saving = false;

  /// Saves the answer first and only then marks the round answered, so a
  /// failed save leaves the round open to answer again.
  Future<void> _answer(_Round round, String picked) async {
    if (_picks.containsKey(_index) || _saving) return;
    final index = _index;
    final diverId = ref.read(currentDiverIdProvider);
    if (diverId == null) {
      setState(() => _picks = {..._picks, index: picked});
      return;
    }
    final states = ref.read(speciesPracticeStatesProvider).value ?? const {};
    final now = _now;
    final before =
        states[round.speciesId] ?? PracticeState.fresh(round.speciesId, now);
    final repository = ref.read(speciesPracticeRepositoryProvider);
    setState(() => _saving = true);
    final saved = await saveWithFeedback(
      context,
      () => repository.save(
        diverId,
        applyAnswer(before, correct: picked == round.speciesId, now: now),
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) _picks = {..._picks, index: picked};
    });
  }

  Widget _notEnough(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(child: Icon(Icons.quiz_outlined, size: 48)),
            const SizedBox(height: 12),
            Text(
              l10n.marineLife_practice_notEnough,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => _leave(context),
              child: Text(l10n.marineLife_practice_back),
            ),
          ],
        ),
      ),
    );
  }

  Widget _round(
    BuildContext context,
    List<_Round> rounds,
    Map<String, SeenSpecies> bySpecies,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final round = rounds[_index];
    final picked = _picks[_index];
    final last = _index == rounds.length - 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.marineLife_practice_progress(_index + 1, rounds.length),
                style: theme.textTheme.labelLarge,
              ),
            ),
            Flexible(
              child: SwitchListTile(
                key: const ValueKey('practice_scientific'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.marineLife_practice_scientificNames,
                  textAlign: TextAlign.end,
                ),
                value: _scientific,
                onChanged: (on) => setState(() => _scientific = on),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 360),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: IdentificationCrop(
                  mediaId: round.crop.mediaId,
                  identificationId: round.crop.identificationId,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.marineLife_practice_question,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final choice in round.choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton.tonal(
              key: ValueKey('practice_choice_$choice'),
              style: picked == null
                  ? null
                  : FilledButton.styleFrom(
                      backgroundColor: choice == round.speciesId
                          ? theme.colorScheme.primaryContainer
                          : choice == picked
                          ? theme.colorScheme.errorContainer
                          : null,
                    ),
              onPressed: picked == null ? () => _answer(round, choice) : () {},
              child: Text(_name(bySpecies[choice])),
            ),
          ),
        if (picked != null) ...[
          const SizedBox(height: 8),
          Text(
            picked == round.speciesId
                ? l10n.marineLife_practice_right
                : l10n.marineLife_practice_wrong(
                    _name(bySpecies[round.speciesId]),
                  ),
            style: theme.textTheme.titleMedium?.copyWith(
              color: picked == round.speciesId
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('practice_next'),
            onPressed: () => setState(() => _index++),
            child: Text(
              last
                  ? l10n.marineLife_practice_finish
                  : l10n.marineLife_practice_next,
            ),
          ),
        ],
      ],
    );
  }

  Widget _summary(
    BuildContext context,
    List<_Round> rounds,
    Map<String, SeenSpecies> bySpecies,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final right = [
      for (var i = 0; i < rounds.length; i++)
        if (_picks[i] == rounds[i].speciesId) i,
    ].length;
    final missed = [
      for (var i = 0; i < rounds.length; i++)
        if (_picks[i] != rounds[i].speciesId) rounds[i],
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.marineLife_practice_score(right, rounds.length),
          style: theme.textTheme.headlineSmall,
        ),
        if (missed.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.marineLife_practice_missedTitle,
            style: theme.textTheme.titleSmall,
          ),
          for (final round in missed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_name(bySpecies[round.speciesId])),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/species/${round.speciesId}'),
            ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: () => setState(() {
                _rounds = null;
                _picks = const {};
                _index = 0;
              }),
              child: Text(l10n.marineLife_practice_again),
            ),
            OutlinedButton(
              onPressed: () => _leave(context),
              child: Text(l10n.marineLife_practice_done),
            ),
          ],
        ),
      ],
    );
  }

  /// A load that failed: what went wrong and a way to try again.
  Widget _failed(BuildContext context, Object error) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.marineLife_practice_title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.marineLife_speciesPage_error(error.toString()),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {
                  ref.invalidate(speciesPracticePoolProvider);
                  ref.invalidate(speciesPracticeStatesProvider);
                  ref.invalidate(seenSpeciesProvider);
                },
                child: Text(l10n.marineLife_speciesPage_retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/species');
    }
  }
}
