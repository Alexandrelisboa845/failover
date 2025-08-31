# Changelog

## 1.0.1

### Features
- Adicionado logo SVG personalizado para o pacote
- Incluídos badges profissionais no README
- Melhorada a apresentação visual do pacote
- Adicionados assets ao pubspec.yaml
- **NOVO:** Suporte para múltiplos tipos de autenticação
- **NOVO:** Suporte para Firebase Token além de API Key
- **NOVO:** Configuração flexível de autenticação por ambiente

### Authentication
- Suporte para API Key (`x-api-key` header)
- Suporte para Firebase Token (`Authorization: Bearer` header)
- Suporte para ambos os tipos com fallback automático
- Configuração por ambiente (`AuthType.apiKey`, `AuthType.firebase`, `AuthType.both`)
- **NOVO:** Headers de autenticação personalizáveis
- **NOVO:** Campo `customAuthHeader` para nomes personalizados

### Interceptors
- **NOVO:** Sistema completo de interceptores HTTP
- **NOVO:** Interceptores antes da requisição (`onRequest`)
- **NOVO:** Interceptores após a resposta (`onResponse`)
- **NOVO:** Interceptores em caso de erro (`onError`)
- **NOVO:** Suporte para múltiplos interceptores por ambiente
- **NOVO:** Interceptores de exemplo: Logging, Métricas, Cache

### Socket.IO
- **NOVO:** Suporte completo para Socket.IO em tempo real
- **NOVO:** Conexão automática ao Socket.IO por ambiente
- **NOVO:** Fallback automático de Socket.IO entre ambientes
- **NOVO:** Métodos para emitir e escutar eventos
- **NOVO:** Reconexão automática em caso de falha
- **NOVO:** Configurações personalizáveis por ambiente

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
