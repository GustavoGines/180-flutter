import 'package:flutter/material.dart';
import '../enums/order_status.dart';

// ============================================================
// Fuente única de verdad para colores y traducciones de estado
// Usada por: OrderCard, OrderDetailPage
// ============================================================

// --- Colores base ---
const _kPastelBabyBlue = Color(0xFFDFF1FF);
const _kPastelMint = Color(0xFFD8F6EC);
const _kPastelSand = Color(0xFFF6EEDF);
const _kInkBabyBlue = Color(0xFF8CC5F5);
const _kInkMint = Color(0xFF83D1B9);
const _kInkSand = Color(0xFFC9B99A);
const _kInkRose = Color(0xFFF3A9B9);

/// Fondos pastel por estado de orden.
const Map<OrderStatus, Color> kStatusPastelBg = {
  OrderStatus.pending: Color(0xFFFFF9C4),
  OrderStatus.confirmed: _kPastelMint,
  OrderStatus.ready: Color(0xFFFFE6EF),
  OrderStatus.delivered: _kPastelBabyBlue,
  OrderStatus.canceled: Color(0xFFFFE0E0),
};

/// Color de acento/borde/texto por estado de orden.
const Map<OrderStatus, Color> kStatusInk = {
  OrderStatus.pending: Color(0xFFFBC02D),
  OrderStatus.confirmed: _kInkMint,
  OrderStatus.ready: _kInkRose,
  OrderStatus.delivered: _kInkBabyBlue,
  OrderStatus.canceled: Color(0xFFE57373),
};

/// Texto visible por estado de orden (español).
const Map<OrderStatus, String> kStatusTranslations = {
  OrderStatus.pending: 'Pendiente',
  OrderStatus.confirmed: 'Confirmado',
  OrderStatus.ready: 'Listo',
  OrderStatus.delivered: 'Entregado',
  OrderStatus.canceled: 'Cancelado',
};

/// Fallback de fondo cuando el estado no tiene entrada.
const Color kStatusBgFallback = _kPastelSand;

/// Fallback de tinta cuando el estado no tiene entrada.
const Color kStatusInkFallback = _kInkSand;
