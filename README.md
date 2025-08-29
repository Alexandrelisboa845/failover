# Sistema de Failover para Flutter

Um sistema robusto e flexível para gerenciar failover entre diferentes ambientes (produção, desenvolvimento, staging) em aplicações Flutter.

## Características

- ✅ **Gerenciamento de Ambientes**: Suporte para produção, desenvolvimento e staging
- ✅ **Configurações Dinâmicas**: Cada ambiente pode ter configurações específicas
- ✅ **Health Check Automático**: Verificação periódica da saúde dos ambientes
- ✅ **Fallback Automático**: Alternância automática entre ambientes em caso de falha
- ✅ **Listeners**: Sistema de notificação para mudanças de ambiente
- ✅ **HTTP Helper**: Utilitário para requisições HTTP com fallback automático
- ✅ **Singleton Pattern**: Instância única para toda a aplicação
- ✅ **Timeout Configurável**: Timeouts específicos para cada ambiente

## Instalação

Adicione a dependência ao seu `pubspec.yaml`:

```yaml
dependencies:
  failover: ^0.0.1
```

## Uso Básico

### 1. Inicialização

```dart
import 'package:failover/failover.dart';

void main() async {
  // Inicializa o sistema com ambiente padrão
  await FailoverHelper.initialize(
    initialEnvironment: Environment.development,
  );
  
  runApp(MyApp());
}
```

### 2. Configurações Customizadas

```dart
// Configurações personalizadas para cada ambiente
final customConfigs = {
  Environment.production: EnvironmentConfig(
    apiUrl: 'https://api.meuapp.com',
    apiKey: 'minha_chave_producao',
    enableLogging: false,
    enableAnalytics: true,
    timeout: Duration(seconds: 30),
    maxRetries: 3,
  ),
  Environment.development: EnvironmentConfig(
    apiUrl: 'https://api-dev.meuapp.com',
    apiKey: 'minha_chave_desenvolvimento',
    enableLogging: true,
    enableAnalytics: false,
    timeout: Duration(seconds: 10),
    maxRetries: 1,
  ),
};

await FailoverHelper.initialize(
  initialEnvironment: Environment.development,
  customConfigs: customConfigs,
);
```

### 3. Requisições HTTP com Fallback

```dart
// Requisição GET simples
try {
  final response = await FailoverHelper.httpRequest(
    endpoint: '/users',
    method: 'GET',
  );
  
  if (response.statusCode == 200) {
    final data = await response.transform(utf8.decoder).join();
    print('Dados recebidos: $data');
  }
} catch (e) {
  print('Erro na requisição: $e');
}

// Requisição POST com dados
try {
  final response = await FailoverHelper.httpRequest(
    endpoint: '/users',
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'name': 'João', 'email': 'joao@email.com'}),
  );
} catch (e) {
  print('Erro na requisição: $e');
}
```

### 4. Alternância Manual de Ambiente

```dart
// Alterna para produção
final success = await FailoverHelper.switchTo(Environment.production);
if (success) {
  print('Ambiente alterado para produção');
} else {
  print('Falha ao alterar ambiente');
}

// Obtém o ambiente atual
final currentEnv = FailoverHelper.currentEnvironment;
print('Ambiente atual: $currentEnv');
```

### 5. Listeners para Mudanças de Ambiente

```dart
// Adiciona um listener para mudanças de ambiente
FailoverHelper.onEnvironmentChanged((Environment newEnvironment) {
  print('Ambiente alterado para: $newEnvironment');
  
  // Atualiza a UI ou reconecta serviços
  if (newEnvironment == Environment.production) {
    // Configurações específicas para produção
  } else if (newEnvironment == Environment.development) {
    // Configurações específicas para desenvolvimento
  }
});
```

### 6. Operações Customizadas com Fallback

```dart
final manager = FailoverManager();

final result = await manager.executeWithFallback(
  operation: (config) async {
    // Sua operação customizada aqui
    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse('${config.apiUrl}/custom-endpoint'),
    );
    request.headers.set('Authorization', 'Bearer ${config.apiKey}');
    
    final response = await request.close();
    client.close();
    return response;
  },
  fallbackOrder: [
    Environment.production,
    Environment.staging,
    Environment.development,
  ],
  timeout: Duration(seconds: 15),
);
```

