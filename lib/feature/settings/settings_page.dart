import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/theme_provider.dart';
import '../auth/auth_state.dart';
import 'pages/admin_settings_page.dart';
import 'pages/change_password_page.dart';
import 'pages/edit_profile_page.dart';
import 'settings_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isClearingCache = false;

  void _clearCache() async {
    setState(() => _isClearingCache = true);
    await Future.delayed(const Duration(seconds: 1)); // Simula la limpieza
    if (!mounted) return;
    setState(() => _isClearingCache = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Caché limpiada correctamente'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    final pushNotifs = ref.watch(pushNotificationsProvider);
    final vibration = ref.watch(vibrationProvider);
    final isTodayView = ref.watch(defaultViewProvider);

    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Configuración'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // ==============================
          // 3. GESTIÓN DE CUENTA (Perfil)
          // ==============================
          Text(
            'Gestión de Cuenta',
            style: textTheme.titleSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: cs.primary,
                        backgroundImage: user?.avatarUrl != null
                            ? CachedNetworkImageProvider(user!.avatarUrl!)
                            : null,
                        child: user?.avatarUrl == null
                            ? Text(
                                user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: cs.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Usuario',
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              user?.email ?? 'correo@ejemplo.com',
                              style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar Perfil'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    if (vibration) HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Cambiar Contraseña'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    if (vibration) HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ==============================
          // 1. AJUSTES DE INTERFAZ
          // ==============================
          Text(
            'Ajustes de Interfaz',
            style: textTheme.titleSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Tema Visual'),
                  subtitle: Text(
                    currentThemeMode == AppThemeMode.system
                        ? 'Sistema'
                        : currentThemeMode == AppThemeMode.dark
                            ? 'Oscuro'
                            : 'Claro',
                  ),
                  trailing: SegmentedButton<AppThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: AppThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.system,
                        icon: Icon(Icons.auto_mode_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 18),
                      ),
                    ],
                    selected: {currentThemeMode},
                    onSelectionChanged: (Set<AppThemeMode> newSelection) {
                      if (vibration) HapticFeedback.selectionClick();
                      ref.read(themeModeProvider.notifier).setMode(newSelection.first);
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.calendar_view_day_outlined),
                  title: const Text('Vista por defecto'),
                  subtitle: Text(isTodayView ? 'Iniciar en "Hoy"' : 'Iniciar en "Mes actual"'),
                  value: isTodayView,
                  onChanged: (val) {
                    if (vibration) HapticFeedback.lightImpact();
                    ref.read(defaultViewProvider.notifier).toggle(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ==============================
          // 2. PREFERENCIAS
          // ==============================
          Text(
            'Preferencias',
            style: textTheme.titleSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Notificaciones Push'),
                  subtitle: const Text('Alertas de nuevos pedidos'),
                  value: pushNotifs,
                  onChanged: (val) {
                    if (vibration) HapticFeedback.lightImpact();
                    ref.read(pushNotificationsProvider.notifier).toggle(val);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: const Text('Vibración en botones'),
                  subtitle: const Text('Respuesta táctil al tocar'),
                  value: vibration,
                  onChanged: (val) {
                    // Si el usuario activa la vibración, hacer que vibre enseguida para confirmarle
                    if (val) HapticFeedback.lightImpact();
                    ref.read(vibrationProvider.notifier).toggle(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ==============================
          // 4. ALMACENAMIENTO
          // ==============================
          Text(
            'Almacenamiento',
            style: textTheme.titleSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Limpiar Caché'),
              subtitle: const Text('Libera espacio de archivos temporales'),
              trailing: _isClearingCache
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                if (vibration) HapticFeedback.lightImpact();
                if (!_isClearingCache) _clearCache();
              },
            ),
          ),
          const SizedBox(height: 32),

          // ==============================
          // 5. ADMINISTRACIÓN DEL NEGOCIO
          // ==============================
          if (user?.isAdmin ?? false) ...[
            Text(
              'Administración del Negocio',
              style: textTheme.titleSmall?.copyWith(
                color: cs.tertiary, // Color distinto
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.tertiary.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.local_shipping_outlined, color: cs.tertiary),
                    title: const Text('Ajustar costos de envío'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsPage())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.schedule_outlined, color: cs.tertiary),
                    title: const Text('Horarios de atención'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsPage())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}
