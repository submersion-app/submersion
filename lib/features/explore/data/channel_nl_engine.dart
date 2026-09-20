import 'package:flutter/services.dart';
import 'package:submersion_nl/submersion_nl.dart';

import 'package:submersion/features/explore/domain/nl_engine.dart';

/// [NlEngine] over the `submersion_nl` method channel.
class ChannelNlEngine implements NlEngine {
  @override
  Future<NlAvailability> availability(String localeTag) async {
    try {
      final raw = await SubmersionNl.availability(localeTag);
      return NlAvailability.values.firstWhere(
        (a) => a.name == raw,
        orElse: () => NlAvailability.modelNotReady,
      );
    } on MissingPluginException {
      return NlAvailability.unsupportedPlatform;
    } on PlatformException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> prepare() async {
    try {
      await SubmersionNl.prepare(
        NlPrompt.instructions(),
        NlPrompt.vocabulary(),
      );
    } on MissingPluginException {
      // Nothing to warm on a platform without an adapter.
    } on PlatformException catch (e) {
      throw _map(e);
    }
  }

  @override
  Stream<double> download() => SubmersionNl.download();

  @override
  Future<String> compile(String sentence, {required String localeTag}) async {
    try {
      return await SubmersionNl.compile(sentence, localeTag);
    } on MissingPluginException {
      throw const NlException(NlError.unknown, 'no adapter on this platform');
    } on PlatformException catch (e) {
      throw _map(e);
    }
  }

  static NlException _map(PlatformException e) {
    final error = switch (e.code) {
      'unsupported_locale' => NlError.unsupportedLocale,
      'context_exceeded' => NlError.contextExceeded,
      'guardrail' => NlError.guardrail,
      'refusal' => NlError.refusal,
      'decoding_failure' => NlError.decodingFailure,
      'model_not_ready' => NlError.modelNotReady,
      'quota_exceeded' => NlError.quotaExceeded,
      'schema_mismatch' => NlError.schemaMismatch,
      _ => NlError.unknown,
    };
    return NlException(error, e.message);
  }
}
