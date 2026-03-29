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

static bool clear_jni_exception(JNIEnv *env, const char *context) {
    if (!env->ExceptionCheck()) return false;

    __android_log_print(ANDROID_LOG_ERROR, TAG,
        "JNI exception while %s", context);
    env->ExceptionDescribe();
    env->ExceptionClear();
    return true;
}

static bool set_descriptor_info(JNIEnv *env, jobject infoObj,
                                const libdc_descriptor_info_t &info) {
    if (infoObj == nullptr) {
        __android_log_print(ANDROID_LOG_ERROR, TAG,
            "DescriptorInfo target was null");
        return false;
    }

    jclass cls = env->GetObjectClass(infoObj);
    if (cls == nullptr) {
        clear_jni_exception(env, "resolving DescriptorInfo class");
        return false;
    }
    if (clear_jni_exception(env, "resolving DescriptorInfo class")) {
        return false;
    }

    jfieldID vendorField = env->GetFieldID(cls, "vendor", "Ljava/lang/String;");
    if (vendorField == nullptr) {
        clear_jni_exception(env, "resolving DescriptorInfo.vendor");
        return false;
    }
    if (clear_jni_exception(env, "resolving DescriptorInfo.vendor")) {
        return false;
    }

    jfieldID productField = env->GetFieldID(cls, "product", "Ljava/lang/String;");
    if (productField == nullptr) {
        clear_jni_exception(env, "resolving DescriptorInfo.product");
        return false;
    }
    if (clear_jni_exception(env, "resolving DescriptorInfo.product")) {
        return false;
    }

    jfieldID modelField = env->GetFieldID(cls, "model", "I");
    if (modelField == nullptr) {
        clear_jni_exception(env, "resolving DescriptorInfo.model");
        return false;
    }
    if (clear_jni_exception(env, "resolving DescriptorInfo.model")) {
        return false;
    }

    jfieldID transportsField = env->GetFieldID(cls, "transports", "I");
    if (transportsField == nullptr) {
        clear_jni_exception(env, "resolving DescriptorInfo.transports");
        return false;
    }
    if (clear_jni_exception(env, "resolving DescriptorInfo.transports")) {
        return false;
    }

    jstring vendor = env->NewStringUTF(info.vendor ? info.vendor : "");
    if (vendor == nullptr) {
        clear_jni_exception(env, "creating vendor string");
        return false;
    }
    if (clear_jni_exception(env, "creating vendor string")) {
        return false;
    }

    jstring product = env->NewStringUTF(info.product ? info.product : "");
    if (product == nullptr) {
        clear_jni_exception(env, "creating product string");
        env->DeleteLocalRef(vendor);
        return false;
    }
    if (clear_jni_exception(env, "creating product string")) {
        env->DeleteLocalRef(vendor);
        return false;
    }

    env->SetObjectField(infoObj, vendorField, vendor);
    if (clear_jni_exception(env, "writing DescriptorInfo.vendor")) {
        env->DeleteLocalRef(vendor);
        env->DeleteLocalRef(product);
        return false;
    }

    env->SetObjectField(infoObj, productField, product);
    if (clear_jni_exception(env, "writing DescriptorInfo.product")) {
        env->DeleteLocalRef(vendor);
        env->DeleteLocalRef(product);
        return false;
    }

    env->SetIntField(infoObj, modelField, static_cast<jint>(info.model));
    if (clear_jni_exception(env, "writing DescriptorInfo.model")) {
        env->DeleteLocalRef(vendor);
        env->DeleteLocalRef(product);
        return false;
    }

    env->SetIntField(infoObj, transportsField, static_cast<jint>(info.transports));
    if (clear_jni_exception(env, "writing DescriptorInfo.transports")) {
        env->DeleteLocalRef(vendor);
        env->DeleteLocalRef(product);
        return false;
    }

    env->DeleteLocalRef(vendor);
    env->DeleteLocalRef(product);
    return true;
}

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
    if (!set_descriptor_info(env, infoObj, info)) return -1;

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

    if (!set_descriptor_info(env, infoObj, info)) return JNI_FALSE;

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
    char ble_name[128];  // BLE device name for DC_IOCTL_BLE_GET_NAME
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