### 7. Verificação de Saúde dos Ambientes

```dart
// Verifica a saúde de todos os ambientes
final healthStatus = await manager.checkAllEnvironments();
healthStatus.forEach((environment, isHealthy) {
  print('$environment: ${isHealthy ? "Saudável" : "Não saudável"}');
});

// Obtém estatísticas do sistema
final stats = FailoverHelper.getStats();
print('Estatísticas: $stats');
```

## Estrutura da API

### EnvironmentConfig

```dart
class EnvironmentConfig {
  final String apiUrl;        // URL base da API
  final String apiKey;        // Chave de autenticação
  final bool enableLogging;   // Habilita logs
  final bool enableAnalytics; // Habilita analytics
  final Duration timeout;     // Timeout para requisições
  final int maxRetries;       // Número máximo de tentativas
}
```

### FailoverManager

- `initialize()`: Inicializa o sistema
- `switchEnvironment()`: Alterna para um ambiente específico
- `executeWithFallback()`: Executa operação com fallback automático
- `checkAllEnvironments()`: Verifica saúde de todos os ambientes
- `addListener()`: Adiciona listener para mudanças
- `getStats()`: Obtém estatísticas do sistema

### FailoverHelper

- `initialize()`: Inicialização simplificada
- `httpRequest()`: Requisições HTTP com fallback
- `switchTo()`: Alternância de ambiente
- `onEnvironmentChanged()`: Adiciona listener
- `getStats()`: Estatísticas do sistema

## Exemplo Completo

```dart
import 'package:failover/failover.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa o sistema de failover
  await FailoverHelper.initialize(
    initialEnvironment: Environment.development,
  );
  
  // Adiciona listener para mudanças de ambiente
  FailoverHelper.onEnvironmentChanged((Environment env) {
    print('Ambiente alterado para: $env');
  });
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Failover Demo',
      home: FailoverDemoPage(),
    );
  }
}

class FailoverDemoPage extends StatefulWidget {
  @override
  _FailoverDemoPageState createState() => _FailoverDemoPageState();
}

class _FailoverDemoPageState extends State<FailoverDemoPage> {
  String _currentEnvironment = '';
  String _lastResponse = '';

  @override
  void initState() {
    super.initState();
    _updateEnvironmentInfo();
  }

  void _updateEnvironmentInfo() {
    setState(() {
      _currentEnvironment = FailoverHelper.currentEnvironment.name;
    });
  }

  Future<void> _testRequest() async {
    try {
      final response = await FailoverHelper.httpRequest(
        endpoint: '/test',
        method: 'GET',
      );
      
      final data = await response.transform(utf8.decoder).join();
      setState(() {
        _lastResponse = 'Status: ${response.statusCode}\nDados: $data';
      });
    } catch (e) {
      setState(() {
        _lastResponse = 'Erro: $e';
      });
    }
  }

  Future<void> _switchEnvironment(Environment env) async {
    final success = await FailoverHelper.switchTo(env);
    if (success) {
      _updateEnvironmentInfo();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ambiente alterado para ${env.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sistema de Failover')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Ambiente Atual: $_currentEnvironment',
                      style: Theme.of(context).textTheme.headline6,
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => _switchEnvironment(Environment.development),
                          child: Text('Dev'),
                        ),
                        ElevatedButton(
                          onPressed: () => _switchEnvironment(Environment.staging),
                          child: Text('Staging'),
                        ),
                        ElevatedButton(
                          onPressed: () => _switchEnvironment(Environment.production),
                          child: Text('Prod'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testRequest,
              child: Text('Testar Requisição'),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Última Resposta:',
                      style: Theme.of(context).textTheme.subtitle1,
                    ),
                    SizedBox(height: 8),
                    Text(_lastResponse.isEmpty ? 'Nenhuma requisição feita' : _lastResponse),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Contribuição

Contribuições são bem-vindas! Por favor, sinta-se à vontade para:

1. Reportar bugs
2. Sugerir novas funcionalidades
3. Enviar pull requests
4. Melhorar a documentação

## Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.
