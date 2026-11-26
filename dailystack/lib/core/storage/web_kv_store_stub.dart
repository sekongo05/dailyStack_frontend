/// Stockage clé-valeur en mémoire pour la VM Dart et `flutter test`.
class WebKvStore {
  static final Map<String, String> _memoryStore = <String, String>{};

  String? read(String key) => _memoryStore[key];

  void write(String key, String value) {
    _memoryStore[key] = value;
  }

  void remove(String key) {
    _memoryStore.remove(key);
  }

  void clearAll() {
    _memoryStore.clear();
  }
}
