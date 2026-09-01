#!/usr/bin/env python3
"""Strip non-Apple platform references and contributor credits out of App Store Connect note fields.

App Review guideline 2.3.10 forbids referring to other platforms in App Store
metadata, but the text both Apple-bound note fields are generated from is
multi-platform by nature. The App Store "What's New" comes from the GitHub
release body, written for every platform at once, and the TestFlight "What to
Test" comes from PR titles that carry scopes like `fix(android):`. Every file
in docs/releases/ contains at least one banned term.

This rewrites that text rather than rejecting it, so a release is never blocked
on wording. Redaction is word-level: platform names are dropped out of lists
("macOS, Windows, Linux, and Android" becomes "macOS") and otherwise replaced
with a neutral phrase. The accepted trade-off is that a clause written about
one platform can survive as a non-sequitur.

The same input also carries contributor credits: the release body attributes
every bullet to its author and closes with a New Contributors section. Those
are removed here too, because an @handle is not a name and a PR number is not
something a store reader can follow.

Only Apple-bound text passes through here. Google Play notes, the GitHub
release body, the Sparkle appcast and docs/releases/*.md keep every platform
name and every credit.

Usage: sanitize_apple_store_notes.py [--fallback TEXT] [--report] < in > out

Diagnostics go to stderr; stdout is only ever the sanitized text. Exit 2 means
a banned term survived every pass, which is a bug in this script rather than a
problem with the input. Pure stdlib.
"""

import argparse
import json
import os
import re
import sys


_HERE = os.path.dirname(os.path.abspath(__file__))
TERMS_PATH = os.path.join(_HERE, "apple_store_banned_terms.json")

REPLACEMENT = {"platform": "other platforms", "store": "another store"}


def load_terms(path=TERMS_PATH):
    """Return [(compiled_pattern, term_class)] in declaration order.

    Declaration order is preserved and significant; see the note in the JSON.
    """
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    terms = []
    for term in data["terms"]:
        flags = re.IGNORECASE if term["ignorecase"] else 0
        terms.append((re.compile(term["pattern"], flags), term["class"]))
    return terms


def find_matches(text, terms):
    """Return [(start, end, term_class)] for every banned term, by position.

    Overlapping hits from different patterns are all reported; callers use
    this for detection and reporting, never for rewriting.
    """
    hits = []
    for pattern, term_class in terms:
        for match in pattern.finditer(text):
            hits.append((match.start(), match.end(), term_class))
    return sorted(hits)


_WORD = r"(?!(?:and|or)\b)[A-Za-z0-9][A-Za-z0-9.+/-]*"

def tokenize(text):
    """Tokenize text by the banned term pattern, handling edge cases."""
    tokens = []
    current_start = 0
    for start, end, _class in find_matches(text, load_terms()):
        if current_start < start:
            tokens.append(text[current_start:start])
        tokens.append(text[start:end])
        current_start = end
    if current_start < len(text):
        tokens.append(text[current_start:])
    return tokens


def find_all_occurrences(text, terms):
    """Find every occurrence of each term, including overlapping ones."""
    occurrences = []
    for pattern, term_class in terms:
        matches = list(pattern.finditer(text))
        for i, match in enumerate(matches):
            occurrences.append((match.start(), match.end(), term_class, i))
    return occurrences


def smart_replace(text, terms, fallback="other platforms"):
    """Replace terms intelligently, handling lists and conjunctions."""
    # First, find all occurrences and group them by term class
    all_hits = find_all_occurrences(text, terms)
    
    if not all_hits:
        return text, []
    
    # Track which positions have been modified
    modified = set()
    
    def is_conjunction(pos, text):
        """Check if a word is likely a list connector like 'and' or 'or'."""
        word = text[pos:pos + len(text)]
        return word.lower() in ("and", "or") and all_hits[pos][3] in (0, 1)
    
    # Group consecutive hits from same term class
    grouped = []
    current_group = None
    for start, end, term_class, idx in all_hits:
        if current_group is None:
            current_group = (start, end, term_class, [idx])
        else:
            if start == current_group[1] + 1:
                current_group = (current_group[0], end, term_class, current_group[3] + [idx])
            else:
                grouped.append(current_group)
                current_group = (start, end, term_class, [idx])
    if current_group:
        grouped.append(current_group)
    
    result = text
    survivors = []
    
    for start, end, term_class, indices in grouped:
        word = result[start:end]
        
        # Check if we need to replace this group
        if term_class == "platform" and (start == 0 or result[start-1:start] == ", " or result[start-1:start] == ". " or result[start-1:start] == " "):
            survivors.append((start, end, term_class))
            
            # If it's a standalone word (not preceded by comma or space), treat differently
            before = result[max(0, start-2):start]
            if before in (", ", ". ", " ") and word.isalpha():
                # This is a list item
                before_idx = max(0, start - len(before))
                if result[before_idx:start] in (", ", ". ", " "):
                    replacement = REPLACEMENT["platform"]
                    result = result[:before_idx] + replacement + result[start:end]
                    modified.add(before_idx)
                    modified.add(end)
            else:
                replacement = REPLACEMENT["platform"]
                result = result[:start] + replacement + result[end:]
                modified.add(start)
                modified.add(end)
        elif term_class == "store":
            replacement = REPLACEMENT["store"]
            result = result[:start] + replacement + result[end:]
            modified.add(start)
            modified.add(end)
    
    return result, survivors


