import 'package:flutter_test/flutter_test.dart';
import 'package:failover/failover.dart';
import 'dart:async';

void main() {
  group('Sistema de Failover - Testes', () {
    late FailoverManager manager;

    setUp(() {
      manager = FailoverManager();
    });

    tearDown(() {
      manager.dispose();
    });

    group('EnvironmentConfig', () {
      test('deve criar configuração válida', () {
        final config = EnvironmentConfig(
          apiUrl: 'https://api.test.com',
          apiKey: 'test_key',
          enableLogging: true,
          enableAnalytics: false,
          timeout: Duration(seconds: 30),
          maxRetries: 3,
        );

        expect(config.apiUrl, equals('https://api.test.com'));
        expect(config.apiKey, equals('test_key'));
        expect(config.enableLogging, isTrue);
        expect(config.enableAnalytics, isFalse);
        expect(config.timeout, equals(Duration(seconds: 30)));
        expect(config.maxRetries, equals(3));
      });
    });

    group('FailoverManager - Inicialização', () {
      test('deve inicializar com ambiente padrão', () async {
        await manager.initialize(enableHealthCheck: false);

        expect(manager.currentEnvironment, equals(Environment.development));
        expect(manager.currentConfig, isNotNull);
        expect(manager.getStats()['isInitialized'], isTrue);
      });

      test('deve inicializar com ambiente específico', () async {
        await manager.initialize(
          initialEnvironment: Environment.production,
          enableHealthCheck: false,
        );

        expect(manager.currentEnvironment, equals(Environment.production));
        expect(manager.currentConfig.apiUrl, contains('production'));
      });

      test('deve inicializar com configurações customizadas', () async {
        final customConfigs = {
          Environment.production: EnvironmentConfig(
            apiUrl: 'https://custom.prod.com',
            apiKey: 'custom_prod_key',
            enableLogging: false,
            enableAnalytics: true,
            timeout: Duration(seconds: 60),
            maxRetries: 5,
          ),
        };

        await manager.initialize(
          initialEnvironment: Environment.production,
          customConfigs: customConfigs,
          enableHealthCheck: false,
        );

        final config = manager.getConfig(Environment.production);
        expect(config?.apiUrl, equals('https://custom.prod.com'));
        expect(config?.apiKey, equals('custom_prod_key'));
        expect(config?.timeout.inSeconds, equals(60));
        expect(config?.maxRetries, equals(5));
      });
    });

    group('FailoverManager - Alternância de Ambiente', () {
      setUp(() async {
        await manager.initialize(enableHealthCheck: false);
      });

      test('deve alternar para ambiente válido', () async {
        final success = await manager.switchEnvironment(
          Environment.staging,
          skipHealthCheck: true,
        );

        expect(success, isTrue);
        expect(manager.currentEnvironment, equals(Environment.staging));
      });

      test('deve notificar listeners sobre mudanças', () async {
        Environment? notifiedEnvironment;

        manager.addListener((environment) {
          notifiedEnvironment = environment;
        });

        await manager.switchEnvironment(
          Environment.staging,
          skipHealthCheck: true,
        );

        expect(notifiedEnvironment, equals(Environment.staging));
      });

      test('deve remover listeners', () async {
        Environment? notifiedEnvironment;

        final listener = (Environment environment) {
          notifiedEnvironment = environment;
        };

        manager.addListener(listener);
        manager.removeListener(listener);

        await manager.switchEnvironment(
          Environment.staging,
          skipHealthCheck: true,
        );

        expect(notifiedEnvironment, isNull);
      });
    });

    group('FailoverManager - Operações com Fallback', () {
      setUp(() async {
        await manager.initialize(enableHealthCheck: false);
      });

      test('deve executar operação bem-sucedida', () async {
        final result = await manager.executeWithFallback(
          operation: (config) async {
            return 'Operação bem-sucedida';
          },
        );

        expect(result, equals('Operação bem-sucedida'));
      });

      test('deve respeitar timeout', () async {
        expect(
          () => manager.executeWithFallback(
            operation: (config) async {
              await Future.delayed(Duration(seconds: 10));
              return 'Operação lenta';
            },
            timeout: Duration(seconds: 1),
          ),
          throwsA(isA<TimeoutException>()),
        );
      });
    });

    group('FailoverHelper', () {
      setUp(() async {
        await FailoverHelper.initialize(enableHealthCheck: false);
      });

      tearDown(() {
        FailoverHelper.dispose();
      });

      test('deve fornecer acesso ao ambiente atual', () {
        expect(FailoverHelper.currentEnvironment, isNotNull);
        expect(FailoverHelper.currentConfig, isNotNull);
      });

      test('deve alternar ambiente via helper', () async {
        final success = await FailoverHelper.switchTo(
          Environment.staging,
          skipHealthCheck: true,
        );
        expect(success, isTrue);
        expect(FailoverHelper.currentEnvironment, equals(Environment.staging));
      });

      test('deve adicionar listener via helper', () async {
        Environment? notifiedEnvironment;

        FailoverHelper.onEnvironmentChanged((environment) {
          notifiedEnvironment = environment;
        });

        await FailoverHelper.switchTo(
          Environment.staging,
          skipHealthCheck: true,
        );

        expect(notifiedEnvironment, equals(Environment.staging));
      });

      test('deve fornecer estatísticas', () {
        final stats = FailoverHelper.getStats();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['currentEnvironment'], isNotNull);
        expect(stats['isInitialized'], isTrue);
      });
    });

    group('Casos de Borda', () {
      test('deve lidar com inicialização sem configurações', () async {
        await manager.initialize(enableHealthCheck: false);

        expect(manager.currentEnvironment, equals(Environment.development));
        expect(manager.currentConfig, isNotNull);
      });

      test('deve lidar com múltiplos listeners', () async {
        await manager.initialize(enableHealthCheck: false);

        int listener1Calls = 0;
        int listener2Calls = 0;

        manager.addListener((_) => listener1Calls++);
        manager.addListener((_) => listener2Calls++);

        await manager.switchEnvironment(
          Environment.staging,
          skipHealthCheck: true,
        );

        expect(listener1Calls, equals(1));
        expect(listener2Calls, equals(1));
      });

      test('deve lidar com listener que lança exceção', () async {
        await manager.initialize(enableHealthCheck: false);

        manager.addListener((_) {
          throw Exception('Erro no listener');
        });

        // Não deve quebrar a aplicação
        expect(
          () => manager.switchEnvironment(
            Environment.staging,
            skipHealthCheck: true,
          ),
          returnsNormally,
        );
      });

      test('deve lidar com dispose múltiplas vezes', () {
        expect(() => manager.dispose(), returnsNormally);
        expect(() => manager.dispose(), returnsNormally);
      });
    });
  });
}
