import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/client.dart';
import '../../../../core/models/order.dart';
import '../../../../core/models/order_item.dart';

part 'new_order_controller.freezed.dart';

@freezed
abstract class NewOrderState with _$NewOrderState {
  const NewOrderState._(); // Constructor privado necesario para definir métodos/getters en la clase

  const factory NewOrderState({
    Order? originalOrder, // Si es no nulo, estamos en modo edición
    Client? selectedClient,
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
      0.0, (sum, item) => sum + (item.finalUnitPrice * item.qty));

  /// Total general = Items + Costo de Envío
  double get grandTotal => itemsTotal + deliveryCost;

  /// Saldo a pagar = Total general - Seña depositada
  double get balance => grandTotal - deposit;

  /// Indica si estamos editando un pedido existente
  bool get isEditMode => originalOrder != null;
}

/// Controlador principal de la pantalla de creación/edición de pedidos
class NewOrderController extends AutoDisposeNotifier<NewOrderState> {
  @override
  NewOrderState build() {
    // Estado inicial por defecto (Formulario vacío)
    return const NewOrderState();
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
    state = state.copyWith(startTime: time);
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
}

/// Provider público para acceder al controlador
final newOrderControllerProvider = AutoDisposeNotifierProvider<NewOrderController, NewOrderState>(() {
  return NewOrderController();
});
