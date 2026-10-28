// Lamma - by Mohamed Ibrahim

class BootstrapData {
  final int version;
  final String lastUpdated;
  final List<CategoryItem> categories;
  final List<SpyWordPackData> spyPacks;
  final List<CharadesCategoryData> charadesCategories;
  final List<AvatarItem> avatars;
  final List<RulePageData> rulePages;
  final Map<String, dynamic> settings;

  const BootstrapData({
    required this.version,
    required this.lastUpdated,
    required this.categories,
    required this.spyPacks,
    required this.charadesCategories,
    required this.avatars,
    required this.rulePages,
    required this.settings,
  });

  factory BootstrapData.fromJson(Map<String, dynamic> json) {
    return BootstrapData(
      version: json['version'] as int? ?? 1,
      lastUpdated: json['last_updated'] as String? ?? '',
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => CategoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      spyPacks: ((json['spy'] as Map<String, dynamic>?)?['packs'] as List<dynamic>? ?? [])
          .map((e) => SpyWordPackData.fromJson(e as Map<String, dynamic>))
          .toList(),
      charadesCategories: ((json['charades'] as Map<String, dynamic>?)?['categories'] as List<dynamic>? ?? [])
          .map((e) => CharadesCategoryData.fromJson(e as Map<String, dynamic>))
          .toList(),
      avatars: (json['avatars'] as List<dynamic>? ?? [])
          .map((e) => AvatarItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      rulePages: (json['rule_pages'] as List<dynamic>? ?? [])
          .map((e) => RulePageData.fromJson(e as Map<String, dynamic>))
          .toList(),
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'last_updated': lastUpdated,
    'categories': categories.map((e) => e.toJson()).toList(),
    'spy': {'packs': spyPacks.map((e) => e.toJson()).toList()},
    'charades': {'categories': charadesCategories.map((e) => e.toJson()).toList()},
    'avatars': avatars.map((e) => e.toJson()).toList(),
    'rule_pages': rulePages.map((e) => e.toJson()).toList(),
    'settings': settings,
  };
}

class CategoryItem {
  final int id;
  final String slug;
  final String nameAr;
  final String emoji;
  final String kind;
  final int sortOrder;

  const CategoryItem({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.emoji,
    required this.kind,
    required this.sortOrder,
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) => CategoryItem(
    id: json['id'] as int? ?? 0,
    slug: json['slug'] as String? ?? '',
    nameAr: json['name_ar'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '',
    kind: json['kind'] as String? ?? 'trivia',
    sortOrder: json['sort_order'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'name_ar': nameAr,
    'emoji': emoji,
    'kind': kind,
    'sort_order': sortOrder,
  };
}

class SpyWordPackData {
  final int id;
  final String slug;
  final String nameAr;
  final List<String> words;

  const SpyWordPackData({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.words,
  });

  factory SpyWordPackData.fromJson(Map<String, dynamic> json) => SpyWordPackData(
    id: json['id'] as int? ?? 0,
    slug: json['slug'] as String? ?? '',
    nameAr: json['name_ar'] as String? ?? '',
    words: (json['words'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'name_ar': nameAr,
    'words': words,
  };
}

class CharadesCategoryData {
  final int id;
  final String slug;
  final String nameAr;
  final List<String> words;

  const CharadesCategoryData({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.words,
  });

  factory CharadesCategoryData.fromJson(Map<String, dynamic> json) => CharadesCategoryData(
    id: json['id'] as int? ?? 0,
    slug: json['slug'] as String? ?? '',
    nameAr: json['name_ar'] as String? ?? '',
    words: (json['words'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'name_ar': nameAr,
    'words': words,
  };
}

class AvatarItem {
  final int id;
  final String emoji;
  final String nameAr;
  final int sortOrder;

  const AvatarItem({
    required this.id,
    required this.emoji,
    required this.nameAr,
    required this.sortOrder,
  });

  factory AvatarItem.fromJson(Map<String, dynamic> json) => AvatarItem(
    id: json['id'] as int? ?? 0,
    emoji: json['emoji'] as String? ?? '🦁',
    nameAr: json['name_ar'] as String? ?? '',
    sortOrder: json['sort_order'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'emoji': emoji,
    'name_ar': nameAr,
    'sort_order': sortOrder,
  };
}

class RulePageData {
  final int id;
  final String slug;
  final String titleAr;
  final String accent;
  final List<RuleSection> sections;

  const RulePageData({
    required this.id,
    required this.slug,
    required this.titleAr,
    required this.accent,
    required this.sections,
  });

  factory RulePageData.fromJson(Map<String, dynamic> json) => RulePageData(
    id: json['id'] as int? ?? 0,
    slug: json['slug'] as String? ?? '',
    titleAr: json['title_ar'] as String? ?? '',
    accent: json['accent'] as String? ?? 'saffron',
    sections: (json['sections'] as List<dynamic>? ?? [])
        .map((e) => RuleSection.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'title_ar': titleAr,
    'accent': accent,
    'sections': sections.map((e) => e.toJson()).toList(),
  };
}

class RuleSection {
  final String heading;
  final String kind;
  final List<String> items;

  const RuleSection({
    required this.heading,
    required this.kind,
    required this.items,
  });

  factory RuleSection.fromJson(Map<String, dynamic> json) => RuleSection(
    heading: json['heading'] as String? ?? '',
    kind: json['kind'] as String? ?? 'text',
    items: (json['items'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
  );

  Map<String, dynamic> toJson() => {
    'heading': heading,
    'kind': kind,
    'items': items,
  };
}
