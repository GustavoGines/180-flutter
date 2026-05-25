# 🗺️ Plan de Mejoras — Sistema 180 (Pastelería)
> Basado en auditoría del 2026-05-03 · Versiones: API Laravel 12 · Flutter 1.3.17+32

---

## 📜 Reglas de Ejecución (INAMOVIBLES)

1. **Paso a paso**: Se trabaja una fase a la vez. Nunca dos fases en paralelo.
2. **Permiso explícito**: Al terminar una fase, el agente se detiene por completo. Solo avanza a la siguiente fase cuando el humano lo indique explícitamente (ej. "Avanza a B2").
3. **Plan de vuelo**: Antes de escribir código, listar los archivos exactos a modificar y esperar confirmación.
4. **Commits atómicos**: Al finalizar cada fase con éxito, el agente recuerda al humano hacer un commit antes de continuar.
5. **Sin asumir**: Si algo es ambiguo, preguntar. Nunca asumir ni avanzar por inercia.

---

## 🎯 Estrategia General

**Empezamos por el BACKEND.**

### ¿Por qué primero el backend?
1. **Hay bugs silenciosos activos hoy**: `markAsUnpaid` retorna array crudo, `updateProduct` borra variantes silenciosamente, `ClientResource` expone campo eliminado.
2. **Hay un riesgo de seguridad real**: credenciales en el directorio, sin throttling en login.
3. **Las correcciones del backend son de bajo riesgo** para el usuario final — no cambia la UI.
4. **El frontend depende de que la API sea correcta**: arreglar primero el contrato de datos ahorra trabajo doble.
5. **El refactor del flutter (`new_order_page.dart`)** es el trabajo más grande y se hace mejor cuando la API ya está estabilizada.

---

## 🔴 BACKEND — 180-api (Laravel 12)

### Fase B1 — Seguridad y Limpieza Urgente
> **Esfuerzo**: ~2h · **Riesgo**: bajo · **Impacto**: alto

- [x] **B1.1** — Mover lógica de `env()` en `GoogleCalendarService` a `config/services.php`
  - `GOOGLE_APP_CREDENTIALS_JSON`, `_BASE64`, `_PATH` → `config('services.google.*')`
- [x] **B1.2** — Mover `env('FRONTEND_URL')` en `AppServiceProvider` a `config/app.php` o `config/services.php`
- [x] **B1.3** — Agregar `throttle:10,1` al endpoint `POST /auth/token`
  - En `routes/api.php` o `routes/auth.php`
- [x] **B1.4** — Actualizar `.gitignore` para incluir: `*.json` (credenciales), `creds.b64`, `*.sql`, `*.log`
- [x] **B1.5** — Eliminar `creds.b64` y `pasteleria-180-474918-11d5cae48736.json` del directorio (ya están en `.env`)
  > ⚠️ **ACCIÓN MANUAL DEL HUMANO**: Antes o inmediatamente después de eliminar estos archivos, **rotar las credenciales en Google Cloud Console y Firebase**. El service account key existente debe ser revocado y reemplazado. Eliminar el archivo sin rotar la clave no mitiga el riesgo si ya fue expuesta en algún commit anterior.
- [x] **B1.6** — Eliminar `database/dump-*.sql` commiteado (verificar si tiene datos sensibles)

**✅ Criterio de éxito**: `php artisan config:cache` no rompe Google Calendar. Sin archivos de credenciales en el directorio del proyecto.

---

### Fase B2 — Bugs Silenciosos (alta prioridad)
> **Esfuerzo**: ~3h · **Riesgo**: bajo-medio · **Impacto**: alto

- [x] **B2.1** — Fix `markAsUnpaid` → retornar `new OrderResource($order->fresh([...]))` en lugar de `response()->json($order->fresh(...))`
- [x] **B2.2** — Fix `AdminCatalogController::updateProduct` → cambiar `else { $product->variants()->delete() }` por `if (isset($validated['variants'])) { ... }` — evita borrado silencioso de variantes
- [x] **B2.3** — Fix `ClientResource` → eliminar `'address' => $this->address` (campo eliminado de BD), agregar `'ig_handle'` y `'whatsapp_url'` si no está
- [x] **B2.4** — Fix `Client.php` → eliminar `protected $dates = ['deleted_at']` (deprecated Laravel 10+)
- [x] **B2.5** — Fix `DeviceController` → eliminar métodos vacíos `index()`, `show()`, `update()`, `destroy()` o agregarles `abort(404)`

