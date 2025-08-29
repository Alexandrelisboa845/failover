import 'package:flutter/material.dart';
import 'package:failover/failover.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o sistema de failover
  await FailoverHelper.initialize(
    initialEnvironment: Environment.development,
    enableHealthCheck: false, // Desabilita health check para o exemplo
  );

  runApp(FailoverDemoApp());
}

class FailoverDemoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Failover Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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
  bool _isLoading = false;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _updateEnvironmentInfo();
    _addEnvironmentListener();
  }

  void _updateEnvironmentInfo() {
    setState(() {
      _currentEnvironment = FailoverHelper.currentEnvironment.name;
    });
  }

  void _addEnvironmentListener() {
    FailoverHelper.onEnvironmentChanged((Environment env) {
      setState(() {
        _logs.add('🔄 Ambiente alterado para: ${env.name}');
        _currentEnvironment = env.name;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ambiente alterado para ${env.name}'),
          backgroundColor: _getEnvironmentColor(env),
        ),
      );
    });
  }

  Color _getEnvironmentColor(Environment env) {
    switch (env) {
      case Environment.production:
        return Colors.red;
      case Environment.staging:
        return Colors.orange;
      case Environment.development:
        return Colors.green;
    }
  }

  Future<void> _testRequest() async {
    setState(() {
      _isLoading = true;
      _logs.add('📡 Fazendo requisição de teste...');
    });

    try {
      final response = await FailoverHelper.httpRequest(
        endpoint: '/api/test',
        method: 'GET',
        headers: {'Accept': 'application/json'},
      );

      final data = await response.transform(utf8.decoder).join();

      setState(() {
        _lastResponse = 'Status: ${response.statusCode}\nDados: $data';
        _logs.add('✅ Requisição bem-sucedida (Status: ${response.statusCode})');
      });
    } catch (e) {
      setState(() {
        _lastResponse = 'Erro: $e';
        _logs.add('❌ Erro na requisição: $e');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _switchEnvironment(Environment env) async {
    setState(() {
      _logs.add('🔄 Alternando para ${env.name}...');
    });

    final success = await FailoverHelper.switchTo(env, skipHealthCheck: true);

    if (success) {
      setState(() {
        _logs.add('✅ Ambiente alterado com sucesso para ${env.name}');
      });
    } else {
      setState(() {
        _logs.add('❌ Falha ao alterar para ${env.name}');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao alterar ambiente'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showStats() {
    final stats = FailoverHelper.getStats();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Estatísticas do Sistema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: stats.entries.map((entry) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('${entry.key}: ${entry.value}'),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sistema de Failover Demo'),
        backgroundColor: _getEnvironmentColor(
          FailoverHelper.currentEnvironment,
        ),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: Icon(Icons.info), onPressed: _showStats)],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card do ambiente atual
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Ambiente Atual',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getEnvironmentColor(
                          FailoverHelper.currentEnvironment,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _currentEnvironment.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () =>
                              _switchEnvironment(Environment.development),
                          icon: Icon(Icons.developer_mode),
                          label: Text('Dev'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _switchEnvironment(Environment.staging),
                          icon: Icon(Icons.assessment),
                          label: Text('Staging'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _switchEnvironment(Environment.production),
                          icon: Icon(Icons.production_quantity_limits),
                          label: Text('Prod'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Botão de teste
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testRequest,
              icon: _isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send),
              label: Text(_isLoading ? 'Testando...' : 'Testar Requisição'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            SizedBox(height: 16),

            // Resposta da requisição
            if (_lastResponse.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Última Resposta:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _lastResponse,
                          style: TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            // Logs
            Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Logs do Sistema',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          TextButton.icon(
                            onPressed: _clearLogs,
                            icon: Icon(Icons.clear),
                            label: Text('Limpar'),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _logs
                                  .map(
                                    (log) => Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        log,
                                        style: TextStyle(
                                          color: Colors.green[300],
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
