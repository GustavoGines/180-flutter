part of '../home_page.dart';

class _ProgressSheetController {
  final void Function(String) _update;
  final VoidCallback _close;

  _ProgressSheetController(this._update, this._close);

  /// Actualiza el texto que se muestra en el sheet.
  void update(String message) => _update(message);

  /// Cierra el sheet.
  void close() => _close();
}

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

  // Clave para guardar la última revisión en SharedPreferences
  static const String _kLastUpdateCheckKey = 'fad_last_check_timestamp';
  // Intervalo mínimo entre revisiones automáticas (ej: 8 horas)
  static const Duration _kUpdateCheckInterval = Duration(hours: 8);

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

    // 👇 MODIFICADO: Ahora usamos el controlador
    _ProgressSheetController? sheetController;
    if (interactive) {
      sheetController = _showProgressSheet(message: 'Buscando actualización…');
    }

    // 1. Define un tiempo mínimo de espera y guarda la hora de inicio
    const minDisplayTime = Duration(milliseconds: 2500); // 2.5 segundos
    final startTime = DateTime.now();

    try {
      final hasUpdate = await checkTesterUpdate();

      // 2. Calcula cuánto tiempo ha pasado
      final duration = DateTime.now().difference(startTime);
      final remainingTime = minDisplayTime - duration;

      // 3. Si la búsqueda fue muy rápida, espera el tiempo restante
      if (remainingTime > Duration.zero) {
        await Future.delayed(remainingTime);
      }

      if (hasUpdate) {
        // ✅ ¡ÉXITO! HAY UPDATE
        if (interactive && sheetController != null) {
          // 1. Actualiza el texto del sheet existente
          sheetController.update('Descargando actualización...');
          // El sheet se queda abierto mostrando "Descargando..."
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nueva versión encontrada. Iniciando actualización…'),
          ),
        );
      } else {
        // ✅ ÉXITO, PERO NO HAY UPDATE
        if (interactive && sheetController != null) {
          // 1. Cierra el sheet de "Buscando..."
          sheetController.close();
        }
        if (!mounted) return;

        // 2. Muestra el sheet "Estás al día" (como pediste)
        if (interactive) {
          await _showResultSheet(
            icon: Icons.check_circle_outline,
            title: 'Estás al día',
            message: 'No hay actualizaciones disponibles por ahora.',
          );
        }
      }
    } catch (e) {
      // ❌ ERROR
      if (interactive && sheetController != null) {
        // 1. Cierra el sheet de "Buscando..."
        sheetController.close();
      }
      if (interactive && mounted) {
        // 2. Muestra el error
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

  // 👇 MODIFICADO: Ahora devuelve el controlador
  _ProgressSheetController _showProgressSheet({required String message}) {
    String currentMessage = message;
    // Esta variable guardará la función setState del builder
    void Function(void Function())? updateState;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // 👇 USA UN STATEFULBUILDER para que el texto sea mutable
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          // 1. Captura la función setState para usarla desde el controlador
          updateState = setState;

          // 2. Esta es la UI de tu sheet (sin cambios, solo usa 'currentMessage')
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                const Icon(Icons.system_update_alt, size: 28),
                const SizedBox(height: 12),
                Text(
                  currentMessage, // Usa la variable de estado
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ),
          );
        },
      ),
    );

    // 3. Define las funciones que usará el controlador
    // 👇 Así es como el linter prefiere que lo escribas
    void close() {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    // 👇 Y así
    void update(String newMessage) {
      if (updateState != null) {
        // Llama al setState del StatefulBuilder para redibujar el texto
        updateState!(() {
          currentMessage = newMessage;
        });
      }
    }

    // 4. Devuelve el controlador con las funciones
    return _ProgressSheetController(update, close);
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
    // --- Lógica de texto ---
    final String pillText;
    final String menuText;

    if (_versionName.isEmpty && _buildNumber.isEmpty) {
      pillText = 'versión';
      menuText = '—';
    } else {
      // ✅ CORREGIDO: Mostrar ambos números
      pillText = 'v$_versionName ($_buildNumber)'; // Ej: v1.0.1 (2)
      menuText = '$_versionName ($_buildNumber)'; // Ej: 1.0.1 (2)
    }
    // --- Fin lógica de texto ---

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
            // ✅ CORREGIDO: Usar el texto del menú
            subtitle: Text(menuText),
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
          // ... (tu decoración de gradiente y sombra está perfecta)
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
              // ✅ CORREGIDO: Usar el texto del pill
              pillText,
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

    final lastCheckMillis = prefs.getInt(_kLastUpdateCheckKey);
    if (lastCheckMillis != null) {
      final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(
        lastCheckMillis,
      );
      final now = DateTime.now();

      // Si la diferencia es MENOR al intervalo, salimos.
      if (now.difference(lastCheckTime) < _kUpdateCheckInterval) {
        // Aún no es tiempo de revisar, salimos silenciosamente.
        return;
      }
    }
    try {
      // Intentamos buscar la actualización (sin mostrar UI)
      await checkTesterUpdate();
    } catch (_) {
      // Ignoramos errores en el chequeo automático,
      // no queremos molestar al usuario.
    } finally {
      // 👇 AÑADIDO: Guardar la hora de esta revisión,
      // sea exitosa o no, para reiniciar el contador de 8 horas.
      await prefs.setInt(
        _kLastUpdateCheckKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }
}
