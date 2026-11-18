import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_constants.dart';
import 'storage_scanner.dart';
import 'foreground_service_manager.dart';

class OnboardingState {
  final bool isLoading;
  final bool isCompleted;
  final bool hasStoragePermission;
  final bool hasBatteryOptimizationIgnored;
  final String pin;
  final List<ScannedFolder> availableFolders;
  final Set<String> selectedFolderPaths;
  final String? errorMessage;

  const OnboardingState({
    this.isLoading = false,
    this.isCompleted = false,
    this.hasStoragePermission = false,
    this.hasBatteryOptimizationIgnored = false,
    this.pin = OnboardingKeys.defaultPin,
    this.availableFolders = const [],
    this.selectedFolderPaths = const {},
    this.errorMessage,
  });

  OnboardingState copyWith({
    bool? isLoading,
    bool? isCompleted,
    bool? hasStoragePermission,
    bool? hasBatteryOptimizationIgnored,
    String? pin,
    List<ScannedFolder>? availableFolders,
    Set<String>? selectedFolderPaths,
    String? errorMessage,
  }) {
    return OnboardingState(
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      hasStoragePermission: hasStoragePermission ?? this.hasStoragePermission,
      hasBatteryOptimizationIgnored:
          hasBatteryOptimizationIgnored ?? this.hasBatteryOptimizationIgnored,
      pin: pin ?? this.pin,
      availableFolders: availableFolders ?? this.availableFolders,
      selectedFolderPaths: selectedFolderPaths ?? this.selectedFolderPaths,
      errorMessage: errorMessage,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController() : super(const OnboardingState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();

    final isCompleted = prefs.getBool(OnboardingKeys.keyOnboardingCompleted) ?? false;
    final savedPin = prefs.getString(OnboardingKeys.keyPairingPin) ?? _generateRandomPin();
    final savedFolders = prefs.getStringList(OnboardingKeys.keySharedFolders)?.toSet() ?? {};

    bool storageGranted = true;
    bool batteryIgnored = true;

    if (Platform.isAndroid) {
      storageGranted = await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted;
      batteryIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
    }

    final folders = await StorageScanner.scanAvailableFolders();
    final initialSelected = savedFolders.isNotEmpty
        ? savedFolders
        : folders.take(3).map((f) => f.path).toSet();

    state = state.copyWith(
      isLoading: false,
      isCompleted: isCompleted,
      hasStoragePermission: storageGranted,
      hasBatteryOptimizationIgnored: batteryIgnored,
      pin: savedPin,
      availableFolders: folders,
      selectedFolderPaths: initialSelected,
    );
  }

  static String _generateRandomPin() {
    final rnd = Random();
    final code = 100000 + rnd.nextInt(900000);
    return code.toString();
  }

  void generateNewPin() {
    state = state.copyWith(pin: _generateRandomPin());
  }

  void setPin(String newPin) {
    if (newPin.trim().length <= 6) {
      state = state.copyWith(pin: newPin.trim());
    }
  }

  Future<void> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      state = state.copyWith(hasStoragePermission: true);
      return;
    }

    PermissionStatus status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    final granted = status.isGranted;
    state = state.copyWith(hasStoragePermission: granted);

    if (granted) {
      final folders = await StorageScanner.scanAvailableFolders();
      state = state.copyWith(
        availableFolders: folders,
        selectedFolderPaths: folders.take(3).map((f) => f.path).toSet(),
      );
    }
  }

  Future<void> requestBatteryOptimization() async {
    if (!Platform.isAndroid) {
      state = state.copyWith(hasBatteryOptimizationIgnored: true);
      return;
    }

    final status = await Permission.ignoreBatteryOptimizations.request();
    state = state.copyWith(hasBatteryOptimizationIgnored: status.isGranted);
  }

  void toggleFolder(String path) {
    final current = Set<String>.from(state.selectedFolderPaths);
    if (current.contains(path)) {
      current.remove(path);
    } else {
      current.add(path);
    }
    state = state.copyWith(selectedFolderPaths: current);
  }

  void selectAll() {
    final all = state.availableFolders.map((f) => f.path).toSet();
    state = state.copyWith(selectedFolderPaths: all);
  }

  void deselectAll() {
    state = state.copyWith(selectedFolderPaths: {});
  }

  Future<bool> completeOnboarding() async {
    if (state.pin.length != 6) {
      state = state.copyWith(errorMessage: 'Pairing PIN must be exactly 6 digits');
      return false;
    }

    if (state.selectedFolderPaths.isEmpty) {
      state = state.copyWith(errorMessage: 'Please select at least one folder to share');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(OnboardingKeys.keyPairingPin, state.pin);
    await prefs.setStringList(
      OnboardingKeys.keySharedFolders,
      state.selectedFolderPaths.toList(),
    );
    await prefs.setBool(OnboardingKeys.keyOnboardingCompleted, true);

    // Launch foreground service on Android with Wi-Fi wake lock
    await ForegroundServiceManager.start(
      notificationTitle: 'P2P File Pool Server',
      notificationText: 'Sharing ${state.selectedFolderPaths.length} folders on port 45454',
    );

    state = state.copyWith(isLoading: false, isCompleted: true);
    return true;
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  return OnboardingController();
});
