import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'onboarding_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onSetupCompleted;

  const OnboardingScreen({
    super.key,
    required this.onSetupCompleted,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late TextEditingController _pinController;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    if (_pinController.text != state.pin) {
      _pinController.text = state.pin;
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Pool Onboarding & Security'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  _buildHeader(colorScheme),
                  const SizedBox(height: 24),

                  // Section 1: Permissions (Android specific)
                  if (Platform.isAndroid) ...[
                    _buildSectionTitle('1. System Permissions', Icons.security_rounded, colorScheme),
                    const SizedBox(height: 12),
                    _buildPermissionCard(
                      title: 'All Files Storage Access',
                      subtitle: 'Required to index and stream selected local folders',
                      isGranted: state.hasStoragePermission,
                      icon: Icons.folder_shared_rounded,
                      colorScheme: colorScheme,
                      onAction: controller.requestStoragePermission,
                    ),
                    const SizedBox(height: 12),
                    _buildPermissionCard(
                      title: 'Unrestricted Battery Optimization',
                      subtitle: 'Allows server to stay alive while screen is locked (No USB debug)',
                      isGranted: state.hasBatteryOptimizationIgnored,
                      icon: Icons.battery_charging_full_rounded,
                      colorScheme: colorScheme,
                      onAction: controller.requestBatteryOptimization,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Section 2: 6-digit PIN Pairing
                  _buildSectionTitle('2. Node Pairing PIN', Icons.pin_rounded, colorScheme),
                  const SizedBox(height: 8),
                  Text(
                    'Other LAN peers will need this PIN to verify write/delete mutations.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _buildPinCard(state, controller, colorScheme),
                  const SizedBox(height: 24),

                  // Section 3: Storage Folder Checklist
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('3. Folders to Share', Icons.folder_copy_rounded, colorScheme),
                      Row(
                        children: [
                          TextButton(
                            onPressed: controller.selectAll,
                            child: const Text('Select All'),
                          ),
                          TextButton(
                            onPressed: controller.deselectAll,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildFolderList(state, controller, colorScheme),
                  const SizedBox(height: 20),

                  if (state.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: colorScheme.onErrorContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: TextStyle(color: colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      final success = await controller.completeOnboarding();
                      if (success) {
                        widget.onSetupCompleted();
                      }
                    },
                    icon: const Icon(Icons.rocket_launch_rounded),
                    label: const Text(
                      'Start Local File Pool',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hub_rounded, color: colors.onPrimary, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local P2P File Pool',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Share, stream, and sync files across Android, TV, and PC over local Wi-Fi.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ColorScheme colors) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required bool isGranted,
    required IconData icon,
    required ColorScheme colorScheme,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? Colors.green.withOpacity(0.4) : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle_rounded : icon,
            color: isGranted ? Colors.green : colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isGranted)
            const Chip(
              label: Text('Enabled', style: TextStyle(fontSize: 12, color: Colors.green)),
              backgroundColor: Colors.transparent,
              side: BorderSide(color: Colors.green),
            )
          else
            OutlinedButton(
              onPressed: onAction,
              child: const Text('Grant'),
            ),
        ],
      ),
    );
  }

  Widget _buildPinCard(
    OnboardingState state,
    OnboardingController controller,
    ColorScheme colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 22,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                counterText: '',
                labelText: '6-Digit Pairing PIN',
                border: OutlineInputBorder(),
              ),
              onChanged: controller.setPin,
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Generate random PIN',
            onPressed: controller.generateNewPin,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderList(
    OnboardingState state,
    OnboardingController controller,
    ColorScheme colors,
  ) {
    if (state.availableFolders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          'No accessible folders found. Please grant storage access.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    }

    return Column(
      children: state.availableFolders.map((folder) {
        final isSelected = state.selectedFolderPaths.contains(folder.path);
        return Card(
          elevation: 0,
          color: isSelected
              ? colors.primaryContainer.withOpacity(0.4)
              : colors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? colors.primary : colors.outlineVariant.withOpacity(0.5),
            ),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (_) => controller.toggleFolder(folder.path),
            secondary: Icon(
              Icons.folder_rounded,
              color: isSelected ? colors.primary : colors.onSurfaceVariant,
            ),
            title: Text(
              folder.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              '${folder.estimatedItemCount} items • ${folder.path}',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }).toList(),
    );
  }
}