**✅ Criterio de éxito**: Test `php artisan test` pasa. `markAsUnpaid` retorna estructura igual a `markAsPaid`. Actualizar un producto sin `variants` no borra las existentes.

---

### Fase B3 — Crear `OrderItemResource` + Limpieza de código
> **Esfuerzo**: ~2h · **Riesgo**: muy bajo · **Impacto**: medio

- [x] **B3.1** — Crear `app/Http/Resources/OrderItemResource.php`
- [x] **B3.2** — Usar `OrderItemResource::collection($this->whenLoaded('items'))` en `OrderResource`
- [x] **B3.3** — Mover lógica de auth de `routes/api.php` a `AuthController::createToken()`
- [x] **B3.4** — Limpiar comentarios fantasma en `routes/api.php` (L151-161)
- [x] **B3.5** — Limpiar comentarios `// Note:`, `// Actually`, `// OR` en `ClientController.php`
- [x] **B3.6** — Eliminar `// DB::statement` duplicado en `AppServiceProvider`
- [x] **B3.7** — Actualizar `description` y limpiar ruido en `pubspec.yaml` del flutter (aprovechar la sesión)
- [x] **B3.8** — Reducir paginación en `ClientController::index()` de `paginate(500)` a `paginate($request->query('per_page', 100))` con máximo 200

**✅ Criterio de éxito**: La respuesta de `GET /orders/{id}` incluye items con estructura limpia sin campos redundantes.

---

### Fase B4 — Rendimiento: Caché del catálogo
> **Esfuerzo**: ~2h · **Riesgo**: bajo · **Impacto**: medio-alto

> [!WARNING]
> **Invalidación de caché a prueba de balas**: El caché del catálogo debe invalidarse en **todos** los puntos de mutación (crear, actualizar, borrar producto/filling/extra/variante). Un caché desactualizado que muestre precios o stock incorrectos a los clientes es peor que no tener caché. Usar una clave de caché única y centralizada (ej. constante `CATALOG_CACHE_KEY = 'catalog_v1'`) y verificar que cada método del `AdminCatalogController` llame a `Cache::forget(self::CATALOG_CACHE_KEY)` antes de retornar.

- [x] **B4.1** — Cachear `GET /catalog` con `Cache::remember('catalog', 3600, fn() => [...])`
- [x] **B4.2** — Invalidar el caché en `AdminCatalogController` al crear/actualizar/borrar productos, fillings o extras
- [x] **B4.3** — Quitar `.resolve()` innecesario en `CatalogController`
- [x] **B4.4** — Optimizar `BotOrderService`: pre-cargar todos los `Filling`, `Extra` y `Product` antes del loop (eliminar N+1)
- [x] **B4.5** — Agregar índice en `devices.fcm_token` (nueva migración)
- [x] **B4.6** — Fix FK `client_address_id` en `orders` → agregar `onDelete('set null')` o `'restrict'` según la lógica de negocio

**✅ Criterio de éxito**: `/catalog` tiene header `X-Cache` o responde < 50ms en segunda llamada. Bot procesa un pedido de 5 items con ≤ 3 queries a BD.

---

### Fase B5 — Completar `.env.example` + Testing básico
> **Esfuerzo**: ~3h · **Riesgo**: muy bajo · **Impacto**: alto (documentación)

- [x] **B5.1** — Completar `.env.example` con todas las variables faltantes:
  - `GOOGLE_APP_CREDENTIALS_BASE64`
  - `FRONTEND_URL`
  - `AWS_ENDPOINT` (para Cloudflare R2)
  - `QUEUE_CONNECTION=database` (con comentario explicativo)
  - `FIREBASE_*` variables
- [x] **B5.2** — Escribir test para `ClientController::search` y normalización de teléfonos
- [x] **B5.3** — Escribir test para `checkAvailability` (martes cerrado, cupo lleno, express)
- [x] **B5.4** — Escribir test para `markAsPaid` / `markAsUnpaid` (verificar que ambos retornan `OrderResource`)
- [x] **B5.5** — Consolidar `markAsPaid` / `updateStatus` — son funcionalidades solapadas; decidir cuál es el canónico

