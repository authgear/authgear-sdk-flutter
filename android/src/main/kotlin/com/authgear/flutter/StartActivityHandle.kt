package com.authgear.flutter

import android.util.SparseArray
import java.util.concurrent.atomic.AtomicInteger

internal class StartActivityHandle<T> internal constructor(val tag: Int, val value: T)

internal class StartActivityHandles<T> internal constructor(
    private val counter: AtomicInteger,
    private val map: SparseArray<StartActivityHandle<T>>) {

    internal constructor() : this(AtomicInteger(), SparseArray())

    internal fun push(handle: StartActivityHandle<T>): Int {
        val index = counter.incrementAndGet()
        map.put(index, handle)
        return index
    }

    internal fun pop(index: Int): StartActivityHandle<T>? {
        val handle = map.get(index)
        map.remove(index)
        return handle
    }
}