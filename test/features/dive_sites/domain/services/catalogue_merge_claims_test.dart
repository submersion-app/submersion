import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_merge_claims.dart';

DiveSite _site(
  String id, {
  String? link,
  SiteCatalogueAnswers answers = SiteCatalogueAnswers.empty,
}) => DiveSite(id: id, name: id, catalogueId: link, catalogueAnswers: answers);

void main() {
  test('the survivor keeps its link and stands for the others', () {
    final claims = mergedCatalogueClaims(
      survivor: _site('s', link: 'r1'),
      mergedAway: [
        _site('a', link: 'r2'),
        _site('b', link: 'r3'),
      ],
    );

    expect(claims.link, 'r1');
    expect(claims.answers.also, {'r2', 'r3'});
  });

  test('an unlinked survivor takes the first link in merge order', () {
    final claims = mergedCatalogueClaims(
      survivor: _site('s'),
      mergedAway: [
        _site('a'),
        _site('b', link: 'r2'),
        _site('c', link: 'r3'),
      ],
    );

    expect(claims.link, 'r2');
    expect(claims.answers.also, {'r3'});
  });

  test('two sites adopted from one record leave nothing to stand for', () {
    final claims = mergedCatalogueClaims(
      survivor: _site('s', link: 'r1'),
      mergedAway: [_site('a', link: 'r1')],
    );

    expect(claims.link, 'r1');
    expect(claims.answers, SiteCatalogueAnswers.empty);
  });

  test('what a merged site stood for carries over', () {
    final claims = mergedCatalogueClaims(
      survivor: _site('s', link: 'r1'),
      mergedAway: [
        _site(
          'a',
          link: 'r2',
          answers: const SiteCatalogueAnswers(also: {'r6'}),
        ),
      ],
    );

    expect(claims.answers.also, {'r2', 'r6'});
  });

  test('a record now claimed is no longer one the site is not', () {
    final claims = mergedCatalogueClaims(
      survivor: _site(
        's',
        link: 'r1',
        answers: const SiteCatalogueAnswers(notSame: {'r2', 'r7'}),
      ),
      mergedAway: [
        _site(
          'a',
          link: 'r2',
          answers: const SiteCatalogueAnswers(notSame: {'r1', 'r8'}),
        ),
      ],
    );

    expect(claims.answers.notSame, {'r7', 'r8'});
  });

  test('details turned down are kept for the surviving link only', () {
    final claims = mergedCatalogueClaims(
      survivor: _site(
        's',
        link: 'r1',
        answers: const SiteCatalogueAnswers(
          declined: {
            'r1': {'depth'},
            'r9': {'entry'},
          },
        ),
      ),
      mergedAway: [
        _site(
          'a',
          link: 'r2',
          answers: const SiteCatalogueAnswers(
            declined: {
              'r2': {'entry'},
            },
          ),
        ),
      ],
    );

    expect(claims.answers.declined, {
      'r1': {'depth'},
    });
  });

  test('keys a newer build wrote on a merged site are carried over', () {
    final claims = mergedCatalogueClaims(
      survivor: _site(
        's',
        link: 'r1',
        answers: SiteCatalogueAnswers.decode('{"later":1,"both":"mine"}'),
      ),
      mergedAway: [
        _site(
          'a',
          answers: SiteCatalogueAnswers.decode(
            '{"both":"theirs","seen":["x"]}',
          ),
        ),
        _site(
          'b',
          answers: SiteCatalogueAnswers.decode('{"seen":["y"],"more":true}'),
        ),
      ],
    );

    // The survivor's own value wins a key both hold, then the first merged
    // site's: what such a key means is not known here, so none is blended.
    expect(claims.answers.unknown, {
      'later': 1,
      'both': 'mine',
      'seen': ['x'],
      'more': true,
    });
  });

  test('sites that claim nothing merge to nothing', () {
    final claims = mergedCatalogueClaims(
      survivor: _site('s'),
      mergedAway: [_site('a')],
    );

    expect(claims.link, isNull);
    expect(claims.answers, SiteCatalogueAnswers.empty);
  });
}
