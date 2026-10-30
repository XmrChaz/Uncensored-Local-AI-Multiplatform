import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../services/odysseus_bridge_service.dart';
import 'odysseus_webview_screen.dart';

/// Entry point for bridging to a self-hosted Odysseus AI workspace
/// (https://github.com/AbuZar-Ansarii/Odysseus-Android) that the user
/// has set up themselves in Termux. This screen never installs or runs
/// anything on the user's behalf — it only opens Termux and, once the
/// local dashboard is up, displays it in a WebView.
class OdysseusBridgeScreen extends StatefulWidget {
  const OdysseusBridgeScreen({super.key});

  @override
  State<OdysseusBridgeScreen> createState() => _OdysseusBridgeScreenState();
}

class _OdysseusBridgeScreenState extends State<OdysseusBridgeScreen> {
  final bridge = Get.find<OdysseusBridgeService>();
  Timer? _poll;

  static const _installOneLiner =
      'curl -fsSL https://raw.githubusercontent.com/AbuZar-Ansarii/'
      'Odysseus-Android/main/install.sh | bash';

  @override
  void initState() {
    super.initState();
    bridge.checkReachable();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) bridge.checkReachable();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _copyInstallCommand() {
    Clipboard.setData(const ClipboardData(text: _installOneLiner));
    Get.snackbar('Copied', 'Paste it into Termux to install Odysseus.',
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> _openTermux() async {
    final ok = await bridge.openTermux();
    if (!ok) {
      Get.dialog(
        AlertDialog(
          backgroundColor: Get.context!.bgPanel,
          title: const Text('Termux not found'),
          content: const Text(
            'Install Termux from F-Droid (not the Play Store build, which '
            "is outdated), then come back here.",
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                bridge.openTermuxInstallPage();
              },
              child: const Text('Get Termux'),
            ),
          ],
        ),
      );
    }
  }

  void _openDashboard() {
    Get.to(() => OdysseusWebViewScreen(url: bridge.baseUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bgPanel,
        title: const Text('Odysseus Bridge', style: TextStyle(fontSize: 16)),
        elevation: 0,
        centerTitle: true,
      ),
      body: !Platform.isAndroid
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Odysseus Bridge requires Termux, which is Android-only.',
                  style: TextStyle(color: context.textM),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Obx(() {
              final reachable = bridge.isReachable.value;
              final checking = bridge.isChecking.value;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (reachable ? AppColors.green : AppColors.orange)
                          .withOpacity(0.1),
                      border: Border.all(
                        color: (reachable ? AppColors.green : AppColors.orange)
                            .withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          reachable
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: reachable ? AppColors.green : AppColors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reachable
                                    ? 'Odysseus detected'
                                    : checking
                                        ? 'Checking…'
                                        : 'Not detected yet',
                                style: TextStyle(
                                  color: reachable
                                      ? AppColors.green
                                      : AppColors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                bridge.baseUrl,
                                style: TextStyle(
                                  color: context.textD,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: checking ? null : bridge.checkReachable,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'One-time setup',
                    style: TextStyle(
                      color: context.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Odysseus runs entirely inside Termux, not inside this '
                    'app. Install Termux from F-Droid, paste the command '
                    'below into it once, then run ./run.sh each time you '
                    'want the dashboard available. After that first setup '
                    "it runs fully offline — this screen just opens it.",
                    style: TextStyle(color: context.textM, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.bgPanel,
                      border: Border.all(color: context.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _installOneLiner,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: _copyInstallCommand,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openTermux,
                      icon: const Icon(Icons.terminal_rounded, size: 18),
                      label: const Text('Open Termux'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.text,
                        side: BorderSide(color: context.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openDashboard,
                      icon: const Icon(Icons.dashboard_rounded, size: 18),
                      label: const Text('Open Dashboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Port',
                    style: TextStyle(
                      color: context.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('odysseus-port-${bridge.port.value}'),
                    initialValue: bridge.port.value.toString(),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: context.text, fontSize: 13),
                    decoration: InputDecoration(
                      helperText: 'Default Odysseus dashboard port is 7000.',
                      filled: true,
                      fillColor: context.bgInput,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.border),
                      ),
                    ),
                    onFieldSubmitted: (value) async {
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed < 1 || parsed > 65535) {
                        Get.snackbar('Invalid Port', 'Choose a port from 1 to 65535.',
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      await bridge.setPort(parsed);
                    },
                  ),
                ],
              );
            }),
    );
  }
}
