package com.erisports.client

import android.annotation.SuppressLint
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"eri_sports/device_verification_identity",
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"getDeviceIdentity" -> {
					val macAddress = resolveMacAddress()
					if (macAddress != null) {
						result.success(
							mapOf(
								"seed" to macAddress,
								"source" to "macAddress",
							),
						)
						return@setMethodCallHandler
					}

					val androidId = resolveAndroidId()
					if (androidId != null) {
						result.success(
							mapOf(
								"seed" to androidId,
								"source" to "androidIdFallback",
							),
						)
						return@setMethodCallHandler
					}

					result.success(
						mapOf(
							"seed" to (android.os.Build.DEVICE ?: "android-device"),
							"source" to "unknown",
						),
					)
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun resolveMacAddress(): String? {
		val interfaces = NetworkInterface.getNetworkInterfaces() ?: return null
		while (interfaces.hasMoreElements()) {
			val candidate = interfaces.nextElement()
			if (candidate.isLoopback || candidate.isVirtual || !candidate.isUp) {
				continue
			}

			val hardwareAddress = try {
				candidate.hardwareAddress
			} catch (_: Exception) {
				null
			} ?: continue

			if (hardwareAddress.isEmpty()) {
				continue
			}

			val macAddress = hardwareAddress.joinToString(":") { octet ->
				String.format("%02X", octet)
			}
			if (macAddress == "02:00:00:00:00:00") {
				continue
			}
			return macAddress
		}
		return null
	}

	@SuppressLint("HardwareIds")
	private fun resolveAndroidId(): String? {
		return Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
			?.takeIf { it.isNotBlank() }
	}
}