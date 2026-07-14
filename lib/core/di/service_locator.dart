/// Lightweight service locator — single source for dependency wiring.
///
/// Usage:
///   final locator = ServiceLocator();
///   locator.register<IConfigService>(() => ConfigService(platform));
///   locator.get<IConfigService>();
///
/// Both CLI and Flutter use the same registration pattern,
/// eliminating the 131-line main() factory.
class ServiceLocator {
  final _factories = <Type, dynamic Function(ServiceLocator)>{};
  final _singletons = <Type, dynamic>{};

  /// Register a lazy singleton factory.
  void register<T>(dynamic Function(ServiceLocator) factory) {
    _factories[T] = factory;
  }

  /// Register an existing instance directly.
  void registerInstance<T>(T instance) {
    _singletons[T] = instance;
  }

  /// Resolve — creates on first call, returns cached thereafter.
  T get<T>() {
    final type = T;
    if (_singletons.containsKey(type)) return _singletons[type] as T;
    final factory = _factories[type];
    if (factory == null) {
      throw ArgumentError('Service not registered: $T');
    }
    final instance = factory(this) as T;
    _singletons[type] = instance;
    return instance;
  }

  /// Whether a service is already registered.
  bool isRegistered<T>() =>
      _singletons.containsKey(T) || _factories.containsKey(T);

  void dispose() {
    for (final instance in _singletons.values) {
      if (instance is Disposable) instance.dispose();
    }
    _singletons.clear();
    _factories.clear();
  }
}

abstract class Disposable {
  void dispose();
}
