package com.submersion.libdivecomputer;

import com.submersion.libdivecomputer.IDiveDownloadCallback;
import com.submersion.libdivecomputer.SerialDownloadRequest;

interface IDiveDownloadService {
    void startSerialDownload(in SerialDownloadRequest request, IDiveDownloadCallback callback);
    void cancel();
}
