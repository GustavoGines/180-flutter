import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteleria_180_flutter/core/network/dio_client.dart';
import 'models/chat_message.dart';

final copilotControllerProvider = AutoDisposeNotifierProvider<CopilotNotifier, List<ChatMessage>>(() {
  return CopilotNotifier();
});

class CopilotNotifier extends AutoDisposeNotifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() {
    return [
      ChatMessage(
        role: ChatRole.assistant,
        content: '¡Hola! Soy Copiloto 180. ¿En qué te puedo ayudar hoy?',
      ),
    ];
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 1. Agregar mensaje del usuario
    final userMessage = ChatMessage(role: ChatRole.user, content: text.trim());
    state = [...state, userMessage];

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

      // 3. Reemplazar mensaje de carga con la respuesta real
      state = [
        ...state.sublist(0, state.length - 1),
        ChatMessage(role: ChatRole.assistant, content: reply.toString()),
      ];
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
}