// BLE ioctl constants matching libdivecomputer's encoding.
// DC_IOCTL('b', 0) = (0x62 << 8) | 0 = 0x6200
#define BLE_IOCTL_GET_NAME 0x6200
#define BLE_IOCTL_GET_PINCODE_NR 1
#define BLE_IOCTL_ACCESSCODE_NR 2

static int jni_io_ioctl(void *userdata, unsigned int request,
                         void *data, size_t size) {
    auto *ctx = static_cast<JniIoContext *>(userdata);

    unsigned int ioctl_type = (request >> 8) & 0xFF;
    unsigned int ioctl_nr = request & 0xFF;
    __android_log_print(ANDROID_LOG_DEBUG, TAG,
        "ioctl: request=0x%x type=0x%x nr=%u size=%zu name='%s'",
        request, ioctl_type, ioctl_nr, size, ctx->ble_name);

    // Handle BLE_GET_NAME: return the BLE device name.
    if (ioctl_type == 0x62 && ioctl_nr == 0) {
        if (data == nullptr || size == 0) {
            return LIBDC_STATUS_INVALIDARGS;
        }
        size_t name_len = strlen(ctx->ble_name);
        if (name_len == 0) {
            return LIBDC_STATUS_UNSUPPORTED;
        }
        size_t copy_len = name_len + 1;  // include null terminator
        if (copy_len > size) {
            copy_len = size;
        }
        memcpy(data, ctx->ble_name, copy_len);
        // Ensure null termination.
        static_cast<char *>(data)[size - 1] = '\0';
        return LIBDC_STATUS_SUCCESS;
    }

    // Handle BLE_GET_PINCODE: request PIN from user via Kotlin.
    if (ioctl_type == 0x62 && ioctl_nr == BLE_IOCTL_GET_PINCODE_NR) {
        if (data == nullptr || size == 0) {
            return LIBDC_STATUS_INVALIDARGS;
        }

        JNIEnv *env;
        bool attached = false;
        if (ctx->jvm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
            ctx->jvm->AttachCurrentThread(&env, nullptr);
            attached = true;
        }

        // Call ioHandler.onPinCodeRequired(address) -- blocks until PIN is entered.
        jclass cls = env->GetObjectClass(ctx->ioHandler);
        jmethodID method = env->GetMethodID(cls, "onPinCodeRequired",
            "(Ljava/lang/String;)Ljava/lang/String;");

        jstring jAddress = env->NewStringUTF(ctx->ble_name);
        jstring jPin = (jstring)env->CallObjectMethod(ctx->ioHandler, method, jAddress);
        env->DeleteLocalRef(jAddress);

        int status = LIBDC_STATUS_SUCCESS;
        if (jPin == nullptr || env->GetStringLength(jPin) == 0) {
            status = LIBDC_STATUS_CANCELLED;
        } else {
            const char *pin_chars = env->GetStringUTFChars(jPin, nullptr);
            size_t pin_len = strlen(pin_chars) + 1;
            size_t copy_len = pin_len < size ? pin_len : size;
            memcpy(data, pin_chars, copy_len);
            static_cast<char *>(data)[copy_len - 1] = '\0';
            env->ReleaseStringUTFChars(jPin, pin_chars);
            __android_log_print(ANDROID_LOG_DEBUG, TAG,
                "ioctl BLE_GET_PINCODE -> PIN provided (%zu chars)", pin_len - 1);
        }

        if (jPin != nullptr) env->DeleteLocalRef(jPin);
        if (attached) ctx->jvm->DetachCurrentThread();
        return status;
    }

    // Handle BLE_GET_ACCESSCODE / BLE_SET_ACCESSCODE.
    if (ioctl_type == 0x62 && ioctl_nr == BLE_IOCTL_ACCESSCODE_NR) {
        if (data == nullptr || size == 0) {
            return LIBDC_STATUS_INVALIDARGS;
        }

        unsigned int direction = (request >> 30) & 0x3;

        JNIEnv *env;
        bool attached = false;
        if (ctx->jvm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
            ctx->jvm->AttachCurrentThread(&env, nullptr);
            attached = true;
        }

        jclass cls = env->GetObjectClass(ctx->ioHandler);
        jstring jAddress = env->NewStringUTF(ctx->ble_name);
        int status;

        if (direction == 1) {
            // GET access code
            jmethodID method = env->GetMethodID(cls, "getAccessCode",
                "(Ljava/lang/String;)[B");
            jbyteArray jCode = (jbyteArray)env->CallObjectMethod(
                ctx->ioHandler, method, jAddress);

            if (jCode == nullptr) {
                status = LIBDC_STATUS_UNSUPPORTED;
                __android_log_print(ANDROID_LOG_DEBUG, TAG,
                    "ioctl BLE_GET_ACCESSCODE -> not found");
            } else {
                jsize code_len = env->GetArrayLength(jCode);
                jsize copy_len = code_len < (jsize)size ? code_len : (jsize)size;
                env->GetByteArrayRegion(jCode, 0, copy_len,
                    reinterpret_cast<jbyte *>(data));
                env->DeleteLocalRef(jCode);
                status = LIBDC_STATUS_SUCCESS;
                __android_log_print(ANDROID_LOG_DEBUG, TAG,
                    "ioctl BLE_GET_ACCESSCODE -> found (%d bytes)", code_len);
            }
        } else {
            // SET access code
            jbyteArray jCode = env->NewByteArray((jsize)size);
            env->SetByteArrayRegion(jCode, 0, (jsize)size,
                reinterpret_cast<const jbyte *>(data));

            jmethodID method = env->GetMethodID(cls, "setAccessCode",
                "(Ljava/lang/String;[B)V");
            env->CallVoidMethod(ctx->ioHandler, method, jAddress, jCode);
            env->DeleteLocalRef(jCode);
            status = LIBDC_STATUS_SUCCESS;
            __android_log_print(ANDROID_LOG_DEBUG, TAG,
                "ioctl BLE_SET_ACCESSCODE -> stored (%zu bytes)", size);
        }

        env->DeleteLocalRef(jAddress);
        if (attached) ctx->jvm->DetachCurrentThread();
        return status;
    }

    return LIBDC_STATUS_UNSUPPORTED;
}

