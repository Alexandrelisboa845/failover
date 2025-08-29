import 'dart:async';
import 'dart:io';

/// Enumeração dos ambientes disponíveis
enum Environment { production, development, staging }

/// Configurações específicas de cada ambiente
class EnvironmentConfig {
  final String apiUrl;
  final String apiKey;
  final bool enableLogging;
  final bool enableAnalytics;
  final Duration timeout;
  final int maxRetries;

  const EnvironmentConfig({
    required this.apiUrl,
    required this.apiKey,
    required this.enableLogging,
    required this.enableAnalytics,
    required this.timeout,
    required this.maxRetries,
  });
}

/// Classe principal do sistema de failover
class FailoverManager {
  static final FailoverManager _instance = FailoverManager._internal();
  factory FailoverManager() => _instance;
  FailoverManager._internal();

  Environment _currentEnvironment = Environment.development;
  final Map<Environment, EnvironmentConfig> _configs = {};
  final List<Function(Environment)> _listeners = [];
  Timer? _healthCheckTimer;
  bool _isInitialized = false;

  /// Configurações padrão para cada ambiente
  static const Map<Environment, EnvironmentConfig> _defaultConfigs = {
    Environment.production: EnvironmentConfig(
      apiUrl: 'https://api.production.com',
      apiKey: 'prod_key_123',
      enableLogging: false,
      enableAnalytics: true,
      timeout: Duration(seconds: 30),
      maxRetries: 3,
    ),
    Environment.development: EnvironmentConfig(
      apiUrl: 'https://api.dev.com',
      apiKey: 'dev_key_456',
      enableLogging: true,
      enableAnalytics: false,
      timeout: Duration(seconds: 10),
      maxRetries: 1,
    ),
    Environment.staging: EnvironmentConfig(
      apiUrl: 'https://api.staging.com',
      apiKey: 'staging_key_789',
      enableLogging: true,
      enableAnalytics: true,
      timeout: Duration(seconds: 20),
      maxRetries: 2,
    ),
  };

  /// Inicializa o sistema de failover
  Future<void> initialize({
    Environment initialEnvironment = Environment.development,
    Map<Environment, EnvironmentConfig>? customConfigs,
    bool enableHealthCheck = true,
  }) async {
    if (_isInitialized) return;

    _currentEnvironment = initialEnvironment;
    _configs.addAll(_defaultConfigs);

    if (customConfigs != null) {
      _configs.addAll(customConfigs);
    }

    if (enableHealthCheck) {
      await _performHealthCheck();
      _startHealthCheckTimer();
    }

    _isInitialized = true;
  }

  /// Obtém o ambiente atual
  Environment get currentEnvironment => _currentEnvironment;

  /// Obtém a configuração do ambiente atual
  EnvironmentConfig get currentConfig => _configs[_currentEnvironment]!;

  /// Obtém a configuração de um ambiente específico
  EnvironmentConfig? getConfig(Environment environment) {
    return _configs[environment];
  }

  /// Alterna para um ambiente específico
  Future<bool> switchEnvironment(
    Environment newEnvironment, {
    bool skipHealthCheck = false,
  }) async {
    if (!_isInitialized) {
      throw StateError('FailoverManager não foi inicializado');
    }

    if (_currentEnvironment == newEnvironment) return true;

    // Verifica se o novo ambiente está disponível
    if (!_configs.containsKey(newEnvironment)) {
      throw ArgumentError('Ambiente $newEnvironment não configurado');
    }

    // Verifica a saúde do novo ambiente (opcional)
    if (!skipHealthCheck) {
      final isHealthy = await _checkEnvironmentHealth(newEnvironment);
      if (!isHealthy) {
        print('Aviso: Ambiente $newEnvironment não está saudável');
        return false;
      }
    }

    final oldEnvironment = _currentEnvironment;
    _currentEnvironment = newEnvironment;

    // Notifica os listeners sobre a mudança
    for (final listener in _listeners) {
      try {
        listener(newEnvironment);
      } catch (e) {
        print('Erro ao notificar listener: $e');
      }
    }

    print('Ambiente alterado de $oldEnvironment para $newEnvironment');
    return true;
  }

  /// Adiciona um listener para mudanças de ambiente
  void addListener(Function(Environment) listener) {
    _listeners.add(listener);
  }

  /// Remove um listener
  void removeListener(Function(Environment) listener) {
    _listeners.remove(listener);
  }

