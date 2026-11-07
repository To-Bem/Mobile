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

  /// De quanto em quanto tempo o monitoramento ao vivo consulta a API.
  /// Padrão: 10 segundos. Para mudar, defina MONITOR_SEGUNDOS
  /// (ex.: `$env:MONITOR_SEGUNDOS="5"; dart run`).
  static Duration get intervaloMonitor {
    final segundos =
        int.tryParse(Platform.environment['MONITOR_SEGUNDOS'] ?? '');
    return Duration(
      seconds: segundos != null && segundos > 0 ? segundos : 10,
    );
  }
}
