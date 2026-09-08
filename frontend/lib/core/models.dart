class Profile {
  const Profile({
    required this.name,
    required this.business,
    required this.tagline,
    required this.summary,
    required this.email,
    required this.location,
    required this.skills,
    required this.experience,
    required this.projects,
  });

  final String name;
  final String business;
  final String tagline;
  final String summary;
  final String email;
  final String location;
  final Map<String, List<String>> skills;
  final List<Experience> experience;
  final List<Project> projects;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    name: json['name'] as String,
    business: json['business'] as String,
    tagline: json['tagline'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    email: json['email'] as String? ?? '',
    location: json['location'] as String? ?? '',
    skills: (json['skills'] as Map<String, dynamic>? ?? {}).map(
      (key, value) => MapEntry(
        key,
        (value as List<dynamic>).map((e) => e as String).toList(),
      ),
    ),
    experience: (json['experience'] as List<dynamic>? ?? [])
        .map((e) => Experience.fromJson(e as Map<String, dynamic>))
        .toList(),
    projects: (json['projects'] as List<dynamic>? ?? [])
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class Experience {
  const Experience({
    required this.company,
    required this.role,
    required this.start,
    required this.end,
    required this.highlights,
    required this.stack,
  });

  final String company;
  final String role;
  final String start;
  final String end;
  final List<String> highlights;
  final List<String> stack;

  factory Experience.fromJson(Map<String, dynamic> json) => Experience(
    company: json['company'] as String,
    role: json['role'] as String,
    start: json['start'] as String? ?? '',
    end: json['end'] as String? ?? '',
    highlights: (json['highlights'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
    stack: (json['stack'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
  );
}

class Project {
  const Project({
    required this.slug,
    required this.name,
    required this.blurb,
    required this.details,
    required this.stack,
    required this.repo,
  });

  final String slug;
  final String name;
  final String blurb;
  final String details;
  final List<String> stack;
  final String? repo;

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    slug: json['slug'] as String,
    name: json['name'] as String,
    blurb: json['blurb'] as String? ?? '',
    details: json['details'] as String? ?? '',
    stack: (json['stack'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
    repo: json['repo'] as String?,
  );
}

enum ChatEventKind { token, tool, done, error }

class ChatEvent {
  const ChatEvent(this.kind, {this.text = '', this.toolName, this.usage});

  final ChatEventKind kind;
  final String text;
  final String? toolName;
  final Map<String, dynamic>? usage;

  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    switch (json['event'] as String?) {
      case 'token':
        return ChatEvent(ChatEventKind.token, text: json['text'] as String);
      case 'tool':
        return ChatEvent(
          ChatEventKind.tool,
          toolName: json['name'] as String?,
        );
      case 'done':
        return ChatEvent(ChatEventKind.done, usage: json);
      default:
        return ChatEvent(
          ChatEventKind.error,
          text: json['message'] as String? ?? 'Something went wrong.',
        );
    }
  }
}

class ChatTurn {
  ChatTurn({required this.role, required this.content});

  final String role;
  String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}