  /// Executa uma operação com fallback automático
  Future<T> executeWithFallback<T>({
    required Future<T> Function(EnvironmentConfig) operation,
    List<Environment>? fallbackOrder,
    Duration? timeout,
  }) async {
    if (!_isInitialized) {
      throw StateError('FailoverManager não foi inicializado');
    }

    final order =
        fallbackOrder ??
        [
          _currentEnvironment,
          Environment.staging,
          Environment.development,
          Environment.production,
        ];

    Exception? lastException;

    for (final environment in order) {
      if (!_configs.containsKey(environment)) continue;

      try {
        final config = _configs[environment]!;
        final result = await operation(
          config,
        ).timeout(timeout ?? config.timeout);
        return result;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('Falha no ambiente $environment: $e');

        // Se não for o último ambiente, tenta o próximo
        if (environment != order.last) {
          await switchEnvironment(order[order.indexOf(environment) + 1]);
        }
      }
    }

    throw lastException ?? Exception('Todos os ambientes falharam');
  }

  /// Verifica a saúde de todos os ambientes
  Future<Map<Environment, bool>> checkAllEnvironments() async {
    final results = <Environment, bool>{};

    for (final environment in _configs.keys) {
      results[environment] = await _checkEnvironmentHealth(environment);
    }

    return results;
  }

  /// Verifica a saúde do ambiente atual
  Future<bool> _performHealthCheck() async {
    return await _checkEnvironmentHealth(_currentEnvironment);
  }

  /// Verifica a saúde de um ambiente específico
  Future<bool> _checkEnvironmentHealth(Environment environment) async {
    try {
      final config = _configs[environment]!;
      final client = HttpClient();

      final request = await client.getUrl(Uri.parse('${config.apiUrl}/health'));
      request.headers.set('Authorization', 'Bearer ${config.apiKey}');

      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );

      client.close();
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao verificar saúde do ambiente $environment: $e');
      return false;
    }
  }

  /// Inicia o timer de verificação de saúde
  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _performHealthCheck(),
    );
  }

  /// Para o timer de verificação de saúde
  void dispose() {
    _healthCheckTimer?.cancel();
    _listeners.clear();
    _isInitialized = false;
  }

  /// Reseta o manager para estado inicial (útil para testes)
  void reset() {
    dispose();
    _configs.clear();
    _currentEnvironment = Environment.development;
  }

  /// Obtém estatísticas do sistema
  Map<String, dynamic> getStats() {
    return {
      'currentEnvironment': _currentEnvironment.name,
      'isInitialized': _isInitialized,
      'totalConfigs': _configs.length,
      'totalListeners': _listeners.length,
      'healthCheckActive': _healthCheckTimer?.isActive ?? false,
    };
  }
}

/// Classe utilitária para facilitar o uso do failover
class FailoverHelper {
  static final FailoverManager _manager = FailoverManager();

  /// Inicializa o sistema
  static Future<void> initialize({
    Environment initialEnvironment = Environment.development,
    Map<Environment, EnvironmentConfig>? customConfigs,
    bool enableHealthCheck = true,
  }) async {
    await _manager.initialize(
      initialEnvironment: initialEnvironment,
      customConfigs: customConfigs,
      enableHealthCheck: enableHealthCheck,
    );
  }

  /// Executa uma operação HTTP com fallback
  static Future<HttpClientResponse> httpRequest({
    required String endpoint,
    String method = 'GET',
    Map<String, String>? headers,
    dynamic body,
  }) async {
    return await _manager.executeWithFallback(
      operation: (config) async {
        final client = HttpClient();
        final uri = Uri.parse('${config.apiUrl}$endpoint');

        final request = method == 'GET'
            ? await client.getUrl(uri)
            : method == 'POST'
            ? await client.postUrl(uri)
            : method == 'PUT'
            ? await client.putUrl(uri)
            : await client.deleteUrl(uri);

        request.headers.set('Authorization', 'Bearer ${config.apiKey}');
        request.headers.set('Content-Type', 'application/json');

        if (headers != null) {
          headers.forEach((key, value) {
            request.headers.set(key, value);
          });
        }

        if (body != null) {
          request.write(body.toString());
        }

        final response = await request.close();
        client.close();
        return response;
      },
    );
  }

  /// Obtém o ambiente atual
  static Environment get currentEnvironment => _manager.currentEnvironment;

  /// Obtém a configuração atual
  static EnvironmentConfig get currentConfig => _manager.currentConfig;

  /// Alterna para um ambiente específico
  static Future<bool> switchTo(
    Environment environment, {
    bool skipHealthCheck = false,
  }) async {
    return await _manager.switchEnvironment(
      environment,
      skipHealthCheck: skipHealthCheck,
    );
  }

  /// Adiciona um listener
  static void onEnvironmentChanged(Function(Environment) listener) {
    _manager.addListener(listener);
  }

  /// Obtém estatísticas
  static Map<String, dynamic> getStats() => _manager.getStats();

  /// Libera recursos
  static void dispose() => _manager.dispose();

  /// Reseta o manager (útil para testes)
  static void reset() => _manager.reset();
}
