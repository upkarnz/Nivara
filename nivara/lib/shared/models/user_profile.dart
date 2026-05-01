class UserProfile {
  const UserProfile({
    required this.name,
    required this.nickname,
    required this.gender,
    required this.dob,
    required this.language,
    required this.timezone,
    required this.photoUrl,
  });

  final String name;
  final String nickname;
  final String gender;
  final String dob;
  final String language;
  final String timezone;
  final String photoUrl;

  factory UserProfile.empty() => const UserProfile(
        name: '',
        nickname: '',
        gender: '',
        dob: '',
        language: 'en',
        timezone: 'UTC',
        photoUrl: '',
      );

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        name: map['name'] as String? ?? '',
        nickname: map['nickname'] as String? ?? '',
        gender: map['gender'] as String? ?? '',
        dob: map['dob'] as String? ?? '',
        language: map['language'] as String? ?? 'en',
        timezone: map['timezone'] as String? ?? 'UTC',
        photoUrl: map['photoUrl'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'nickname': nickname,
        'gender': gender,
        'dob': dob,
        'language': language,
        'timezone': timezone,
        'photoUrl': photoUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  UserProfile copyWith({
    String? name,
    String? nickname,
    String? gender,
    String? dob,
    String? language,
    String? timezone,
    String? photoUrl,
  }) =>
      UserProfile(
        name: name ?? this.name,
        nickname: nickname ?? this.nickname,
        gender: gender ?? this.gender,
        dob: dob ?? this.dob,
        language: language ?? this.language,
        timezone: timezone ?? this.timezone,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}

class AssistantConfig {
  const AssistantConfig({
    required this.name,
    required this.voice,
    required this.speed,
    required this.style,
    required this.wakePhrase,
    required this.aiModel,
  });

  final String name;
  final String voice;
  final String speed;
  final String style;
  final String wakePhrase;
  final String aiModel;

  factory AssistantConfig.defaults() => const AssistantConfig(
        name: 'Rocky',
        voice: 'neutral',
        speed: 'normal',
        style: 'friendly',
        wakePhrase: 'Hey Rocky',
        aiModel: 'claude',
      );

  factory AssistantConfig.fromMap(Map<String, dynamic> map) => AssistantConfig(
        name: map['name'] as String? ?? 'Rocky',
        voice: map['voice'] as String? ?? 'neutral',
        speed: map['speed'] as String? ?? 'normal',
        style: map['style'] as String? ?? 'friendly',
        wakePhrase: map['wakePhrase'] as String? ?? 'Hey Rocky',
        aiModel: map['aiModel'] as String? ?? 'claude',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'voice': voice,
        'speed': speed,
        'style': style,
        'wakePhrase': wakePhrase,
        'aiModel': aiModel,
      };
}
