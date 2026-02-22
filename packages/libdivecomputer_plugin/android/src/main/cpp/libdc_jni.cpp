// JNI bridge between Kotlin and the libdivecomputer C wrapper.
// Exposes libdc_wrapper functions to Kotlin via JNI.

#include <jni.h>
#include <cstdio>
#include <cstring>
#include <android/log.h>

extern "C" {
#include "libdc_wrapper.h"
}

#define TAG "libdc_jni"

// ============================================================
// Version
// ============================================================

extern "C" JNIEXPORT jstring JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetVersion(
    JNIEnv *env, jclass) {
    const char *version = libdc_get_version();
    return env->NewStringUTF(version ? version : "unknown");
}

// ============================================================
// Descriptor Iterator
// ============================================================

extern "C" JNIEXPORT jlong JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeDescriptorIteratorNew(
    JNIEnv *, jclass) {
    return reinterpret_cast<jlong>(libdc_descriptor_iterator_new());
}

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeDescriptorIteratorNext(
    JNIEnv *env, jclass, jlong iterPtr, jobject infoObj) {
    auto *iter = reinterpret_cast<libdc_descriptor_iterator_t *>(iterPtr);
    libdc_descriptor_info_t info;
    int result = libdc_descriptor_iterator_next(iter, &info);
    if (result != 0) return result;

    // Set fields on the Java DescriptorInfo object.
    jclass cls = env->GetObjectClass(infoObj);
    env->SetObjectField(infoObj,
        env->GetFieldID(cls, "vendor", "Ljava/lang/String;"),
        env->NewStringUTF(info.vendor ? info.vendor : ""));
    env->SetObjectField(infoObj,
        env->GetFieldID(cls, "product", "Ljava/lang/String;"),
        env->NewStringUTF(info.product ? info.product : ""));
    env->SetIntField(infoObj,
        env->GetFieldID(cls, "model", "I"),
        static_cast<jint>(info.model));
    env->SetIntField(infoObj,
        env->GetFieldID(cls, "transports", "I"),
        static_cast<jint>(info.transports));

    return 0;
}

extern "C" JNIEXPORT void JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeDescriptorIteratorFree(
    JNIEnv *, jclass, jlong iterPtr) {
    auto *iter = reinterpret_cast<libdc_descriptor_iterator_t *>(iterPtr);
    libdc_descriptor_iterator_free(iter);
}

// ============================================================
// BLE Discovery Helper
// ============================================================

extern "C" JNIEXPORT jboolean JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeDescriptorMatch(
    JNIEnv *env, jclass, jstring name, jint transport, jobject infoObj) {
    const char *nameStr = env->GetStringUTFChars(name, nullptr);
    libdc_descriptor_info_t info;
    int matched = libdc_descriptor_match(nameStr, static_cast<unsigned int>(transport), &info);
    env->ReleaseStringUTFChars(name, nameStr);

    if (!matched) return JNI_FALSE;

    jclass cls = env->GetObjectClass(infoObj);
    env->SetObjectField(infoObj,
        env->GetFieldID(cls, "vendor", "Ljava/lang/String;"),
        env->NewStringUTF(info.vendor ? info.vendor : ""));
    env->SetObjectField(infoObj,
        env->GetFieldID(cls, "product", "Ljava/lang/String;"),
        env->NewStringUTF(info.product ? info.product : ""));
    env->SetIntField(infoObj,
        env->GetFieldID(cls, "model", "I"),
        static_cast<jint>(info.model));
    env->SetIntField(infoObj,
        env->GetFieldID(cls, "transports", "I"),
        static_cast<jint>(info.transports));

    return JNI_TRUE;
}

// ============================================================
// Download Session
// ============================================================

extern "C" JNIEXPORT jlong JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeDownloadSessionNew(
    JNIEnv *, jclass) {
    return reinterpret_cast<jlong>(libdc_download_session_new());
}

