import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'chat_storage_service.dart';

/// Bridges to a Termux + proot-distro install running the Odysseus AI
/// workspace (https://github.com/AbuZar-Ansarii/Odysseus-Android) on
/// `localhost`. This app does not install or run Odysseus itself — the
/// user sets that up once in Termux — it only detects the local server
/// and hosts it in an in-app WebView.
class OdysseusBridgeService extends GetxService {
  static const termuxPackage = 'com.termux';
  static const fdroidTermuxUrl = 'https://f-droid.org/packages/com.termux/';

  final ChatStorageService _storage = Get.find<ChatStorageService>();

  final port = 7000.obs;
  final isReachable = false.obs;
  final isChecking = false.obs;

  Future<OdysseusBridgeService> init() async {
    port.value = _normalizePort(_storage.odysseusBridgePort);
    return this;
  }

  String get baseUrl => 'http://127.0.0.1:${port.value}';

  Future<void> setPort(int value) async {
    port.value = _normalizePort(value);
    _storage.odysseusBridgePort = port.value;
    await checkReachable();
  }

  int _normalizePort(int value) {
    if (value < 1 || value > 65535) return 7000;
    return value;
  }

  /// Pings the local Odysseus dashboard. Returns true if something is
  /// listening on the configured port.
  Future<bool> checkReachable() async {
    isChecking.value = true;
    try {
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 3));
      isReachable.value = response.statusCode < 500;
    } catch (_) {
      isReachable.value = false;
    } finally {
      isChecking.value = false;
    }
    return isReachable.value;
  }

  /// Launches the installed Termux app so the user can run `./run.sh`.
  /// Returns false if Termux is not installed or could not be launched.
  Future<bool> openTermux() async {
    if (!Platform.isAndroid) return false;
    try {
      final intent = AndroidIntent(
        action: 'action_main',
        category: 'android.intent.category.LAUNCHER',
        package: termuxPackage,
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> openTermuxInstallPage() async {
    final uri = Uri.parse(fdroidTermuxUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