**✅ Criterio de éxito**: `php artisan test` pasa con ≥ 15 tests. `.env.example` sirve como documentación completa del proyecto.

---

## 🟦 FRONTEND — 180_flutter

### Fase F1 — Quick wins sin riesgo
> **Esfuerzo**: ~1.5h · **Riesgo**: muy bajo · **Impacto**: inmediato

- [x] **F1.1** — Reemplazar todos los `print()` por `debugPrint()` en `orders_repository.dart`
- [x] **F1.2** — Fix `ref.watch()` → `ref.read()` en el `suggestionsCallback` del TypeAhead (previene leaks)
- [x] **F1.3** — Eliminar import duplicado de riverpod en `firebase_messaging_service.dart`
- [x] **F1.4** — Cambiar import de `flutter/material.dart` por `flutter/foundation.dart` en repositories que solo usan `debugPrint`
- [x] **F1.5** — Actualizar `description` en `pubspec.yaml`
- [x] **F1.6** — Fijar versiones en `pubspec.yaml`:
  - `intl: ^0.19.0`
  - `firebase_app_distribution: ^0.3.6`
  - `firebase_app_distribution_platform_interface: ^0.3.6`
- [x] **F1.7** — Agregar `pasteleria_180_flutter.iml` al `.gitignore`
- [x] **F1.8** — Eliminar `flutter_01.log`, `analysis_output.txt`, `release_notes.txt` de la raíz

**✅ Criterio de éxito**: `flutter analyze` sin warnings nuevos. `flutter pub get` resuelve versiones fijas.

---

### Fase F2 — Extraer lógica de sort + migrar multipart a Dio
> **Esfuerzo**: ~3h · **Riesgo**: medio · **Impacto**: alto

- [x] **F2.1** — Crear `extension OrderListExtension on List<Order>` con método `sortedByDateAndStatus()` en archivo separado (`lib/core/extensions/order_list_extension.dart`)
- [x] **F2.2** — Reemplazar las 4 copias del bloque de sort en `state_providers.dart` / `OrdersWindowNotifier` con la nueva extension
- [x] **F2.3** — Migrar `createOrderWithFiles` de `http` a `FormData` de Dio:
  ```dart
  final formData = FormData.fromMap({...});
  await _dio.post('/orders', data: formData);
  ```
- [x] **F2.4** — Migrar `updateOrderWithFiles` de `http` a `FormData` de Dio con `_method: 'PUT'`
- [x] **F2.5** — Eliminar dependencia `http` del `pubspec.yaml` una vez migrado
- [x] **F2.6** — Verificar que el `AuthInterceptor` aplica correctamente el token en los nuevos requests multipart

**✅ Criterio de éxito**: Upload de imágenes funciona con Dio. Interceptor de auth aplica token automáticamente. `http` eliminado del pubspec.

---

### Fase F3 — Fix `AuthInterceptor` en 401 + `OrderStatus` enum
> **Esfuerzo**: ~2.5h · **Riesgo**: medio · **Impacto**: alto (UX y seguridad)

- [x] **F3.1** — Crear `enum OrderStatus { pending, confirmed, ready, delivered, canceled, unknown }` en `lib/core/enums/order_status.dart`
- [x] **F3.2** — Actualizar `Order.fromJson` para usar el enum (con fallback a `unknown`)
- [x] **F3.3** — Actualizar todos los comparadores de string mágicos (`o.status != 'canceled'`, etc.) para usar el enum
- [x] **F3.4** — Fix `AuthInterceptor` en error 401:
  - Agregar callback `onUnauthorized` al constructor
  - Al recibir 401: borrar token + llamar callback
  - En `DioClient`, pasar callback que llame `ref.invalidate(authTokenProvider)` o equivalente
- [x] **F3.5** — Verificar que GoRouter redirige automáticamente al invalidar el auth state

**✅ Criterio de éxito**: Al recibir 401, el router navega a `/login` automáticamente sin intervención del usuario. El enum de status elimina todos los strings mágicos.

---

### Fase F4 — Refactor `new_order_page.dart` (el más importante)
> **Esfuerzo**: ~8-12h · **Riesgo**: alto (requiere testing manual exhaustivo) · **Impacto**: enorme

