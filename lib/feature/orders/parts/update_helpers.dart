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
      final proceed = await maybeShowTesterExplainerOnce(context);
      if (!proceed) return;
    }

    // 1️⃣ Pedir permiso de notificaciones si el usuario lo fuerza manualmente
    if (interactive) {
      final current = await Permission.notification.status;
      if (current.isDenied || current.isRestricted) {
        final granted = await Permission.notification.request();
        if (!granted.isGranted) {
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
        await _showResultSheet(
          icon: Icons.notifications_off_outlined,
          title: 'Permiso bloqueado',
          message: 'Abrí Ajustes y activá las notificaciones para esta app.',
        );
        return;
      }
    }

    // 2️⃣ Mostrar sheet inicial de progreso
    _ProgressSheetController? sheetController;
    if (interactive) {
      sheetController = _showProgressSheet(message: 'Buscando actualización…');
    }

    const minDisplayTime = Duration(milliseconds: 2500);
    final startTime = DateTime.now();

    try {
      // 3️⃣ Llamamos al método que realmente distingue entre “hay update” y “no hay”
      final hasUpdate = await checkTesterUpdate(interactive: interactive);

      // Espera mínima de UX
      final elapsed = DateTime.now().difference(startTime);
      final remaining = minDisplayTime - elapsed;
      if (remaining > Duration.zero) await Future.delayed(remaining);

      // =======================
      // 🔁 Si hay actualización
      // =======================
      if (hasUpdate) {
        if (sheetController != null) {
          sheetController.update('Nueva versión encontrada…');
        }

        // 🔹 Mostrar feedback antes de descargar
        await Future.delayed(const Duration(milliseconds: 800));
        if (sheetController != null) {
          sheetController.update('Descargando actualización…');
        }

        // No hacemos nada aquí, porque `updateIfNewReleaseAvailable()`
        // ya maneja internamente el proceso de descarga y de instalación.

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Actualización iniciada. La app se reiniciará al finalizar.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        // ============================
        // 🟢 No hay nueva actualización
        // ============================
        if (sheetController != null) sheetController.close();

        await _showResultSheet(
          icon: Icons.check_circle_outline,
          title: 'Estás al día',
          message: 'No hay actualizaciones disponibles por ahora.',
        );
      }
    } catch (e) {
      // =====================
      // ❌ ERROR EN PROCESO
      // =====================
      if (sheetController != null) sheetController.close();

      await _showResultSheet(
        icon: Icons.error_outline,
        title: 'No pudimos buscar',
        message: 'Reintentá en unos minutos.\nDetalle: $e',
      );
    }
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
      pillText = _versionName; // Ej: v1.0.1
      menuText = _versionName; // Ej: 1.0.1
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
      await checkTesterUpdate(interactive: false);
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
