package com.example.correctv1

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.correctv1.bluetooth/unpair"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "removeBond") {
                val address = call.argument<String>("address")
                if (address != null) {
                    val success = removeBond(address)
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENT", "Address is null", null)
                }
            } else if (call.method == "createBond") {
                val address = call.argument<String>("address")
                if (address != null) {
                    val success = createBond(address)
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENT", "Address is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun createBond(address: String): Boolean {
        return try {
            val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
            if (bluetoothAdapter == null) {
                false
            } else {
                val device = bluetoothAdapter.getRemoteDevice(address)
                when (device?.bondState) {
                    BluetoothDevice.BOND_BONDED -> true
                    BluetoothDevice.BOND_BONDING -> true
                    else -> {
                        val method = device.javaClass.getMethod("createBond")
                        method.invoke(device) as Boolean
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    @SuppressLint("MissingPermission")
    private fun removeBond(address: String): Boolean {
        return try {
            val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
            if (bluetoothAdapter == null) {
                false
            } else {
                val device = bluetoothAdapter.getRemoteDevice(address)
                if (device != null) {
                    // Use reflection to call removeBond() which is hidden in the API
                    val method = device.javaClass.getMethod("removeBond")
                    method.invoke(device) as Boolean
                } else {
                    false
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
