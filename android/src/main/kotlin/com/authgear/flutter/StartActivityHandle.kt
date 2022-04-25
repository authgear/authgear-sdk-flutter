package com.authgear.flutter

import android.util.SparseArray
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicInteger

internal class StartActivityHandle internal constructor(val tag: Int, val result: MethodChannel.Result)

internal class StartActivityHandles internal constructor(
    private val counter: AtomicInteger,
    private val map: SparseArray<StartActivityHandle>) {

    internal constructor() : this(AtomicInteger(), SparseArray())

    internal fun push(handle: StartActivityHandle): Int {
        val index = counter.incrementAndGet()
        map.put(index, handle)
        return index
    }

    internal fun pop(index: Int): StartActivityHandle? {
        val handle = map.get(index)
        map.remove(index)
        return handle
    }
}