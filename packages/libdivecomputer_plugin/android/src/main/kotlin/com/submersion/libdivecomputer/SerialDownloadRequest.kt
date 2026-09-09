package com.submersion.libdivecomputer

import android.os.Parcel
import android.os.Parcelable

/** The serial-download request marshaled from the main process into :dc (#318). */
class SerialDownloadRequest(
    val vendor: String,
    val product: String,
    val model: Long,
    val name: String?,
    val fingerprint: ByteArray?,
    /** Set the computer's clock after a successful download (issue #1216). */
    val syncClock: Boolean = false,
) : Parcelable {

    constructor(parcel: Parcel) : this(
        vendor = parcel.readString() ?: "",
        product = parcel.readString() ?: "",
        model = parcel.readLong(),
        name = parcel.readString(),
        fingerprint = parcel.createByteArray(),
        syncClock = parcel.readInt() != 0,
    )

    override fun writeToParcel(dest: Parcel, flags: Int) {
        dest.writeString(vendor)
        dest.writeString(product)
        dest.writeLong(model)
        dest.writeString(name)
        dest.writeByteArray(fingerprint)
        dest.writeInt(if (syncClock) 1 else 0)
    }

    override fun describeContents(): Int = 0

    companion object CREATOR : Parcelable.Creator<SerialDownloadRequest> {
        override fun createFromParcel(parcel: Parcel) = SerialDownloadRequest(parcel)
        override fun newArray(size: Int): Array<SerialDownloadRequest?> = arrayOfNulls(size)
    }
}
