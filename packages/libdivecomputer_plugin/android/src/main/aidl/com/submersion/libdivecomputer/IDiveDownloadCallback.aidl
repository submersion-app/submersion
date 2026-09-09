package com.submersion.libdivecomputer;

// Called by :dc back into the main process as the download proceeds. `oneway`
// so the child never blocks on the main process, and a dead main-process
// binder can't wedge the child.
oneway interface IDiveDownloadCallback {
    void onProgress(int current, int max);
    void onDive(in byte[] pigeonEncodedDive);   // ParsedDive via DiveMarshaling
    void onError(String code, String message);
    // Strings are nullable: null serial/firmware when the device reported
    // none, null clockSyncStatus when no sync was requested (issue #1216).
    void onComplete(long totalDives, String serialNumber, String firmwareVersion, String clockSyncStatus);
}
