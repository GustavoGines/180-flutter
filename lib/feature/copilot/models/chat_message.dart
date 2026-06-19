enum ChatRole { user, assistant }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final bool isLoading;
  final Map<String, dynamic>? uiWidget;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    this.isLoading = false,
    this.uiWidget,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    bool? isLoading,
    Map<String, dynamic>? uiWidget,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      isLoading: isLoading ?? this.isLoading,
      uiWidget: uiWidget ?? this.uiWidget,
    );
  }
}
