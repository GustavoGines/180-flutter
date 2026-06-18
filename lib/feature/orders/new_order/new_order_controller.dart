import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/client.dart';
import '../../../../core/models/order.dart';
import '../../../../core/models/order_item.dart';
import '../../clients/clients_repository.dart';
import '../orders_repository.dart';
import 'package:collection/collection.dart';
import '../home_page.dart';
import '../order_detail_page.dart';

part 'new_order_controller.freezed.dart';

class ClientExistsException implements Exception {
  final Client clientToRestore;
  ClientExistsException(this.clientToRestore);
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => message;
}

@freezed
abstract class NewOrderState with _$NewOrderState {
  const NewOrderState._(); // Constructor privado necesario para definir métodos/getters en la clase

  const factory NewOrderState({
    Order? originalOrder, // Si es no nulo, estamos en modo edición
    Client? selectedClient,
    @Default('') String prefillClientName,
    @Default([]) List<Map<String, dynamic>> suggestedClients,
    int? selectedAddressId,
    @Default(false) bool isPaid,
    DateTime? eventDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    @Default(0.0) double deposit,
    @Default(0.0) double deliveryCost,
    @Default('') String notes,
    @Default([]) List<OrderItem> items,
    @Default({}) Map<String, XFile> filesToUpload,
    @Default(false) bool isLoading,
    String? error,
  }) = _NewOrderState;

  // --- Getters Matemáticos ---
  
  /// Suma total de todos los items en el carrito
  double get itemsTotal => items.fold(
      0.0, (sum, item) => sum + item.finalLinePrice);

  /// Total general = Items + Costo de Envío
  double get grandTotal => itemsTotal + deliveryCost;

  /// Saldo a pagar = Total general - Seña depositada
  double get balance => grandTotal - deposit;

  /// Indica si estamos editando un pedido existente
  bool get isEditMode => originalOrder != null;

  /// Indica si el formulario tiene datos cargados que podrían perderse
  bool get hasUnsavedChanges {
    if (isEditMode) return true; // En modo edición siempre protegemos la salida por precaución
    return items.isNotEmpty || selectedClient != null || notes.isNotEmpty || deposit > 0 || deliveryCost > 0;
  }
}

/// Controlador principal de la pantalla de creación/edición de pedidos
class NewOrderController extends AutoDisposeNotifier<NewOrderState> {
  @override
  NewOrderState build() {
    // Estado inicial por defecto (Formulario vacío)
    // Modo CREACIÓN: pre-inicializa la fecha de hoy para no confundir al usuario
    final now = DateTime.now();
    return NewOrderState(
      eventDate: DateTime(now.year, now.month, now.day),
    );
  }

  // --- Inicialización (Modo Edición) ---
  void initializeWithOrder(Order order) {
    state = state.copyWith(
      originalOrder: order,
      selectedClient: order.client,
      selectedAddressId: order.clientAddressId,
      isPaid: order.isPaid,
      eventDate: order.eventDate,
      startTime: TimeOfDay.fromDateTime(order.startTime),
      endTime: TimeOfDay.fromDateTime(order.endTime),
      deposit: order.deposit ?? 0.0,
      deliveryCost: order.deliveryCost ?? 0.0,
      notes: order.notes ?? '',
      items: List.from(order.items), // Copiamos la lista para evitar mutaciones directas
    );
  }

  // --- Mutaciones de Cliente ---
  void updateClient(Client? client) {
    state = state.copyWith(
      selectedClient: client,
      selectedAddressId: null, // Si cambia el cliente, reiniciamos la dirección seleccionada
      suggestedClients: [], // Limpiamos las sugerencias al elegir
      prefillClientName: '',
    );
  }

  void updateAddress(int? addressId) {
    state = state.copyWith(selectedAddressId: addressId);
  }

  // --- Mutaciones de Fecha y Hora ---
  void updateDate(DateTime date) {
    state = state.copyWith(eventDate: date);
  }

  void updateStartTime(TimeOfDay time) {
    // Calcula automáticamente endTime = startTime + 1 hora
    final totalMinutes = time.hour * 60 + time.minute + 60;
    final endTime = TimeOfDay(
      hour: (totalMinutes ~/ 60) % 24,
      minute: totalMinutes % 60,
    );
    state = state.copyWith(startTime: time, endTime: endTime);
  }

  void updateEndTime(TimeOfDay time) {
    state = state.copyWith(endTime: time);
  }

  // --- Mutaciones Financieras ---
  void updateDeposit(double amount) {
    state = state.copyWith(deposit: amount);
  }

  void updateDeliveryCost(double amount) {
    state = state.copyWith(deliveryCost: amount);
  }

  void updateIsPaid(bool isPaid) {
    state = state.copyWith(isPaid: isPaid);
  }

  void updateNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  // --- Mutaciones de Items ---
  void addItem(OrderItem item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  void updateItem(int index, OrderItem updatedItem) {
    final newItems = List<OrderItem>.from(state.items);
    newItems[index] = updatedItem;
    state = state.copyWith(items: newItems);
  }

  void updateItems(List<OrderItem> newItems) {
    state = state.copyWith(items: newItems);
  }

  void removeItem(int index) {
    final newItems = List<OrderItem>.from(state.items);
    newItems.removeAt(index);
    state = state.copyWith(items: newItems);
  }

  // --- Mutaciones de Archivos (Fotos de inspiración/mesa dulce) ---
  void addFilesToUpload(Map<String, XFile> files) {
    final newFiles = Map<String, XFile>.from(state.filesToUpload);
    newFiles.addAll(files);
    state = state.copyWith(filesToUpload: newFiles);
  }
  
  void updateFilesToUpload(Map<String, XFile> files) {
    state = state.copyWith(filesToUpload: files);
  }

  void removeFile(String localPath) {
    final newFiles = Map<String, XFile>.from(state.filesToUpload);
    newFiles.remove(localPath);
    state = state.copyWith(filesToUpload: newFiles);
  }

  // --- Estado de UI ---
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }
  
  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  // --- Lógica de Negocio (API) ---

