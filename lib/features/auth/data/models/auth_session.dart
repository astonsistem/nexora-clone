class AuthSession {
  final String accessToken;
  final String? refreshToken;
  final String? userName;
  final bool? sessionApproved;

  const AuthSession({
    required this.accessToken,
    this.refreshToken,
    this.userName,
    this.sessionApproved,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final user = data['user'] as Map<String, dynamic>?;
    final session = data['session'] as Map<String, dynamic>?;

    return AuthSession(
      accessToken: data['access_token'] as String? ?? '',
      refreshToken: data['refresh_token'] as String?,
      userName: user?['name'] as String? ?? user?['username'] as String?,
      sessionApproved: session?['approved'] as bool?,
    );
  }
}
