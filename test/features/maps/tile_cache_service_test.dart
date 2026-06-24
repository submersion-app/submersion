import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';

// FMTCBrowsingError's constructor is annotated @internal for the FMTC package;
// it is constructed directly here only to drive the error handler in isolation.
// ignore_for_file: invalid_use_of_internal_member

void main() {
  group('TileCacheService.handleTileError', () {
    // Returns the next LogEntry emitted on the shared logger stream while
    // [action] runs. The subscription is established before [action] so the
    // handler's synchronous emission is captured.
    Future<LogEntry> logFrom(void Function() action) {
      final next = LoggerService.logStream.first;
      action();
      return next;
    }

    test('returns null so a failed tile renders blank instead of throwing', () {
      final result = TileCacheService.handleTileError(
        FMTCBrowsingError(
          type: FMTCBrowsingErrorType.noConnectionDuringFetch,
          networkUrl: 'https://tile.example/0/0/0.png',
          storageSuitableUID: 'uid',
        ),
      );

      expect(result, isNull);
    });

    test('logs an offline cache miss at info with the type and url', () async {
      final entry = await logFrom(() {
        TileCacheService.handleTileError(
          FMTCBrowsingError(
            type: FMTCBrowsingErrorType.noConnectionDuringFetch,
            networkUrl: 'https://tile.example/4/5/6.png',
            storageSuitableUID: 'uid',
          ),
        );
      });

      expect(entry.level, LogLevel.info);
      expect(
        entry.message,
        allOf(
          contains('Tile load failed [noConnectionDuringFetch]'),
          contains('url=https://tile.example/4/5/6.png'),
        ),
      );
    });

    test(
      'logs a non-200 response at warning with status and content type',
      () async {
        final entry = await logFrom(() {
          TileCacheService.handleTileError(
            FMTCBrowsingError(
              type: FMTCBrowsingErrorType.negativeFetchResponse,
              networkUrl: 'https://tile.openstreetmap.org/1/2/3.png',
              storageSuitableUID: 'uid',
              response: http.Response(
                'blocked',
                418,
                headers: const {'content-type': 'text/html'},
              ),
            ),
          );
        });

        expect(entry.level, LogLevel.warning);
        expect(
          entry.message,
          allOf(
            contains('httpStatus=418'),
            contains('contentType=text/html'),
            contains('bodyBytes=7'), // 'blocked' is 7 bytes
          ),
        );
      },
    );

    test(
      'logs an unexpected transport error at warning with the cause',
      () async {
        final entry = await logFrom(() {
          TileCacheService.handleTileError(
            FMTCBrowsingError(
              type: FMTCBrowsingErrorType.unknownFetchException,
              networkUrl: 'https://tile.openstreetmap.org/7/8/9.png',
              storageSuitableUID: 'uid',
              originalError: const FormatException('handshake boom'),
            ),
          );
        });

        expect(entry.level, LogLevel.warning);
        expect(
          entry.message,
          allOf(contains('cause=FormatException'), contains('handshake boom')),
        );
      },
    );

    test('never rethrows when the cause toString throws', () async {
      Object? result;
      final entry = await logFrom(() {
        result = TileCacheService.handleTileError(
          FMTCBrowsingError(
            type: FMTCBrowsingErrorType.unknownFetchException,
            networkUrl: 'https://tile.example/1/1/1.png',
            storageSuitableUID: 'uid',
            originalError: _ThrowingToString(),
          ),
        );
      });

      expect(result, isNull); // handler degraded instead of propagating
      expect(entry.level, LogLevel.warning);
      expect(entry.message, contains('cause=_ThrowingToString'));
    });
  });
}

/// A cause whose `toString` throws, used to verify
/// [TileCacheService.handleTileError] degrades safely rather than letting the
/// error escape the handler.
class _ThrowingToString {
  @override
  String toString() => throw StateError('toString boom');
}
