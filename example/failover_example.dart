import 'package:failover/failover.dart';
import 'dart:convert';

/// Exemplo completo de uso do sistema de failover
class FailoverExample {
  static Future<void> runExample() async {
    print('=== Sistema de Failover - Exemplo Completo ===\n');

    // 1. Inicialização com configurações customizadas
    print('1. Inicializando o sistema...');

    final customConfigs = {
      Environment.production: EnvironmentConfig(
        apiUrl: 'https://api.production.example.com',
        apiKey: 'prod_key_secure_123',
        enableLogging: false,
        enableAnalytics: true,
        timeout: Duration(seconds: 30),
        maxRetries: 3,
      ),
      Environment.development: EnvironmentConfig(
        apiUrl: 'https://api.dev.example.com',
        apiKey: 'dev_key_test_456',
        enableLogging: true,
        enableAnalytics: false,
        timeout: Duration(seconds: 10),
        maxRetries: 1,
      ),
      Environment.staging: EnvironmentConfig(
        apiUrl: 'https://api.staging.example.com',
        apiKey: 'staging_key_789',
        enableLogging: true,
        enableAnalytics: true,
        timeout: Duration(seconds: 20),
        maxRetries: 2,
      ),
    };

    await FailoverHelper.initialize(
      initialEnvironment: Environment.development,
      customConfigs: customConfigs,
    );

    print('✅ Sistema inicializado com sucesso!');
    print('Ambiente atual: ${FailoverHelper.currentEnvironment.name}\n');

    // 2. Adicionando listener para mudanças de ambiente
    print('2. Configurando listener para mudanças de ambiente...');

    FailoverHelper.onEnvironmentChanged((Environment newEnvironment) {
      print('🔄 Ambiente alterado para: $newEnvironment');

      // Aqui você pode adicionar lógica específica para cada ambiente
      switch (newEnvironment) {
        case Environment.production:
          print('   📊 Analytics habilitado');
          print('   🔇 Logs desabilitados');
          break;
        case Environment.development:
          print('   📝 Logs habilitados');
          print('   📊 Analytics desabilitado');
          break;
        case Environment.staging:
          print('   📝 Logs habilitados');
          print('   📊 Analytics habilitado');
          break;
      }
    });

    print('✅ Listener configurado!\n');

    // 3. Demonstração de requisições HTTP com fallback
    print('3. Testando requisições HTTP com fallback...');

    await _testHttpRequests();

    // 4. Alternância manual de ambientes
    print('\n4. Testando alternância manual de ambientes...');

    await _testEnvironmentSwitching();

    // 5. Verificação de saúde dos ambientes
    print('\n5. Verificando saúde dos ambientes...');

    await _testHealthCheck();

    // 6. Operações customizadas com fallback
    print('\n6. Testando operações customizadas...');

    await _testCustomOperations();

    // 7. Estatísticas do sistema
    print('\n7. Estatísticas do sistema:');

    final stats = FailoverHelper.getStats();
    stats.forEach((key, value) {
      print('   $key: $value');
    });

    print('\n=== Exemplo concluído com sucesso! ===');
  }

  static Future<void> _testHttpRequests() async {
    try {
      print('   Fazendo requisição GET...');

      final response = await FailoverHelper.httpRequest(
        endpoint: '/api/users',
        method: 'GET',
        headers: {'Accept': 'application/json'},
      );

      print('   ✅ Requisição GET bem-sucedida!');
      print('   Status: ${response.statusCode}');

      // Simula processamento da resposta
      final data = await response.transform(utf8.decoder).join();
      print('   Dados recebidos: ${data.length} caracteres');
    } catch (e) {
      print('   ❌ Erro na requisição GET: $e');
    }

    try {
      print('   Fazendo requisição POST...');

      final userData = {
        'name': 'João Silva',
        'email': 'joao@example.com',
        'age': 30,
      };

      final response = await FailoverHelper.httpRequest(
        endpoint: '/api/users',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(userData),
      );

      print('   ✅ Requisição POST bem-sucedida!');
      print('   Status: ${response.statusCode}');
    } catch (e) {
      print('   ❌ Erro na requisição POST: $e');
    }
  }

  static Future<void> _testEnvironmentSwitching() async {
    final environments = [
      Environment.staging,
      Environment.production,
      Environment.development,
    ];

    for (final env in environments) {
      print('   Alternando para ${env.name}...');

      final success = await FailoverHelper.switchTo(env);

      if (success) {
        print('   ✅ Ambiente alterado para ${env.name}');
        print('   Configuração atual:');
        print('     - API URL: ${FailoverHelper.currentConfig.apiUrl}');
        print(
          '     - Timeout: ${FailoverHelper.currentConfig.timeout.inSeconds}s',
        );
        print(
          '     - Logs: ${FailoverHelper.currentConfig.enableLogging ? "Habilitado" : "Desabilitado"}',
        );
        print(
          '     - Analytics: ${FailoverHelper.currentConfig.enableAnalytics ? "Habilitado" : "Desabilitado"}',
        );
      } else {
        print('   ❌ Falha ao alterar para ${env.name}');
      }

      // Aguarda um pouco entre as alternâncias
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  static Future<void> _testHealthCheck() async {
    final manager = FailoverManager();

    print('   Verificando saúde de todos os ambientes...');

    final healthStatus = await manager.checkAllEnvironments();

    healthStatus.forEach((environment, isHealthy) {
      final status = isHealthy ? '✅ Saudável' : '❌ Não saudável';
      print('   ${environment.name}: $status');
    });
  }

  static Future<void> _testCustomOperations() async {
    final manager = FailoverManager();

    print('   Executando operação customizada com fallback...');

    try {
      final result = await manager.executeWithFallback(
        operation: (config) async {
          // Simula uma operação customizada
          print('     Tentando operação em ${config.apiUrl}...');

          // Simula uma operação que pode falhar
          await Future.delayed(Duration(seconds: 1));

          // Simula falha aleatória (para demonstração)
          if (DateTime.now().millisecond % 3 == 0) {
            throw Exception('Falha simulada na operação');
          }

          return 'Operação bem-sucedida em ${config.apiUrl}';
        },
        fallbackOrder: [
          Environment.development,
          Environment.staging,
          Environment.production,
        ],
        timeout: Duration(seconds: 5),
      );

      print('   ✅ Operação customizada bem-sucedida: $result');
    } catch (e) {
      print('   ❌ Falha na operação customizada: $e');
    }
  }
}

/// Função principal para executar o exemplo
void main() async {
  await FailoverExample.runExample();
}
