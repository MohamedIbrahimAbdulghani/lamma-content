// Lamma - Category Localization Helper
// توحيد ترجمة أسماء الأقسام للعربية في كل شاشات ورسائل التطبيق

class CategoryLocalization {
  const CategoryLocalization._();

  static const Map<String, String> _triviaMap = {
    'movies': 'أفلام ومسلسلات',
    'guess_movie': 'أفلام ومسلسلات',
    'movie': 'أفلام ومسلسلات',
    'sports': 'كورة مصرية',
    'kora': 'كورة مصرية',
    'sport': 'كورة مصرية',
    'afeehat': 'إفيهات وقفشات',
    'history': 'تاريخ وجغرافيا',
    'general': 'معلومات عامة',
    'all': 'كل الأقسام',
  };

  static const Map<String, String> _charadesMap = {
    'movies': 'أفلام',
    'movie': 'أفلام',
    'series': 'مسلسلات',
    'actions': 'أفعال وحركات',
    'verbs': 'أفعال وحركات',
    'jobs': 'مهن',
    'animals': 'حيوانات',
    'places': 'أماكن',
    'things': 'أشياء',
    'proverbs': 'أمثال',
    'mixed': 'متنوع',
    'all': 'كل الأقسام',
  };

  static const Map<String, String> _spyMap = {
    'places': 'أماكن ومعالم',
    'movies': 'أفلام',
    'movie': 'أفلام',
    'food': 'أكلات شعبية',
    'foods': 'أكلات شعبية',
    'mixed': 'مختلط',
    'all': 'كل الحزم',
  };

  static String getTriviaCategoryName(String slug) {
    final key = slug.trim().toLowerCase();
    return _triviaMap[key] ?? slug;
  }

  static String getTriviaCategoriesLabel(List<String> categories) {
    if (categories.isEmpty || categories.contains('all')) {
      return 'المختارة';
    }
    return categories.map(getTriviaCategoryName).join(' و ');
  }

  static String getCharadesCategoryName(String slug) {
    final key = slug.trim().toLowerCase();
    return _charadesMap[key] ?? slug;
  }

  static String getSpyPackName(String slug) {
    final key = slug.trim().toLowerCase();
    return _spyMap[key] ?? slug;
  }

  static String getCategoryArabicName(String gameType, String slug) {
    switch (gameType.toLowerCase()) {
      case 'trivia':
        return getTriviaCategoryName(slug);
      case 'charades':
        return getCharadesCategoryName(slug);
      case 'spy':
        return getSpyPackName(slug);
      default:
        return _triviaMap[slug.toLowerCase()] ??
            _charadesMap[slug.toLowerCase()] ??
            _spyMap[slug.toLowerCase()] ??
            slug;
    }
  }

  static String canonicalTriviaSlug(String input) {
    final lower = input.trim().toLowerCase();
    if (lower == 'movies' || lower == 'guess_movie' || lower == 'movie' || lower.contains('أفلام') || lower.contains('مسلسل')) {
      return 'movies';
    }
    if (lower == 'sports' || lower == 'kora' || lower == 'sport' || lower.contains('كورة')) {
      return 'sports';
    }
    if (lower == 'afeehat' || lower == 'afeeh' || lower.contains('إفيه')) {
      return 'afeehat';
    }
    if (lower == 'history' || lower.contains('تاريخ') || lower.contains('جغرافيا')) {
      return 'history';
    }
    if (lower == 'general' || lower.contains('عامة')) {
      return 'general';
    }
    return lower;
  }

  static String canonicalSpyPackSlug(String input) {
    final lower = input.trim().toLowerCase();
    if (lower == 'places' || lower.contains('أماكن') || lower.contains('معالم')) return 'places';
    if (lower == 'movies' || lower == 'movie' || lower.contains('أفلام')) return 'movies';
    if (lower == 'food' || lower == 'foods' || lower.contains('أكل')) return 'foods';
    return lower;
  }

  static String canonicalCharadesCategorySlug(String input) {
    final lower = input.trim().toLowerCase();
    if (lower == 'movies' || lower == 'movie' || lower.contains('أفلام')) return 'movies';
    if (lower == 'series' || lower.contains('مسلسل')) return 'series';
    if (lower == 'actions' || lower == 'verbs' || lower.contains('أفعال') || lower.contains('حركات')) return 'actions';
    if (lower == 'jobs' || lower.contains('مهن') || lower.contains('وظائف')) return 'jobs';
    if (lower == 'animals' || lower.contains('حيوان')) return 'animals';
    if (lower == 'mixed' || lower == 'all' || lower.contains('متنوع') || lower.contains('كل')) return 'mixed';
    return lower;
  }
}
