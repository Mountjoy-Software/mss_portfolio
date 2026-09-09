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
    required this.links,
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
  final Map<String, String> links;

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
    links: (json['links'] as Map<String, dynamic>? ?? {}).map(
      (key, value) => MapEntry(key, '$value'),
    ),
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
    required this.url,
  });

  final String slug;
  final String name;
  final String blurb;
  final String details;
  final List<String> stack;
  final String? repo;
  final String? url;

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    slug: json['slug'] as String,
    name: json['name'] as String,
    blurb: json['blurb'] as String? ?? '',
    details: json['details'] as String? ?? '',
    stack: (json['stack'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
    repo: json['repo'] as String?,
    url: json['url'] as String?,
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
        return ChatEvent(ChatEventKind.tool, toolName: json['name'] as String?);
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
  ChatTurn({required this.role, required this.content, this.graphSeed});

  final String role;
  final String? graphSeed;
  String content;

  bool get isGraph => graphSeed != null;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class GraphNode {
  GraphNode({
    required this.id,
    required this.kind,
    required this.title,
    required this.payload,
    this.score,
  });

  final String id;
  final String kind;
  final String title;
  final Map<String, dynamic> payload;
  final double? score;

  bool get isCategory => kind == 'category';

  factory GraphNode.fromJson(Map<String, dynamic> json) {
    final payload = Map<String, dynamic>.from(json)
      ..remove('id')
      ..remove('kind')
      ..remove('title')
      ..remove('score');
    return GraphNode(
      id: json['id'] as String,
      kind: json['kind'] as String? ?? 'unknown',
      title: json['title'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble(),
      payload: payload,
    );
  }
}