extern "C" JNIEXPORT void JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeDownloadCancel(
    JNIEnv *, jclass, jlong sessionPtr) {
    auto *session = reinterpret_cast<libdc_download_session_t *>(sessionPtr);
    libdc_download_cancel(session);
}

extern "C" JNIEXPORT void JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeDownloadSessionFree(
    JNIEnv *, jclass, jlong sessionPtr) {
    auto *session = reinterpret_cast<libdc_download_session_t *>(sessionPtr);
    libdc_download_session_free(session);
}

// Structs for passing callback context through JNI.
struct JniDownloadContext {
    JavaVM *jvm;
    jobject callback;  // Global ref to Kotlin callback object
};

static void jni_on_progress(unsigned int current, unsigned int maximum, void *userdata) {
    auto *ctx = static_cast<JniDownloadContext *>(userdata);
    JNIEnv *env;
    bool attached = false;
    if (ctx->jvm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        ctx->jvm->AttachCurrentThread(&env, nullptr);
        attached = true;
    }

    jclass cls = env->GetObjectClass(ctx->callback);
    jmethodID method = env->GetMethodID(cls, "onProgress", "(II)V");
    if (method) {
        env->CallVoidMethod(ctx->callback, method,
            static_cast<jint>(current), static_cast<jint>(maximum));
    }

    if (attached) ctx->jvm->DetachCurrentThread();
}

static void jni_on_dive(const libdc_parsed_dive_t *dive, void *userdata) {
    auto *ctx = static_cast<JniDownloadContext *>(userdata);
    JNIEnv *env;
    bool attached = false;
    if (ctx->jvm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        ctx->jvm->AttachCurrentThread(&env, nullptr);
        attached = true;
    }

    jclass cls = env->GetObjectClass(ctx->callback);
    jmethodID method = env->GetMethodID(cls, "onDive", "(J)V");
    if (method) {
        // Pass the dive pointer so Kotlin can read fields via additional JNI calls.
        env->CallVoidMethod(ctx->callback, method,
            reinterpret_cast<jlong>(dive));
    }

    if (attached) ctx->jvm->DetachCurrentThread();
}

// I/O callback bridge from C to Kotlin (for BLE).
struct JniIoContext {
    JavaVM *jvm;
    jobject ioHandler;  // Global ref to Kotlin BleIoHandler
    int timeout_ms;
};

static int jni_io_set_timeout(void *userdata, int timeout) {
    auto *ctx = static_cast<JniIoContext *>(userdata);
    ctx->timeout_ms = timeout < 0 ? -1 : timeout;
    return LIBDC_STATUS_SUCCESS;
}

static int jni_io_read(void *userdata, void *data, size_t size, size_t *actual) {
    auto *ctx = static_cast<JniIoContext *>(userdata);
    JNIEnv *env;
    bool attached = false;
    if (ctx->jvm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        ctx->jvm->AttachCurrentThread(&env, nullptr);
        attached = true;
    }

    jclass cls = env->GetObjectClass(ctx->ioHandler);
    jmethodID method = env->GetMethodID(cls, "read", "(II)[B");
    if (!method) {
        if (attached) ctx->jvm->DetachCurrentThread();
        return LIBDC_STATUS_IO;
    }

    auto result = static_cast<jbyteArray>(
        env->CallObjectMethod(ctx->ioHandler, method,
            static_cast<jint>(size), static_cast<jint>(ctx->timeout_ms)));

    if (!result) {
        *actual = 0;
        if (attached) ctx->jvm->DetachCurrentThread();
        return LIBDC_STATUS_TIMEOUT;
    }

    jsize len = env->GetArrayLength(result);
    env->GetByteArrayRegion(result, 0, len, static_cast<jbyte *>(data));
    *actual = static_cast<size_t>(len);

    if (attached) ctx->jvm->DetachCurrentThread();
    return LIBDC_STATUS_SUCCESS;
}