  /// Guarda el pedido (Crea o Actualiza)
  Future<Order> saveOrder() async {
    // 1. Validaciones
    if (state.deposit > state.grandTotal + 0.01) {
      throw ValidationException('El monto de la seña/depósito no puede ser mayor al TOTAL del pedido. Verifica los valores.');
    }
    if (state.deliveryCost > 0 && state.selectedAddressId == null) {
      throw ValidationException('Si hay costo de envío, debes seleccionar una dirección de entrega.');
    }
    if (state.selectedClient == null || state.items.isEmpty) {
      throw ValidationException('Revisa los campos obligatorios: Cliente y al menos un Producto.');
    }
    if (state.eventDate == null) {
      throw ValidationException('Debes seleccionar una fecha para el evento.');
    }
    if (state.grandTotal <= 0 && state.items.isNotEmpty) {
      throw ValidationException('El total calculado es cero o negativo. Revisa los precios de los productos.');
    }

    setLoading(true);

    try {
      final fmt = DateFormat('yyyy-MM-dd');
      String t(TimeOfDay x) =>
          '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';

      final payload = {
        'client_id': state.selectedClient!.id,
        'event_date': fmt.format(state.eventDate ?? DateTime.now()),
        'start_time': t(state.startTime ?? const TimeOfDay(hour: 9, minute: 0)),
        'end_time': t(state.endTime ?? const TimeOfDay(hour: 10, minute: 0)),
        'status': state.isEditMode ? state.originalOrder!.status : 'confirmed',
        'deposit': state.deposit,
        'delivery_cost': state.deliveryCost > 0 ? state.deliveryCost : null,
        'notes': state.notes.trim().isEmpty ? null : state.notes.trim(),
        'client_address_id': state.selectedAddressId,
        'is_paid': state.isPaid,
        'items': state.items.map((item) => item.toJson()).toList(),
      };

      final ordersRepo = ref.read(ordersRepoProvider);
      
      if (state.isEditMode) {
        final Order updatedOrder = await ordersRepo.updateOrderWithFiles(
          state.originalOrder!.id, 
          payload, 
          state.filesToUpload,
        );
        
        await ref.read(ordersWindowProvider.notifier).updateOrder(updatedOrder);
        
        // No necesitamos esperar esto, pero invalida el proveedor de detalle
        ref.invalidate(orderByIdProvider(state.originalOrder!.id));
        
        return updatedOrder;
      } else {
        final Order createdOrder = await ordersRepo.createOrderWithFiles(
          payload, 
          state.filesToUpload,
        );
        
        await ref.read(ordersWindowProvider.notifier).addOrder(createdOrder);
        
        return createdOrder;
      }
    } catch (e) {
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// Crea un nuevo cliente y lo selecciona automáticamente
  Future<Client> createClient(String name, String? phone) async {
    setLoading(true);
    try {
      final newClient = await ref.read(clientsRepoProvider).createClient({
        'name': name.trim(),
        'phone': phone?.trim(),
      });
      
      updateClient(newClient);
      return newClient;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 && e.response?.data['client'] != null) {
        final clientData = e.response?.data['client'];
        final clientToRestore = Client.fromJson(
          (clientData as Map).map((k, v) => MapEntry(k.toString(), v)),
        );
        throw ClientExistsException(clientToRestore);
      }
      final msg = e.response?.data['message'] as String? ?? 'Error al crear cliente.';
      throw Exception(msg);
    } catch (e) {
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// Restaura un cliente eliminado y lo selecciona
  Future<Client> restoreClient(int clientId) async {
    setLoading(true);
    try {
      final restoredClient = await ref.read(clientsRepoProvider).restoreClient(clientId);
      
      ref.invalidate(clientsListProvider(''));
      ref.invalidate(trashedClientsProvider);
      
      updateClient(restoredClient);
      return restoredClient;
    } catch (e) {
      rethrow;
    } finally {
      setLoading(false);
    }
  }
  /// Carga el estado del formulario a partir de la interpretación del Asistente de Voz
  Future<void> prefillFromVoiceAssistant({
    required String clientName,
    required bool isNewClient,
    DateTime? eventDate,
    TimeOfDay? startTime,                         // BUG-V02: nuevo parámetro para el horario
    List<OrderItem>? items,
    List<Map<String, dynamic>>? suggestedClients,
  }) async {
    setLoading(true);
    try {
      if (eventDate != null) {
        updateDate(eventDate);
      }
      // BUG-V02: Inyectar el horario si la IA lo detectó
      if (startTime != null) {
        updateStartTime(startTime); // updateStartTime ya calcula endTime = startTime + 1h
      }
      if (items != null && items.isNotEmpty) {
        updateItems(items);
      }

      if (isNewClient) {
        state = state.copyWith(
          prefillClientName: clientName,
          suggestedClients: suggestedClients ?? [],
        );
      } else {
        // Buscar cliente existente
        final result = await ref.read(clientsRepoProvider).searchClients(query: clientName);
        if (result.isNotEmpty) {
          updateClient(result.first);
        }
      }
    } catch (e) {
      // Ignorar fallos de búsqueda automática
    } finally {
      setLoading(false);
    }
  }
}

/// Provider público para acceder al controlador
final newOrderControllerProvider = AutoDisposeNotifierProvider<NewOrderController, NewOrderState>(() {
  return NewOrderController();
});
