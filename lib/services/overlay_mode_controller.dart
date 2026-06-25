import 'app_settings_controller.dart';
import 'game_status_service.dart';
import 'overlay_service.dart';

class OverlayModeStatus {
  const OverlayModeStatus({
    required this.supported,
    required this.permissionGranted,
    required this.running,
  });

  static const unknown = OverlayModeStatus(
    supported: false,
    permissionGranted: false,
    running: false,
  );

  final bool supported;
  final bool permissionGranted;
  final bool running;
}

class OverlayModeResult {
  const OverlayModeResult({required this.status, this.message});

  final OverlayModeStatus status;
  final String? message;
}

class OverlayModeController {
  const OverlayModeController([this._overlayService = const OverlayService()]);

  static const _permissionSettleDelay = Duration(milliseconds: 500);
  static const _startSettleDelay = Duration(milliseconds: 450);
  static const _permissionMessage =
      'Enable Display over other apps to use Overlay Mode.';
  static const _unsupportedMessage =
      'Overlay Mode is unavailable on this device.';
  static const _startFailureMessage =
      'Overlay Mode did not start. Try reopening VanaDeck and starting it again.';

  final OverlayService _overlayService;

  Future<OverlayModeStatus> status() async {
    return OverlayModeStatus(
      supported: await _overlayService.isSupported(),
      permissionGranted: await _overlayService.hasPermission(),
      running: await _overlayService.isRunning(),
    );
  }

  Future<OverlayModeStatus> requestPermission() async {
    await _overlayService.requestPermission();
    await Future<void>.delayed(_permissionSettleDelay);
    return status();
  }

  Future<OverlayModeResult> start(AppSettingsController settings) async {
    var current = await status();
    if (!current.supported) {
      return OverlayModeResult(status: current, message: _unsupportedMessage);
    }

    if (!current.permissionGranted) {
      current = await requestPermission();
      if (!current.permissionGranted) {
        return OverlayModeResult(status: current, message: _permissionMessage);
      }
    }

    await GameStatusService.stopListening();
    final accepted = await _overlayService.start(
      scale: settings.overlayScale,
      appearance: settings.overlayAppearance,
      tabPosition: settings.overlayTabPosition,
      macroButtonStyle: settings.overlayMacroButtonStyle,
    );
    await Future<void>.delayed(_startSettleDelay);

    final running = accepted && await _overlayService.isRunning();
    final nextStatus = OverlayModeStatus(
      supported: current.supported,
      permissionGranted: current.permissionGranted,
      running: running,
    );

    if (running) {
      return OverlayModeResult(status: nextStatus);
    }

    GameStatusService.startDefaultListener();
    return OverlayModeResult(
      status: nextStatus,
      message: await _overlayService.lastError() ?? _startFailureMessage,
    );
  }

  Future<OverlayModeResult> stop() async {
    await _overlayService.stop();
    GameStatusService.startDefaultListener();

    final current = await status();
    return OverlayModeResult(
      status: OverlayModeStatus(
        supported: current.supported,
        permissionGranted: current.permissionGranted,
        running: false,
      ),
    );
  }

  Future<OverlayModeResult> toggle(AppSettingsController settings) async {
    final current = await status();
    return current.running ? stop() : start(settings);
  }
}
