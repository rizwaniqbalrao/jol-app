// File: models/group_models.dart

class GroupSettings {
  final int maxMembers;
  final bool isPrivate;
  final String? description;

  GroupSettings({
    this.maxMembers = 50,
    this.isPrivate = false,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'maxMembers': maxMembers,
    'isPrivate': isPrivate,
    'description': description,
  };

  factory GroupSettings.fromJson(Map<dynamic, dynamic> json) => GroupSettings(
    maxMembers: json['maxMembers'] ?? 50,
    isPrivate: json['isPrivate'] ?? false,
    description: json['description'],
  );
}

class GroupMember {
  final String id;
  final String name;
  final String role; // 'owner', 'admin', 'member'
  final int joinedAt;
  final bool isActive; // Currently viewing group screen
  final int? lastSeen;

  GroupMember({
    required this.id,
    required this.name,
    this.role = 'member',
    required this.joinedAt,
    this.isActive = false,
    this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'joinedAt': joinedAt,
    'isActive': isActive,
    'lastSeen': lastSeen,
  };

  factory GroupMember.fromJson(String id, Map<dynamic, dynamic> json) => GroupMember(
    id: id,
    name: json['name'] ?? 'Unknown',
    role: json['role'] ?? 'member',
    joinedAt: json['joinedAt'] ?? DateTime.now().millisecondsSinceEpoch,
    isActive: json['isActive'] ?? false,
    lastSeen: json['lastSeen'],
  );

  GroupMember copyWith({
    String? name,
    String? role,
    int? joinedAt,
    bool? isActive,
    int? lastSeen,
  }) {
    return GroupMember(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      isActive: isActive ?? this.isActive,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'owner';
}

class Group {
  final String id;
  final String name;
  final String ownerId;
  final GroupSettings settings;
  final Map<String, GroupMember> members;
  final int createdAt;
  final int? lastActivity;

  Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.settings,
    required this.members,
    required this.createdAt,
    this.lastActivity,
  });

  factory Group.fromJson(String id, Map<dynamic, dynamic> json) {
    Map<String, GroupMember> parseMembers = {};
    if (json['members'] != null) {
      final rawMembers = json['members'];
      if (rawMembers is Map) {
        rawMembers.forEach((key, value) {
          if (value is Map) {
            parseMembers[key.toString()] = GroupMember.fromJson(key.toString(), value);
          }
        });
      }
    }

    return Group(
      id: id,
      name: json['name'] ?? 'Unnamed Group',
      ownerId: json['ownerId'] ?? '',
      settings: GroupSettings.fromJson(json['settings'] ?? {}),
      members: parseMembers,
      createdAt: json['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      lastActivity: json['lastActivity'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'ownerId': ownerId,
    'settings': settings.toJson(),
    'members': members.map((key, value) => MapEntry(key, value.toJson())),
    'createdAt': createdAt,
    'lastActivity': lastActivity,
  };

  int get memberCount => members.length;
  int get activeMemberCount => members.values.where((m) => m.isActive).length;
  bool get isFull => memberCount >= settings.maxMembers;

  List<GroupMember> get activeMembers =>
      members.values.where((m) => m.isActive).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<GroupMember> get allMembers =>
      members.values.toList()
        ..sort((a, b) {
          // Owners first, then admins, then members
          if (a.role != b.role) {
            if (a.isOwner) return -1;
            if (b.isOwner) return 1;
            if (a.isAdmin) return -1;
            if (b.isAdmin) return 1;
          }
          return a.name.compareTo(b.name);
        });
}