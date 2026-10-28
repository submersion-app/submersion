/// The Submersion nearby service, advertised with no name and no data:
/// who a device is comes out only after connecting, in the hello.
const nearbyServiceUuid = '6e2f8a40-93b1-4c52-8d7e-0c3a5b1d9e01';

/// The central writes its byte stream here.
const nearbyInboxUuid = '6e2f8a40-93b1-4c52-8d7e-0c3a5b1d9e02';

/// The peripheral's byte stream, served to the central's reads; a one-byte
/// notification here only says bytes are waiting.
const nearbyOutboxUuid = '6e2f8a40-93b1-4c52-8d7e-0c3a5b1d9e03';