> [!IMPORTANT]
> **Regla estricta de rama**: Todo el trabajo de esta fase se realiza **exclusivamente** en una rama separada: `feature/refactor-new-order`. Nunca en `main` ni `develop`. Esto garantiza que la rama principal pueda recibir hotfixes de producción en cualquier momento sin estar bloqueada por el refactor. El merge a `develop` solo ocurre cuando F4d esté 100% completo y testeado manualmente.

> [!IMPORTANT]
> Esta fase se hace en sub-pasos para minimizar el riesgo. **No tocar la lógica, solo mover código.**

#### Sub-fase F4a — Extraer widgets de solo presentación (~2h)
- [x] **F4a.1** — Extraer `_buildTotalsCard` → `lib/feature/orders/new_order/widgets/order_totals_card.dart`
- [x] **F4a.2** — Extraer `_buildDateTimePicker` → `widgets/date_time_picker_row.dart`
- [x] **F4a.3** — Extraer `_buildDeliverySection` → `widgets/delivery_section.dart`
- [x] **F4a.4** — Verificar que la app compila y funciona igual ✓

#### Sub-fase F4b — Extraer `_buildClientSelector` (~2h)
- [x] **F4b.1** — Extraer `_buildClientSelector` → `widgets/client_selector_widget.dart` (ConsumerStatefulWidget)
- [x] **F4b.2** — Pasar los callbacks necesarios como parámetros
- [x] **F4b.3** — Verificar flujo completo de selección de cliente ✓

#### Sub-fase F4c — Extraer `_buildItemsSection` (~3h)
- [x] **F4c.1** — Extraer `_buildItemsSection` y sus helpers → `widgets/order_items_section.dart`
- [x] **F4c.2** — Los callbacks de mutación se pasan como parámetros tipados
- [x] **F4c.3** — Verificar flujo completo de agregar/editar/eliminar items ✓
#### Sub-fase F4d — Crear `NewOrderController` (StateNotifier/Notifier) (~4h)
- [ ] **F4d.1** — Crear `new_order_controller.dart` con `NotifierProvider`
- [ ] **F4d.2** — Migrar variables de estado de `_OrderFormState` al controller
- [ ] **F4d.3** — `new_order_page.dart` pasa a ser < 150 líneas de scaffolding puro
- [ ] **F4d.4** — Testing manual exhaustivo de todo el flujo de creación/edición ✓

#### Sub-fase F4e — Desglosar Diálogos de Items (Post-Controller) (~1.5h)
- [ ] **F4e.1** — Extraer `_addBoxDialog` → `widgets/dialogs/add_box_dialog.dart` (leyendo del Controller)
- [ ] **F4e.2** — Extraer `_addCakeDialog` → `widgets/dialogs/add_cake_dialog.dart`
- [ ] **F4e.3** — Extraer `_addMesaDulceDialog` → `widgets/dialogs/add_mesa_dulce_dialog.dart`
- [ ] **F4e.4** — Limpiar y refactorizar `order_items_section.dart` al mínimo posible.

**✅ Criterio de éxito**: `new_order_page.dart` < 200 líneas. Cada widget en su archivo propio. Cero cambios en comportamiento visible.

---

### Fase F5 — Testing + `riverpod_lint`
> **Esfuerzo**: ~4h · **Riesgo**: muy bajo · **Impacto**: alto (prevención)

- [ ] **F5.1** — Agregar `riverpod_lint` al `pubspec.yaml` (detecta `ref.watch` en callbacks, providers sin `autoDispose`, etc.)
- [ ] **F5.2** — Test unitario: `Order.fromJson()` con casos de fechas edge
- [ ] **F5.3** — Test unitario: `OrderItem.toJson()` verifica `calculated_final_unit_price`
- [ ] **F5.4** — Test unitario: `Client.whatsappUrl` con diferentes formatos de teléfono
- [ ] **F5.5** — Test de provider: `OrdersWindowNotifier.addOrder()` verifica sort correcto
- [ ] **F5.6** — Test de provider: `selectedMonthOrdersProvider` filtra por mes correctamente
- [ ] **F5.7** — Test de provider: `monthlyIncomeProvider` con diferentes estados de pedidos
- [ ] **F5.8** — Widget test: `OrderCard` en light y dark mode

**✅ Criterio de éxito**: `flutter test` con ≥ 15 tests pasando. `flutter analyze` con 0 warnings de riverpod_lint.
