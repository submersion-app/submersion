import 'package:http/http.dart' as http;

import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';

/// The part a reef-data request that threw [error] reports.
///
/// A request that got no answer at all is [ReefPart.unanswered]: package:http
/// throws a [http.ClientException] on every platform's client when there is
/// no network, the host cannot be found, or the connection drops. Saving
/// that as a failure would keep "could not fetch" for the next hour after
/// the device is back online, though it says nothing about the source.
///
/// Anything else is a failure like a server's reply: a timeout (the source
/// is slow) or a reply that could not be read. Those are saved, so the next
/// try is spaced out.
ReefPart<T> reefFailure<T>(Object error) =>
    ReefPart<T>.unavailable(unanswered: gotNoAnswer(error));

/// Whether a request that threw [error] got no reply at all, as
/// [reefFailure] reads it.
bool gotNoAnswer(Object error) => error is http.ClientException;