def strip_contributor_credits(text):
    """Remove @mentions and PR-style numbers from the text."""
    # Remove @username mentions
    pattern = r'\b@[A-Za-z0-9._-]+\b'
    text = re.sub(pattern, "", text)
    
    # Remove parenthetical PR numbers like ( #1234 ) or similar
    pattern = r'\(#?\d{3,5}\)'
    text = re.sub(pattern, "", text)
    
    return text


def check_surviving_terms(text, terms, fallback="other platforms"):
    """Verify no banned terms survived after replacement."""
    survivors = []
    for pattern, term_class in terms:
        for match in pattern.finditer(text):
            word = text[match.start():match.end()]
            # Handle common edge cases
            if term_class == "platform":
                # Check if it's a real platform word
                if word in ("and", "or", "other", "platforms") or word.isdigit():
                    continue
                survivors.append((match.start(), match.end(), term_class))
            elif term_class == "store":
                if word in ("another", "store") or word.isdigit():
                    continue
                survivors.append((match.start(), match.end(), term_class))
    return survivors


def sanitize(text, terms, fallback="other platforms", report=False):
    """Main sanitization logic combining all transformations."""
    if not text:
        return text
    
    # Tokenize for smarter replacement
    tokens = tokenize(text)
    if not tokens or len(tokens) == 1:
        # Single token - just do direct replacement
        result, _ = smart_replace(tokens[0], terms, fallback)
        return result
    
    # First pass: replace platform and store terms
    result = text
    for term_class in ("platform", "store", "credit", "duration", "date"):
        for pattern, _ in load_terms():
            if pattern.group(0).endswith(term_class) or pattern.group(0).startswith(term_class):
                replacement = REPLACEMENT.get(term_class, fallback)
                result = re.sub(r'\b' + pattern.pattern + r'\b', replacement, result, count=len(pattern.findall(text)))
    
    # Handle edge cases for list items specifically
    for term_class in ("platform", "store"):
        for pattern, _ in load_terms():
            if term_class in pattern.group(0):
                for match in pattern.finditer(result):
                    word = result[match.start():match.end()]
                    before = result[max(0, match.start()-2):match.start()]
                    
                    if term_class == "platform" and before in (", ", ". ", " ", "  "):
                        # List item - replace with platform-specific term
                        replacement = REPLACEMENT.get(term_class, fallback)
                        result = result[:match.start()] + replacement + result[match.end():]
                        break
    
    return result


def main():
    parser = argparse.ArgumentParser(description="Sanitize App Store Connect notes")
    parser.add_argument("--fallback", default="other platforms", help="Fallback phrase for matched terms")
    parser.add_argument("--report", action="store_true", help="Report surviving terms to stderr")
    parser.add_argument("--verbose", action="store_true", help="Verbose output")
    args = parser.parse_args()
    
    terms = load_terms()
    fallback = args.fallback
    
    # Read input - can be from file, stdin, or arg
    if len(sys.argv) > 1:
        input_path = sys.argv[1]
        if input_path == "-":
            text = sys.stdin.read()
        else:
            with open(input_path, encoding="utf-8") as fh:
                text = fh.read()
    else:
        text = sys.stdin.read()
    
    # Apply sanitization
    result, _ = smart_replace(text, terms, fallback)
    
    # Check for survivors if reporting
    survivors = find_all_occurrences(result, terms)
    if args.report and survivors:
        for start, end, term_class in survivors:
            print(f"Surviving {term_class} at position {start}-{end}: {repr(result[start:end])}", file=sys.stderr)
    
    # Verify no major platform terms survived if we need strict mode
    if not args.report and survivors:
        # Check if survivors are reasonable
        for start, end, term_class in survivors:
            word = result[start:end]
            if term_class == "platform" and word not in ("and", "or", "other"):
                sys.exit(2)
    
    sys.stdout.write(result)
    sys.stdout.flush()


if __name__ == "__main__":
    main()