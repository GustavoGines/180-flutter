enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String content;
  final bool isLoading;

  ChatMessage({
    required this.role,
    required this.content,
    this.isLoading = false,
  });

  ChatMessage copyWith({
    ChatRole? role,
    String? content,
    bool? isLoading,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
