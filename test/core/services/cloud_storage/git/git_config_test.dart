import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';

GitConfig _config(
  String url, {
  String username = 'diver',
  String token = 'tok',
  String branch = kDefaultGitBranch,
}) => GitConfig(repoUrl: url, username: username, token: token, branch: branch);

void main() {
  group('address normalization', () {
    test('GitHub address variants all become one clone URL', () {
      for (final raw in [
        'https://github.com/you/dive-log',
        'https://GitHub.com/you/dive-log/',
        'https://www.github.com/you/dive-log.git',
        'https://github.com/you/dive-log.git/',
        '  https://github.com/you/dive-log  ',
      ]) {
        expect(
          _config(raw).cloneUrl.toString(),
          'https://github.com/you/dive-log.git',
          reason: raw,
        );
      }
    });

    test('an address on an unrecognized host is kept as typed', () {
      // Azure DevOps and CodeCommit refuse a .git suffix.
      for (final url in [
        'https://dev.azure.com/org/proj/_git/dives',
        'https://git-codecommit.us-east-1.amazonaws.com/v1/repos/dives',
      ]) {
        expect(_config(url).cloneUrl.toString(), url);
        expect(_config('$url/').cloneUrl.toString(), url);
      }
    });

    test('GitLab subgroups keep every path segment', () {
      final c = _config('https://gitlab.com/group/sub/repo');
      expect(c.cloneUrl.toString(), 'https://gitlab.com/group/sub/repo.git');
      expect(c.repoPath, 'group/sub/repo');
      expect(c.hostKind, GitHostKind.gitlab);
    });

    test('the display label is the repository path at the host', () {
      expect(
        _config('https://github.com/you/dive-log').displayLabel,
        'you/dive-log @ github.com',
      );
    });

    test('a branch other than the default is named in the label', () {
      // Two branches of one repository are two accounts.
      expect(
        GitConfig(
          repoUrl: 'https://github.com/you/dive-log',
          username: 'u',
          token: 't',
          branch: 'club',
        ).displayLabel,
        'you/dive-log @ github.com (club)',
      );
    });
  });

  group('detectGitHost', () {
    GitHostKind kind(String url) => detectGitHost(Uri.parse(url));

    test('recognises each family by its host', () {
      expect(kind('https://github.com/a/b.git'), GitHostKind.github);
      expect(kind('https://gitlab.com/a/b.git'), GitHostKind.gitlab);
      expect(kind('https://gitlab.example.org/a/b.git'), GitHostKind.gitlab);
      expect(kind('https://bitbucket.org/a/b.git'), GitHostKind.bitbucket);
      expect(kind('https://codeberg.org/a/b.git'), GitHostKind.giteaLike);
      expect(kind('https://gitea.com/a/b.git'), GitHostKind.giteaLike);
      expect(
        kind('https://git.forgejo.example/a/b.git'),
        GitHostKind.giteaLike,
      );
      expect(kind('https://git.example.net/a/b.git'), GitHostKind.other);
    });

    test('a family name inside another word is not that host', () {
      expect(kind('https://notgitlab.example/a/b'), GitHostKind.other);
      expect(kind('https://mygitea-mirror.example/a/b'), GitHostKind.other);
      expect(kind('https://forgejoish.example/a/b'), GitHostKind.other);
      // So the address is kept as typed, with no .git added.
      expect(
        GitConfig(
          repoUrl: 'https://notgitlab.example/a/b',
          username: 'u',
          token: 't',
        ).repoUrl,
        'https://notgitlab.example/a/b',
      );
    });
  });

  group('validate', () {
    test('a well-formed config is valid', () {
      expect(_config('https://github.com/you/r').validate(), isNull);
      expect(
        _config('https://github.com/you/r', branch: 'sync/dev').validate(),
        isNull,
      );
    });

    test('a pasted token is trimmed; inner whitespace is invalid', () {
      expect(
        _config('https://github.com/you/r', token: '  ghp_abc\n').token,
        'ghp_abc',
      );
      expect(
        _config('https://github.com/you/r', token: 'ghp a').validate(),
        isNotNull,
      );
    });

    test(
      'http, embedded credentials, queries and empty fields are refused',
      () {
        for (final bad in [
          _config('http://github.com/you/r'),
          _config('https://u:p@github.com/you/r'),
          _config('https://github.com/you/r?x=1'),
          _config('https://github.com'),
          _config('not a url'),
          _config('https://github.com/you/r', username: '  '),
          _config('https://github.com/you/r', token: ''),
        ]) {
          expect(bad.validate(), isNotNull, reason: bad.toString());
        }
      },
    );

    test('branch names Git would refuse are refused before any request', () {
      for (final branch in [
        '',
        'sync dev',
        'sync..dev',
        '-x',
        'refs/heads/x',
        'x/',
        '/x',
        'x.',
        'x.lock',
        'a@{b',
        'a~b',
        'a^b',
        'a:b',
        'a?b',
        'a*b',
        'a[b',
        'a\\b',
      ]) {
        expect(
          _config('https://github.com/you/r', branch: branch).validate(),
          isNotNull,
          reason: branch,
        );
      }
    });
  });

  test('problems() names every field that is wrong, in field order', () {
    final c = _config(
      'http://github.com/you/r',
      username: '',
      token: 'a b',
      branch: 'x..y',
    );
    expect(c.problems(), [
      GitConfigProblem.repoUrl,
      GitConfigProblem.username,
      GitConfigProblem.tokenSpaces,
      GitConfigProblem.branch,
    ]);
    expect(_config('https://github.com/you/r').problems(), isEmpty);
    expect(_config('https://u:p@github.com/you/r').problems(), [
      GitConfigProblem.credentialsInUrl,
    ]);
  });

  group('serialization', () {
    test('JSON round-trips and toString never shows the token', () {
      final c = GitConfig(
        repoUrl: 'https://github.com/you/dive-log',
        username: 'you',
        token: 'ghp_secret',
        branch: 'submersion-sync',
        pinnedCertSha256: 'AB12',
      );
      final back = GitConfig.fromJson(c.toJson());
      expect(back.cloneUrl, c.cloneUrl);
      expect(back.username, 'you');
      expect(back.token, 'ghp_secret');
      expect(back.branch, 'submersion-sync');
      expect(back.pinnedCertSha256, 'ab12');
      expect(c.toString(), isNot(contains('ghp_secret')));
    });

    test('copyWith keeps the other fields', () {
      final c = _config('https://github.com/you/r').copyWith(branch: 'other');
      expect(c.branch, 'other');
      expect(c.cloneUrl.toString(), 'https://github.com/you/r.git');
    });

    test('a corrupt blob decodes to null', () {
      expect(decodeGitConfig(null), isNull);
      expect(decodeGitConfig('{not json'), isNull);
      expect(decodeGitConfig('{"repoUrl": 3}'), isNull);
      expect(decodeGitConfig('[]'), isNull);
    });
  });

  test('the account identity changes with the branch', () {
    final a = _config('https://github.com/you/r');
    expect(
      gitNaturalKey(a),
      gitNaturalKey(_config('https://github.com/you/r/')),
    );
    expect(gitNaturalKey(a), isNot(gitNaturalKey(a.copyWith(branch: 'other'))));
  });

  test('plain http is refused even on loopback unless explicitly allowed', () {
    final c = _config('http://127.0.0.1:8080/r');
    expect(c.problems(), contains(GitConfigProblem.repoUrl));
    expect(c.validate(), isNotNull);
    expect(c.problems(allowLoopbackHttp: true), isEmpty);
    expect(
      _config('http://github.com/you/r').problems(allowLoopbackHttp: true),
      contains(GitConfigProblem.repoUrl),
    );
  });
}
