# Changelog

## 1.0.1

### Features
- Adicionado logo SVG personalizado para o pacote
- Incluídos badges profissionais no README
- Melhorada a apresentação visual do pacote
- Adicionados assets ao pubspec.yaml

### Visual
- Logo com design de failover (setas e indicadores de ambiente)
- Badges para versão, Flutter, licença e status do pub.dev
- Layout centralizado e profissional no README

## 1.0.0

### Features
- Sistema completo de failover entre ambientes (produção, desenvolvimento, staging)
- Configurações dinâmicas para cada ambiente
- Health check automático configurável
- Fallback automático entre ambientes
- Sistema de listeners para mudanças de ambiente
- HTTP helper com fallback automático
- Singleton pattern para gerenciamento centralizado
- Timeouts configuráveis por ambiente
- Estatísticas do sistema
- Tratamento robusto de erros

### Components
- `EnvironmentConfig`: Configurações específicas de cada ambiente
- `FailoverManager`: Classe principal com lógica de failover
- `FailoverHelper`: Interface simplificada para uso comum

### Examples
- Exemplo básico de uso (`example/failover_example.dart`)
- Aplicação Flutter completa (`example/flutter_app_example.dart`)

### Tests
- 17 testes abrangentes cobrindo todas as funcionalidades
- Testes de inicialização, alternância de ambientes, listeners e casos de borda
