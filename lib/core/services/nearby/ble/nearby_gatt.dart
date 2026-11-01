/// The Submersion nearby service, advertised with no name and no data:
/// who a device is comes out only after connecting, in the hello.
const nearbyServiceUuid = '6e2f8a40-93b1-4c52-8d7e-0c3a5b1d9e01';

/// The central writes its byte stream here.
const nearbyInboxUuid = '6e2f8a40-93b1-4c52-8d7e-0c3a5b1d9e02';

/// The peripheral's byte stream, served to the central's reads.
const nearbyOutboxUuid = '6e2f8a40-93b1-4c52-8d7e-0c3a5b1d9e03';

/// A one-byte notification here says bytes are waiting in the outbox. It is
/// not the outbox: Apple reports read answers and notifications through one
/// callback, so a notification on a characteristic being read is taken for
/// the read's answer, and every read answer rings like a notification.
const nearbyDoorbellUuid = '6e2f8a40-93b1-4c52-8d7e-0c3a5b1d9e04';