static int jni_io_write(void *userdata, const void *data, size_t size, size_t *actual) {
    auto *ctx = static_cast<JniIoContext *>(userdata);
    JNIEnv *env;
    bool attached = false;
    if (ctx->jvm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        ctx->jvm->AttachCurrentThread(&env, nullptr);
        attached = true;
    }

    jclass cls = env->GetObjectClass(ctx->ioHandler);
    jmethodID method = env->GetMethodID(cls, "write", "([BI)I");
    if (!method) {
        if (attached) ctx->jvm->DetachCurrentThread();
        return LIBDC_STATUS_IO;
    }

    jbyteArray arr = env->NewByteArray(static_cast<jint>(size));
    env->SetByteArrayRegion(arr, 0, static_cast<jint>(size),
        static_cast<const jbyte *>(data));

    jint result = env->CallIntMethod(ctx->ioHandler, method, arr,
        static_cast<jint>(ctx->timeout_ms));

    if (result < 0) {
        *actual = 0;
        if (attached) ctx->jvm->DetachCurrentThread();
        return LIBDC_STATUS_IO;
    }

    *actual = size;
    if (attached) ctx->jvm->DetachCurrentThread();
    return LIBDC_STATUS_SUCCESS;
}

static int jni_io_close(void *userdata) {
    auto *ctx = static_cast<JniIoContext *>(userdata);
    JNIEnv *env;
    bool attached = false;
    if (ctx->jvm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        ctx->jvm->AttachCurrentThread(&env, nullptr);
        attached = true;
    }

    jclass cls = env->GetObjectClass(ctx->ioHandler);
    jmethodID method = env->GetMethodID(cls, "close", "()V");
    if (method) {
        env->CallVoidMethod(ctx->ioHandler, method);
    }

    if (attached) ctx->jvm->DetachCurrentThread();
    return LIBDC_STATUS_SUCCESS;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeDownloadRun(
    JNIEnv *env, jclass,
    jlong sessionPtr,
    jstring vendor, jstring product, jint model, jint transport,
    jobject ioHandler,
    jobject downloadCallback,
    jbyteArray errorBuf) {

    auto *session = reinterpret_cast<libdc_download_session_t *>(sessionPtr);

    const char *vendorStr = env->GetStringUTFChars(vendor, nullptr);
    const char *productStr = env->GetStringUTFChars(product, nullptr);

    // Set up I/O callbacks via JNI bridge.
    JavaVM *jvm;
    env->GetJavaVM(&jvm);

    JniIoContext ioCtx;
    ioCtx.jvm = jvm;
    ioCtx.ioHandler = env->NewGlobalRef(ioHandler);
    ioCtx.timeout_ms = 10000;

    libdc_io_callbacks_t io_callbacks;
    memset(&io_callbacks, 0, sizeof(io_callbacks));
    io_callbacks.set_timeout = jni_io_set_timeout;
    io_callbacks.read = jni_io_read;
    io_callbacks.write = jni_io_write;
    io_callbacks.close = jni_io_close;
    io_callbacks.userdata = &ioCtx;

    // Set up download callbacks.
    JniDownloadContext dlCtx;
    dlCtx.jvm = jvm;
    dlCtx.callback = env->NewGlobalRef(downloadCallback);

    libdc_download_callbacks_t dl_callbacks;
    memset(&dl_callbacks, 0, sizeof(dl_callbacks));
    dl_callbacks.on_progress = jni_on_progress;
    dl_callbacks.on_dive = jni_on_dive;
    dl_callbacks.userdata = &dlCtx;

    // Run the download.
    char error_buf[256] = {0};
    int result = libdc_download_run(
        session,
        vendorStr, productStr,
        static_cast<unsigned int>(model),
        static_cast<unsigned int>(transport),
        &io_callbacks,
        nullptr, 0,  // No fingerprint
        &dl_callbacks,
        nullptr, nullptr,  // serial_out, firmware_out (not yet wired on Android)
        error_buf, sizeof(error_buf));

    // Copy error message to output buffer.
    if (errorBuf && error_buf[0]) {
        jsize len = env->GetArrayLength(errorBuf);
        jsize msgLen = static_cast<jsize>(strlen(error_buf));
        if (msgLen > len) msgLen = len;
        env->SetByteArrayRegion(errorBuf, 0, msgLen,
            reinterpret_cast<const jbyte *>(error_buf));
    }

    // Cleanup.
    env->ReleaseStringUTFChars(vendor, vendorStr);
    env->ReleaseStringUTFChars(product, productStr);
    env->DeleteGlobalRef(ioCtx.ioHandler);
    env->DeleteGlobalRef(dlCtx.callback);

    return result;
}

// ============================================================
// Dive Data Access (for reading parsed dive fields from Kotlin)
// ============================================================

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveYear(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->year;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveMonth(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->month;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveDay(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->day;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveHour(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->hour;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveMinute(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->minute;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveSecond(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->second;
}

extern "C" JNIEXPORT jdouble JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveMaxDepth(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->max_depth;
}

extern "C" JNIEXPORT jdouble JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveAvgDepth(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->avg_depth;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveDuration(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return static_cast<jint>(dive->duration);
}

extern "C" JNIEXPORT jdouble JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveMinTemp(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->min_temp;
}

extern "C" JNIEXPORT jdouble JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveMaxTemp(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->max_temp;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveMode(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return static_cast<jint>(dive->dive_mode);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveFingerprint(
    JNIEnv *env, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    char hex[LIBDC_MAX_FINGERPRINT * 2 + 1];
    for (unsigned int i = 0; i < dive->fingerprint_size; i++) {
        snprintf(hex + i * 2, 3, "%02x", dive->fingerprint[i]);
    }
    hex[dive->fingerprint_size * 2] = '\0';
    return env->NewStringUTF(hex);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveSampleCount(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return static_cast<jint>(dive->sample_count);
}

extern "C" JNIEXPORT jdoubleArray JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveSample(
    JNIEnv *env, jclass, jlong divePtr, jint index) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    if (index < 0 || static_cast<unsigned int>(index) >= dive->sample_count) return nullptr;

    const libdc_sample_t *s = &dive->samples[index];
    // Return [time_ms, depth, temperature, pressure, tank]
    jdouble values[5] = {
        static_cast<jdouble>(s->time_ms),
        s->depth,
        s->temperature,
        s->pressure,
        static_cast<jdouble>(s->tank)
    };
    jdoubleArray result = env->NewDoubleArray(5);
    env->SetDoubleArrayRegion(result, 0, 5, values);
    return result;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveGasmixCount(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return static_cast<jint>(dive->gasmix_count);
}

extern "C" JNIEXPORT jdoubleArray JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveGasmix(
    JNIEnv *env, jclass, jlong divePtr, jint index) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    if (index < 0 || static_cast<unsigned int>(index) >= dive->gasmix_count) return nullptr;

    const libdc_gasmix_t *gm = &dive->gasmixes[index];
    jdouble values[2] = { gm->oxygen, gm->helium };
    jdoubleArray result = env->NewDoubleArray(2);
    env->SetDoubleArrayRegion(result, 0, 2, values);
    return result;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveTankCount(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return static_cast<jint>(dive->tank_count);
}

extern "C" JNIEXPORT jdoubleArray JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveTank(
    JNIEnv *env, jclass, jlong divePtr, jint index) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    if (index < 0 || static_cast<unsigned int>(index) >= dive->tank_count) return nullptr;

    const libdc_tank_t *tk = &dive->tanks[index];
    // Return [gasmix, volume, workpressure, beginpressure, endpressure]
    jdouble values[5] = {
        static_cast<jdouble>(tk->gasmix),
        tk->volume,
        tk->workpressure,
        tk->beginpressure,
        tk->endpressure
    };
    jdoubleArray result = env->NewDoubleArray(5);
    env->SetDoubleArrayRegion(result, 0, 5, values);
    return result;
}
