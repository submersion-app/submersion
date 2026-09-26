#!/usr/bin/env python3
"""Generates the query error codes from one table (#2365).

Writes:
  lib/core/query/domain/query_error_code.dart      the enum and its English text
  lib/features/query/presentation/query_error_text.dart   describeQueryError
and appends any missing query_error_<code> keys to lib/l10n/arb/app_en.arb.

The English text is the engine's message, byte for byte; the ARB's English
string is the same template, so the UI in English reads as the engine does.
Add a row here, run the script, run flutter gen-l10n, translate the new key
in the other ten locales.
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent

# (code, English template with {arg} placeholders). Args are listed in the
# order they first appear in the template.
CODES = [
    ('unterminatedQuote', 'unterminated quote'),
    ('unexpectedCharacter', 'unexpected character "{text}"'),
    ('unexpectedToken', 'unexpected "{text}"'),
    ('expectedCloseParen', 'expected ")"'),
    ('expectedCloseBracket', 'expected "]"'),
    ('expectedOpenBracketAfterIn', 'expected "[" after "in"'),
    ('expectedAnd', 'expected "and"'),
    ('expectedOperator', 'expected an operator'),
    ('expectedConditionOrText', 'expected a condition or text'),
    ('expectedName', 'expected a name'),
    ('expectedDate', 'expected a date'),
    ('expectedDateValue', 'expected a date value'),
    ('expectedValue', 'expected a value'),
    ('expectedNumber', 'expected a number'),
    ('expectedText', 'expected text'),
    ('expectedBool', 'expected true or false'),
    ('emptyText', 'empty text'),
    ('emptyList', 'the list is empty'),
    ('emptyGroup', 'an empty group matches nothing'),
    ('emptyPath', 'empty path'),
    ('notSingleDay', '"{text}" is not a single day'),
    ('notADate', '"{text}" is not a date'),
    ('openEndedDate', '"{text}" is open-ended; write {field} {symbol} {day} instead'),
    ('unknownUnit', 'unknown unit "{unit}"'),
    ('noUnitAllowed', '{field} takes no unit'),
    ('wrongUnitDimension', '"{unit}" is not a {dimension} unit'),
    ('wrongUnitForField', '"{unit}" is not a {dimension} unit; {field} is measured in {dimension}'),
    ('decimalComma', 'use "." for decimals, not ","'),
    ('scopeNeedsRelationQuoted', '"[...]" needs a relation, "{path}" is a field'),
    ('scopeNeedsRelation', '[...] needs a relation, "{path}" is a field'),
    ('relationNeedsRefOp', '"{path}" is a relation; use =, in, :none, :any or [...]'),
    ('relationOpNotAllowed', '"{op}" cannot be used with a relation; use =, !=, in, :none, :any or [...]'),
    ('opNotForFieldQuoted', '"{op}" cannot be used with {field}'),
    ('opNotForField', '{op} cannot be used with {field}'),
    ('noneAmbiguous', '"{field}:none" is ambiguous: write "{field} = none" for the value none, or "NOT {field}:any" for unrecorded'),
    ('noRefNamed', 'no {relation} named "{text}"'),
    ('notEnumValue', '"{text}" is not a {field} value'),
    ('unknownField', 'unknown field "{name}"'),
    ('fieldNotPath', '"{name}" is a field and cannot be followed by ".{next}"'),
    ('tooManyHops', 'a query may cross at most {max} relations, counting nested groups'),
    ('pathTooLong', 'a path may cross at most {max} relations'),
    ('textNotSearchable', 'free text cannot be searched inside {table}'),
    ('expectsReference', '{name} expects a reference'),
    ('expectsReferences', '{name} expects references'),
    ('betweenNeedsTwo', 'between needs two values'),
    ('inNeedsList', 'in needs a list'),
    ('expectsNumber', '{field} expects a number'),
    ('outOfRange', '{field} value is out of range'),
    ('expectsText', '{field} expects text'),
    ('expectsBool', '{field} expects true or false'),
    ('expectsEnumValue', '{field} expects one of its values'),
    ('expectsSingleDay', '{field} expects a single day here'),
    ('expectsDate', '{field} expects a date'),
]

# Quoted words that are query syntax and must stay untranslated.
SYNTAX = ['and', 'in', 'none', 'any', 'NOT', 'true', 'false', '[...]',
          'between', '=', '!=', ':none', ':any']


def args_of(template):
    seen = []
    for a in re.findall(r'\{(\w+)\}', template):
        if a not in seen:
            seen.append(a)
    return seen


def dart_string(template):
    """The template as a Dart string literal interpolating a('arg')."""
    body = template.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$')
    body = re.sub(r'\{(\w+)\}', lambda m: "${a('" + m.group(1) + "')}", body)
    return "'" + body + "'"


enum_rows = []
english_cases = []
describe_cases = []
for code, template in CODES:
    args = args_of(template)
    arg_list = ', '.join(f"'{a}'" for a in args)
    enum_rows.append(f'  {code}([{arg_list}]),')
    english_cases.append(
        f'    case QueryErrorCode.{code}:\n      return {dart_string(template)};'
    )
    if args:
        call = ', '.join(f"a('{a}')" for a in args)
        describe_cases.append(
            f'    case QueryErrorCode.{code}:\n'
            f'      return l10n.query_error_{code}({call});'
        )
    else:
        describe_cases.append(
            f'    case QueryErrorCode.{code}:\n'
            f'      return l10n.query_error_{code};'
        )
enum_rows[-1] = enum_rows[-1][:-1] + ';'

code_dart = f'''// GENERATED by scripts/gen_query_error_codes.py. Do not edit by hand.

/// Every parser, tokenizer, validator and path error (#2365). A code plus
/// the words it quotes ([argNames]) is what the UI localizes; the English
/// text below is the engine's own message.
enum QueryErrorCode {{
{chr(10).join(enum_rows)}

  const QueryErrorCode(this.argNames);

  /// The args the message quotes, in the order they appear.
  final List<String> argNames;
}}

/// The English text of [code] with [args] substituted: the engine's message
/// for logs and tests. The UI shows `describeQueryError` instead.
String englishQueryMessage(QueryErrorCode code, Map<String, String> args) {{
  String a(String name) => args[name] ?? '';
  switch (code) {{
{chr(10).join(english_cases)}
  }}
}}
'''
(ROOT / 'lib/core/query/domain/query_error_code.dart').write_text(code_dart, encoding='utf-8')

text_dart = f'''// GENERATED by scripts/gen_query_error_codes.py. Do not edit by hand.

import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// [error] in the diver's language (#2365). Exhaustive over
/// [QueryErrorCode], so a new code cannot ship without its string. The args
/// are the words the diver typed and render verbatim.
String describeQueryError(AppLocalizations l10n, QueryError error) {{
  String a(String name) => error.args[name] ?? '';
  switch (error.code) {{
{chr(10).join(describe_cases)}
  }}
}}
'''
(ROOT / 'lib/features/query/presentation/query_error_text.dart').write_text(text_dart, encoding='utf-8')

# ARB: append missing English keys, and keep every key's metadata current.
arb_path = ROOT / 'lib/l10n/arb/app_en.arb'
text = arb_path.read_text(encoding='utf-8')
existing = json.loads(text)


def dump(v):
    return json.dumps(v, ensure_ascii=False, separators=(', ', ': '))


def meta_for(template):
    args = args_of(template)
    syntax = [
        w for w in SYNTAX if f'"{w}"' in template or f' {w} ' in f' {template} '
    ]
    desc = 'Query error message.'
    if args:
        verb = 'is' if len(args) == 1 else 'are'
        desc += f' {", ".join(args)} {verb} what the diver typed; keep verbatim.'
    if syntax:
        desc += ' Query syntax, keep untranslated: ' + ' '.join(syntax) + '.'
    meta = {'description': desc}
    if args:
        meta['placeholders'] = {a: {'type': 'String'} for a in args}
    return meta


lines = []
rewritten = 0
for code, template in CODES:
    key = f'query_error_{code}'
    meta_line = f'  {dump("@" + key)}: {dump(meta_for(template))}'
    if key in existing:
        pattern = re.compile(r'^  ' + re.escape(dump('@' + key)) + r': .*?(,?)$', re.M)
        text, n = pattern.subn(lambda m: meta_line + m.group(1), text)
        rewritten += n
        continue
    lines.append(f'  {dump(key)}: {dump(template)}')
    lines.append(meta_line)
if lines:
    body = text.rstrip()
    assert body.endswith('}')
    text = body[:-1].rstrip() + ',\n' + ',\n'.join(lines) + '\n}\n'
json.loads(text)
arb_path.write_text(text, encoding='utf-8')
print(f'{len(CODES)} codes; appended {len(lines) // 2} ARB keys; '
      f'refreshed {rewritten} metadata lines')
