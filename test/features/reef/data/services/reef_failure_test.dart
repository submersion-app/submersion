import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/features/reef/data/services/reef_failure.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';

/// Which failed requests may be saved as a failure.
void main() {
  test('a request that got no answer is unanswered', () {
    // What package:http throws offline, on every platform's client.
    final part = reefFailure<int>(
      http.ClientException('Failed host lookup', Uri.parse('https://x.test')),
    );
    expect(part.status, ReefDataStatus.unavailable);
    expect(part.unanswered, isTrue);
  });

  test('a request that ran out of time is a failure like any other', () {
    // A slow server is still the source's state: its failure spaces out
    // the next try.
    final part = reefFailure<int>(TimeoutException('slow'));
    expect(part.status, ReefDataStatus.unavailable);
    expect(part.unanswered, isFalse);
  });

  test('a reply that could not be read is a failure like any other', () {
    expect(reefFailure<int>(const FormatException('bad')).unanswered, isFalse);
  });

  test('a failure the server answered is not unanswered', () {
    expect(const ReefPart<int>.unavailable().unanswered, isFalse);
  });
}
