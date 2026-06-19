import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pasteleria_180_flutter/core/network/dio_client.dart';
import 'models/chat_message.dart';

final copilotControllerProvider = AutoDisposeNotifierProvider<CopilotNotifier, List<ChatMessage>>(() {
  return CopilotNotifier();
});

class CopilotNotifier extends AutoDisposeNotifier<List<ChatMessage>> {
  static const _cacheKey = 'copilot_chat_history';
  static const _lastUpdateKey = 'copilot_chat_last_update';

  bool _hasStartedChat = false;

  @override
  List<ChatMessage> build() {
    _hasStartedChat = false;
    _loadHistory();
    return [
      ChatMessage(
        role: ChatRole.assistant,
        content: '¡Hola! Soy 180 IA. ¿En qué te puedo ayudar hoy?',
      ),
    ];
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      
      // Si pasaron más de 24 horas (86400000 ms), limpiar
      if (DateTime.now().millisecondsSinceEpoch - lastUpdate > 86400000) {
        await prefs.remove(_cacheKey);
        return;
      }
      
      final str = prefs.getString(_cacheKey);
      if (str != null) {
        final List<dynamic> decoded = jsonDecode(str);
        final history = decoded.map((e) {
          return ChatMessage(
            role: e['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
            content: e['content'],
            uiWidget: e['uiWidget'],
          );
        }).toList();
        
        if (history.isNotEmpty) {
          if (!_hasStartedChat) {
            state = history;
          } else {
            // Si ya se envió un mensaje (ej. Smart Handoff), conservar el historial y el mensaje nuevo
            state = [...history, ...state.sublist(1)]; // Saltamos el saludo inicial
          }
        }
      }
    } catch (_) {}
  }

  void _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = state.where((m) => !m.isLoading).map((m) => {
        'role': m.role == ChatRole.user ? 'user' : 'assistant',
        'content': m.content,
        'uiWidget': m.uiWidget,
      }).toList();
      
      await prefs.setString(_cacheKey, jsonEncode(toSave));
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _hasStartedChat = true;

    // 1. Agregar mensaje del usuario
    final userMessage = ChatMessage(role: ChatRole.user, content: text.trim());
    state = [...state, userMessage];
    _saveHistory();

    // 2. Agregar mensaje temporal de carga de la IA
    final loadingMessage = ChatMessage(role: ChatRole.assistant, content: '', isLoading: true);
    state = [...state, loadingMessage];

    try {
      // Filtrar el loader y tomar los últimos 6
      final nonLoadingMessages = state.where((m) => !m.isLoading).toList();
      final recentMessages = nonLoadingMessages.length > 6 
          ? nonLoadingMessages.sublist(nonLoadingMessages.length - 6) 
          : nonLoadingMessages;
          
      final payloadMessages = recentMessages.map((m) => {
        'role': m.role == ChatRole.user ? 'user' : 'assistant',
        'content': m.content
      }).toList();

      final dio = DioClient().dio;
      final response = await dio.post('/copilot/process', data: {'messages': payloadMessages});
      
      final reply = response.data['reply'] ?? 'Hubo un error al procesar la respuesta.';
      final uiWidget = response.data['ui_widget'];

      // 3. Reemplazar mensaje de carga con la respuesta real
      state = [
        ...state.sublist(0, state.length - 1),
        ChatMessage(
          role: ChatRole.assistant, 
          content: reply.toString(),
          uiWidget: uiWidget is Map<String, dynamic> ? uiWidget : null,
        ),
      ];
      _saveHistory();
    } on DioException catch (e) {
      String errorMsg = 'Error de conexión';
      if (e.response != null && e.response?.data != null && e.response?.data['error'] != null) {
        errorMsg = e.response?.data['error'];
      }

      state = [
        ...state.sublist(0, state.length - 1),
        ChatMessage(role: ChatRole.assistant, content: 'Lo siento, ocurrió un error: $errorMsg'),
      ];
    } catch (e) {
      state = [
        ...state.sublist(0, state.length - 1),
        ChatMessage(role: ChatRole.assistant, content: 'Lo siento, ocurrió un error inesperado.'),
      ];
    }
  }

  Future<void> clearChat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      _hasStartedChat = false;
      state = [
        ChatMessage(
          role: ChatRole.assistant,
          content: '¡Hola! Soy 180 IA. ¿En qué te puedo ayudar hoy?',
        ),
      ];
    } catch (_) {}
  }
}
