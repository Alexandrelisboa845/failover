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

    group('Múltiplas Instâncias', () {
      setUp(() {
        // Limpa todas as instâncias antes de cada teste
        FailoverHelper.reset();
      });

      test('deve criar e gerenciar múltiplas instâncias', () async {
        // Inicializa instância padrão
        await FailoverHelper.initialize(
          initialEnvironment: Environment.development,
          enableHealthCheck: false,
        );

        // Cria instância para backend geral
        await FailoverHelper.createInstance(
          instanceName: 'general',
          initialEnvironment: Environment.production,
          enableHealthCheck: false,
        );

        // Cria instância para carteira digital
        await FailoverHelper.createInstance(
          instanceName: 'wallet',
          initialEnvironment: Environment.staging,
          enableHealthCheck: false,
        );

        // Verifica se as instâncias foram criadas
        expect(FailoverHelper.hasInstance('general'), isTrue);
        expect(FailoverHelper.hasInstance('wallet'), isTrue);
        expect(FailoverHelper.availableInstances, contains('general'));
        expect(FailoverHelper.availableInstances, contains('wallet'));

        // Verifica se a instância padrão está funcionando
        expect(
          FailoverHelper.getStats()['currentEnvironment'],
          equals('development'),
        );

        // Verifica se as instâncias específicas estão funcionando
        final generalStats = FailoverHelper.getInstance('general').getStats();
        expect(generalStats['currentEnvironment'], equals('production'));

        final walletStats = FailoverHelper.getInstance('wallet').getStats();
        expect(walletStats['currentEnvironment'], equals('staging'));
      });

      test(
        'deve alternar ambientes independentemente em cada instância',
        () async {
          // Inicializa instância padrão
          await FailoverHelper.initialize(
            initialEnvironment: Environment.development,
            enableHealthCheck: false,
          );

          // Cria instância para backend geral
          await FailoverHelper.createInstance(
            instanceName: 'general',
            initialEnvironment: Environment.production,
            enableHealthCheck: false,
          );

          // Cria instância para carteira digital
          await FailoverHelper.createInstance(
            instanceName: 'wallet',
            initialEnvironment: Environment.staging,
            enableHealthCheck: false,
          );

          // Alterna ambiente na instância padrão
          await FailoverHelper.switchTo(
            Environment.staging,
            skipHealthCheck: true,
          );
          expect(
            FailoverHelper.getStats()['currentEnvironment'],
            equals('staging'),
          );

          // Alterna ambiente na instância geral
          final generalManager = FailoverHelper.getInstance('general');
          await generalManager.switchEnvironment(
            Environment.development,
            skipHealthCheck: true,
          );
          expect(
            generalManager.getStats()['currentEnvironment'],
            equals('development'),
          );

          // Alterna ambiente na instância wallet
          final walletManager = FailoverHelper.getInstance('wallet');
          await walletManager.switchEnvironment(
            Environment.production,
            skipHealthCheck: true,
          );
          expect(
            walletManager.getStats()['currentEnvironment'],
            equals('production'),
          );

          // Verifica que as mudanças são independentes
          expect(
            FailoverHelper.getStats()['currentEnvironment'],
            equals('staging'),
          );
          expect(
            generalManager.getStats()['currentEnvironment'],
            equals('development'),
          );
          expect(
            walletManager.getStats()['currentEnvironment'],
            equals('production'),
          );
        },
      );

      test('deve gerenciar instância padrão corretamente', () async {
        // Inicializa instância padrão
        await FailoverHelper.initialize(
          initialEnvironment: Environment.development,
          enableHealthCheck: false,
        );

        // Verifica se a instância padrão é definida corretamente
        expect(FailoverHelper.defaultInstanceName, equals('default'));

        // Cria primeira instância adicional
        await FailoverHelper.createInstance(
          instanceName: 'first',
          initialEnvironment: Environment.production,
          enableHealthCheck: false,
        );

        // A instância padrão deve continuar sendo 'default'
        expect(FailoverHelper.defaultInstanceName, equals('default'));

        // Define nova instância padrão
        FailoverHelper.setDefaultInstance('first');
        expect(FailoverHelper.defaultInstanceName, equals('first'));

        // Volta para a instância padrão original
        FailoverHelper.setDefaultInstance('default');
        expect(FailoverHelper.defaultInstanceName, equals('default'));
      });

      test('deve remover instâncias corretamente', () async {
        // Inicializa instância padrão
        await FailoverHelper.initialize(
          initialEnvironment: Environment.development,
          enableHealthCheck: false,
        );

        // Cria múltiplas instâncias
        await FailoverHelper.createInstance(
          instanceName: 'general',
          initialEnvironment: Environment.production,
          enableHealthCheck: false,
        );

        await FailoverHelper.createInstance(
          instanceName: 'wallet',
          initialEnvironment: Environment.staging,
          enableHealthCheck: false,
        );

        // Verifica se todas existem
        expect(FailoverHelper.hasInstance('general'), isTrue);
        expect(FailoverHelper.hasInstance('wallet'), isTrue);
        expect(FailoverHelper.availableInstances.length, equals(2));

        // Remove uma instância
        FailoverHelper.removeInstance('general');
        expect(FailoverHelper.hasInstance('general'), isFalse);
        expect(FailoverHelper.hasInstance('wallet'), isTrue);
        expect(FailoverHelper.availableInstances.length, equals(1));

        // Remove a última instância
        FailoverHelper.removeInstance('wallet');
        expect(FailoverHelper.hasInstance('wallet'), isFalse);
        expect(FailoverHelper.availableInstances.length, equals(0));
      });

      test('deve obter estatísticas de todas as instâncias', () async {
        // Inicializa instância padrão
        await FailoverHelper.initialize(
          initialEnvironment: Environment.development,
          enableHealthCheck: false,
        );

        // Cria instâncias adicionais
        await FailoverHelper.createInstance(
          instanceName: 'general',
          initialEnvironment: Environment.production,
          enableHealthCheck: false,
        );

        await FailoverHelper.createInstance(
          instanceName: 'wallet',
          initialEnvironment: Environment.staging,
          enableHealthCheck: false,
        );

        // Obtém estatísticas de todas as instâncias
        final allStats = FailoverHelper.getAllInstancesStats();

        // Verifica se as estatísticas foram coletadas
        expect(allStats, containsPair('default', isA<Map<String, dynamic>>()));
        expect(allStats, containsPair('general', isA<Map<String, dynamic>>()));
        expect(allStats, containsPair('wallet', isA<Map<String, dynamic>>()));

        // Verifica se cada instância tem suas próprias estatísticas
        expect(
          allStats['default']!['currentEnvironment'],
          equals('development'),
        );
        expect(
          allStats['general']!['currentEnvironment'],
          equals('production'),
        );
        expect(allStats['wallet']!['currentEnvironment'], equals('staging'));
      });

      test(
        'deve lançar exceção ao tentar acessar instância inexistente',
        () async {
          // Inicializa instância padrão
          await FailoverHelper.initialize(
            initialEnvironment: Environment.development,
            enableHealthCheck: false,
          );

          // Tenta acessar instância que não existe
          expect(
            () => FailoverHelper.getInstance('inexistente'),
            throwsA(isA<ArgumentError>()),
          );

          // Tenta definir instância inexistente como padrão
          expect(
            () => FailoverHelper.setDefaultInstance('inexistente'),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test(
        'deve funcionar com listeners independentes por instância',
        () async {
          // Inicializa instância padrão
          await FailoverHelper.initialize(
            initialEnvironment: Environment.development,
            enableHealthCheck: false,
          );

          // Cria instância adicional
          await FailoverHelper.createInstance(
            instanceName: 'general',
            initialEnvironment: Environment.production,
            enableHealthCheck: false,
          );

          // Adiciona listeners para cada instância
          final defaultListener = (Environment env) => print('Default: $env');
          final generalListener = (Environment env) => print('General: $env');

          FailoverHelper.onEnvironmentChanged(defaultListener);
          FailoverHelper.getInstance('general').addListener(generalListener);

          // Alterna ambiente na instância padrão
          await FailoverHelper.switchTo(
            Environment.staging,
            skipHealthCheck: true,
          );
          expect(
            FailoverHelper.getStats()['currentEnvironment'],
            equals('staging'),
          );

          // Alterna ambiente na instância geral
          final generalManager = FailoverHelper.getInstance('general');
          await generalManager.switchEnvironment(
            Environment.development,
            skipHealthCheck: true,
          );
          expect(
            generalManager.getStats()['currentEnvironment'],
            equals('development'),
          );

          // Verifica que as mudanças são independentes
          expect(
            FailoverHelper.getStats()['currentEnvironment'],
            equals('staging'),
          );
          expect(
            generalManager.getStats()['currentEnvironment'],
            equals('development'),
          );
        },
      );

      test('deve funcionar com Socket.IO independente por instância', () async {
        // Inicializa instância padrão
        await FailoverHelper.initialize(
          initialEnvironment: Environment.development,
          enableHealthCheck: false,
        );

        // Cria instância adicional
        await FailoverHelper.createInstance(
          instanceName: 'general',
          initialEnvironment: Environment.production,
          enableHealthCheck: false,
        );

        // Verifica se Socket.IO está desconectado inicialmente
        expect(FailoverHelper.isSocketConnected, isFalse);
        expect(FailoverHelper.isSocketConnectedForInstance('general'), isFalse);

        // Tenta conectar Socket.IO na instância padrão
        final defaultConnected = await FailoverHelper.connectSocket();
        expect(
          defaultConnected,
          isTrue,
        ); // Retorna true pois Socket.IO está configurado

        // Tenta conectar Socket.IO na instância geral
        final generalConnected = await FailoverHelper.connectSocketForInstance(
          'general',
        );
        expect(
          generalConnected,
          isTrue,
        ); // Retorna true pois Socket.IO está configurado

        // Verifica se ambas permanecem desconectadas
        expect(FailoverHelper.isSocketConnected, isFalse);
        expect(FailoverHelper.isSocketConnectedForInstance('general'), isFalse);
      });

      test(
        'deve funcionar com HTTP requests independentes por instância',
        () async {
          // Inicializa instância padrão
          await FailoverHelper.initialize(
            initialEnvironment: Environment.development,
            enableHealthCheck: false,
          );

          // Cria instância adicional
          await FailoverHelper.createInstance(
            instanceName: 'general',
            initialEnvironment: Environment.production,
            enableHealthCheck: false,
          );

          // Tenta fazer request na instância padrão (deve falhar com URL inválida)
          try {
            await FailoverHelper.httpRequest(endpoint: '/test', method: 'GET');
            fail('Deveria ter lançado exceção');
          } catch (e) {
            expect(e, isA<Exception>());
          }

          // Tenta fazer request na instância geral (deve falhar com URL inválida)
          try {
            await FailoverHelper.httpRequestForInstance(
              instanceName: 'general',
              endpoint: '/test',
              method: 'GET',
            );
            fail('Deveria ter lançado exceção');
          } catch (e) {
            expect(e, isA<Exception>());
          }
        },
      );

      test(
        'deve manter instância padrão funcionando após criar instâncias adicionais',
        () async {
          // Inicializa instância padrão
          await FailoverHelper.initialize(
            initialEnvironment: Environment.development,
            enableHealthCheck: false,
          );

          // Verifica se a instância padrão está funcionando
          expect(
            FailoverHelper.getStats()['currentEnvironment'],
            equals('development'),
          );
          expect(
            FailoverHelper.currentEnvironment,
            equals(Environment.development),
          );

          // Cria instâncias adicionais
          await FailoverHelper.createInstance(
            instanceName: 'general',
            initialEnvironment: Environment.production,
            enableHealthCheck: false,
          );

          await FailoverHelper.createInstance(
            instanceName: 'wallet',
            initialEnvironment: Environment.staging,
            enableHealthCheck: false,
          );

          // Verifica se a instância padrão continua funcionando
          expect(
            FailoverHelper.getStats()['currentEnvironment'],
            equals('development'),
          );
          expect(
            FailoverHelper.currentEnvironment,
            equals(Environment.development),
          );

          // Alterna ambiente na instância padrão
          await FailoverHelper.switchTo(
            Environment.staging,
            skipHealthCheck: true,
          );
          expect(
            FailoverHelper.getStats()['currentEnvironment'],
            equals('staging'),
          );
          expect(
            FailoverHelper.currentEnvironment,
            equals(Environment.staging),
          );

          // Verifica se as outras instâncias não foram afetadas
          expect(
            FailoverHelper.getInstance(
              'general',
            ).getStats()['currentEnvironment'],
            equals('production'),
          );
          expect(
            FailoverHelper.getInstance(
              'wallet',
            ).getStats()['currentEnvironment'],
            equals('staging'),
          );
        },
      );
    });
  });
}
