enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String content;
  final bool isLoading;
  final Map<String, dynamic>? uiWidget;

  ChatMessage({
    required this.role,
    required this.content,
    this.isLoading = false,
    this.uiWidget,
  });

  ChatMessage copyWith({
    ChatRole? role,
    String? content,
    bool? isLoading,
    Map<String, dynamic>? uiWidget,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      isLoading: isLoading ?? this.isLoading,
      uiWidget: uiWidget ?? this.uiWidget,
    );
  }
}
