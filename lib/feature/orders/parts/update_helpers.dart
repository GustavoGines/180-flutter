part of '../home_page.dart';

extension _UpdateHelpers on _HomePageState {
  // (Este método sí lo tenías en _HomePageState, muévelo)
  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    // ignore: invalid_use_of_protected_member
    setState(() {
      _versionName = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  // --------------------- Update Checker + Sheets ---------------------

  Future<void> _checkForUpdate({bool interactive = false}) async {
    if (!Platform.isAndroid || kFlavor != 'dev') return;

    if (interactive) {
      final proceed = await _maybeShowTesterExplainerOnce();
      if (!proceed) return;
    }

    if (interactive) {
      final current = await Permission.notification.status;
      if (current.isDenied || current.isRestricted) {
        final granted = await Permission.notification.request();
        if (!granted.isGranted) {
          if (!mounted) return;
          await _showResultSheet(
            icon: Icons.notifications_off_outlined,
            title: 'Notificaciones desactivadas',
            message:
                'Activá las notificaciones para recibir avisos de actualización.',
          );
          return;
        }
      }
      if (await Permission.notification.isPermanentlyDenied) {
        if (!mounted) return;
        await _showResultSheet(
          icon: Icons.notifications_off_outlined,
          title: 'Permiso bloqueado',
          message: 'Abrí Ajustes y activá las notificaciones para esta app.',
        );
        return;
      }
    }

    VoidCallback? close;
    if (interactive) {
      close = _showProgressSheet(message: 'Buscando actualización…');
    }

    try {
      final hasUpdate = await checkTesterUpdate();
      if (interactive && close != null) close();
      if (!mounted) return;

      if (hasUpdate) {
        if (interactive) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nueva versión encontrada. Iniciando actualización…',
              ),
            ),
          );
        }
      } else {
        if (interactive) {
          await _showResultSheet(
            icon: Icons.check_circle_outline,
            title: 'Estás al día',
            message: 'No hay actualizaciones disponibles por ahora.',
          );
        }
      }
    } catch (e) {
      if (interactive && close != null) close();
      if (interactive && mounted) {
        await _showResultSheet(
          icon: Icons.error_outline,
          title: 'No pudimos buscar',
          message: 'Reintentá en unos minutos.\nDetalle: $e',
        );
      }
    }
  }

  Future<bool> _maybeShowTesterExplainerOnce() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'fad_explainer_shown';
    final alreadyShown = prefs.getBool(key) ?? false;
    if (alreadyShown && mounted) return true;

    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Habilitar alertas de pruebas'),
        content: const Text(
          'Para avisarte cuando haya una nueva versión de la app, necesitamos habilitar '
          'las alertas de pruebas UNA sola vez. Se te pedirá iniciar sesión con tu cuenta '
          'de Google y aceptar notificaciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await prefs.setBool(key, true);
      return true;
    }
    return false;
  }

  VoidCallback _showProgressSheet({
    String message = 'Buscando actualización...',
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            const Icon(Icons.system_update_alt, size: 28),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );

    return () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    };
  }

  Future<void> _showResultSheet({
    required IconData icon,
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _versionPillMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Versión',
      onSelected: (value) async {
        if (value == 'check_update') {
          await _checkForUpdate(interactive: true);
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versión instalada'),
            subtitle: Text(
              (_versionName.isEmpty && _buildNumber.isEmpty)
                  ? '—'
                  : _versionName,
            ),
          ),
        ),
        if (kFlavor == 'dev') const PopupMenuDivider(),
        if (kFlavor == 'dev')
          const PopupMenuItem<String>(
            value: 'check_update',
            child: ListTile(
              leading: Icon(Icons.system_update_alt),
              title: Text('Buscar actualización'),
            ),
          ),
      ],
      // Botón "moderno" como trigger del menú
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A4A4A), Color(0xFF6A6A6A)],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              offset: Offset(0, 2),
              color: Colors.black12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              _versionName.isEmpty ? 'versión' : 'v$_versionName',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _autoCheckForUpdateIfEnabled() async {
    if (!Platform.isAndroid || kFlavor != 'dev') return;

    final prefs = await SharedPreferences.getInstance();
    const key = 'fad_explainer_shown';
    final enabled = prefs.getBool(key) ?? false;
    if (!enabled) return;

    final granted = await Permission.notification.isGranted;
    if (!granted) return;

    try {
      await checkTesterUpdate();
    } catch (_) {}
  }
}
