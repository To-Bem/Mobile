import 'dart:io';

/// Configurações gerais da aplicação.
class AppConfig {
  AppConfig._();

  /// Nome exibido para o usuário.
  /// Provisório: o grupo ainda decide entre "Tô Bem" e "Sinal de Vida".
  static const String nomeApp = 'Tô Bem';

  /// Endereço da API Java.
  ///
  /// Padrão: a API rodando no próprio PC. Para apontar para a VM da Azure,
  /// defina a variável de ambiente API_URL antes de executar:
  ///
  ///   PowerShell: `$env:API_URL="http://<IP da VM>:8080"; dart run`
  ///   Linux/Mac:  `API_URL=http://<IP da VM>:8080 dart run`
  static String get apiBaseUrl =>
      Platform.environment['API_URL'] ?? 'http://localhost:8080';
}