static int jni_io_purge(void *userdata, unsigned int direction) {
    auto *ctx = static_cast<JniIoContext *>(userdata);
    JNIEnv *env;
    bool attached = false;
    if (ctx->jvm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        ctx->jvm->AttachCurrentThread(&env, nullptr);
        attached = true;
    }

    jclass cls = env->GetObjectClass(ctx->ioHandler);
    jmethodID method = env->GetMethodID(cls, "purge", "(I)V");
    if (method) {
        env->CallVoidMethod(ctx->ioHandler, method, static_cast<jint>(direction));
    }

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
    jstring devName,
    jbyteArray fingerprint,
    jobject downloadCallback,
    jbyteArray errorBuf) {

    auto *session = reinterpret_cast<libdc_download_session_t *>(sessionPtr);

    const char *vendorStr = env->GetStringUTFChars(vendor, nullptr);
    const char *productStr = env->GetStringUTFChars(product, nullptr);

    // Set up I/O callbacks via JNI bridge.
    JavaVM *jvm;
    env->GetJavaVM(&jvm);

    JniIoContext ioCtx;
    memset(&ioCtx, 0, sizeof(ioCtx));
    ioCtx.jvm = jvm;
    ioCtx.ioHandler = env->NewGlobalRef(ioHandler);
    ioCtx.timeout_ms = 10000;

    // Store BLE device name for DC_IOCTL_BLE_GET_NAME.
    if (devName != nullptr) {
        const char *nameStr = env->GetStringUTFChars(devName, nullptr);
        strncpy(ioCtx.ble_name, nameStr, sizeof(ioCtx.ble_name) - 1);
        ioCtx.ble_name[sizeof(ioCtx.ble_name) - 1] = '\0';
        env->ReleaseStringUTFChars(devName, nameStr);
    }

    libdc_io_callbacks_t io_callbacks;
    memset(&io_callbacks, 0, sizeof(io_callbacks));
    io_callbacks.set_timeout = jni_io_set_timeout;
    io_callbacks.read = jni_io_read;
    io_callbacks.write = jni_io_write;
    io_callbacks.ioctl = jni_io_ioctl;
    io_callbacks.close = jni_io_close;
    io_callbacks.purge = jni_io_purge;
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

    // Decode fingerprint from Java byte array.
    unsigned char *fp_data = nullptr;
    unsigned int fp_size = 0;
    if (fingerprint != nullptr) {
        fp_size = static_cast<unsigned int>(env->GetArrayLength(fingerprint));
        if (fp_size > 0) {
            fp_data = new unsigned char[fp_size];
            env->GetByteArrayRegion(fingerprint, 0, fp_size,
                reinterpret_cast<jbyte *>(fp_data));
        }
    }

    // Register libdivecomputer log callback so internal diagnostic messages
    // appear in logcat. Android's NativeLogger already wraps Log.d(), so
    // logcat output is captured by the platform-level logging infrastructure.
    libdc_set_log_callback(
        [](int level, const char *message, void *) {
            // Map dc_loglevel_t: ERROR=1, WARNING=2, INFO=3, DEBUG=4+
            android_LogPriority priority;
            switch (level) {
            case 1:
                priority = ANDROID_LOG_ERROR;
                break;
            case 2:
                priority = ANDROID_LOG_WARN;
                break;
            case 3:
                priority = ANDROID_LOG_INFO;
                break;
            default:
                priority = ANDROID_LOG_DEBUG;
                break;
            }
            __android_log_print(priority, "libdc", "%s", message);
        },
        nullptr
    );

    // Run the download.
    char error_buf[256] = {0};
    int result = libdc_download_run(
        session,
        vendorStr, productStr,
        static_cast<unsigned int>(model),
        static_cast<unsigned int>(transport),
        &io_callbacks,
        fp_data, fp_size,
        &dl_callbacks,
        nullptr, nullptr,
        error_buf, sizeof(error_buf));

    // Cleanup fingerprint.
    delete[] fp_data;

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

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveTimezone(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->timezone;
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
    // All 14 fields. Integer sentinels (UINT32_MAX) are cast to double.
    jdouble values[14] = {
        static_cast<jdouble>(s->time_ms),
        s->depth,
        s->temperature,
        s->pressure,
        static_cast<jdouble>(s->tank),
        static_cast<jdouble>(s->heartbeat),
        s->setpoint,
        s->ppo2,
        s->cns,
        static_cast<jdouble>(s->rbt),
        static_cast<jdouble>(s->deco_type),
        static_cast<jdouble>(s->deco_time),
        s->deco_depth,
        static_cast<jdouble>(s->deco_tts)
    };
    jdoubleArray result = env->NewDoubleArray(14);
    env->SetDoubleArrayRegion(result, 0, 14, values);
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

// ============================================================
// Event Data Access
// ============================================================

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveEventCount(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    if (!dive->events) return 0;
    return static_cast<jint>(dive->event_count);
}

extern "C" JNIEXPORT jlongArray JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveEvent(
    JNIEnv *env, jclass, jlong divePtr, jint index) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    if (!dive->events || index < 0 ||
        static_cast<unsigned int>(index) >= dive->event_count) return nullptr;

    const libdc_event_t *e = &dive->events[index];
    jlong values[4] = {
        static_cast<jlong>(e->time_ms),
        static_cast<jlong>(e->type),
        static_cast<jlong>(e->flags),
        static_cast<jlong>(e->value)
    };
    jlongArray result = env->NewLongArray(4);
    env->SetLongArrayRegion(result, 0, 4, values);
    return result;
}

// ============================================================
// Decompression Model Access
// ============================================================

extern "C" JNIEXPORT jintArray JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveDecoModel(
    JNIEnv *env, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    jint values[4] = {
        static_cast<jint>(dive->deco_model_type),
        static_cast<jint>(dive->deco_conservatism),
        static_cast<jint>(dive->gf_low),
        static_cast<jint>(dive->gf_high)
    };
    jintArray result = env->NewIntArray(4);
    env->SetIntArrayRegion(result, 0, 4, values);
    return result;
}
