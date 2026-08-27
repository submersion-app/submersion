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
) : Parcelable {

    constructor(parcel: Parcel) : this(
        vendor = parcel.readString() ?: "",
        product = parcel.readString() ?: "",
        model = parcel.readLong(),
        name = parcel.readString(),
        fingerprint = parcel.createByteArray(),
    )

    override fun writeToParcel(dest: Parcel, flags: Int) {
        dest.writeString(vendor)
        dest.writeString(product)
        dest.writeLong(model)
        dest.writeString(name)
        dest.writeByteArray(fingerprint)
    }

    override fun describeContents(): Int = 0

    companion object CREATOR : Parcelable.Creator<SerialDownloadRequest> {
        override fun createFromParcel(parcel: Parcel) = SerialDownloadRequest(parcel)
        override fun newArray(size: Int): Array<SerialDownloadRequest?> = arrayOfNulls(size)
    }
}
