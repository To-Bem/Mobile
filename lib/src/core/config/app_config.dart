import 'dart:io';

/// Configurações gerais da aplicação.
class AppConfig {
  AppConfig._();

  /// Nome exibido para o usuário.
  /// Provisório: o grupo ainda decide entre "Tô Bem" e "Sinal de Vida".
  static const String nomeApp = 'Tô Bem';

  /// Endereço da API Java (sem o `/api` do final).
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
  static Duration get intervaloMonitor =>
      Duration(seconds: _inteiroPositivo('MONITOR_SEGUNDOS', 10));

  /// Depois de quanto tempo sem heartbeat nem evento um dispositivo é
  /// considerado "sem sinal". Padrão: 15 minutos (SEM_SINAL_MINUTOS).
  static Duration get semSinalDepoisDe =>
      Duration(minutes: _inteiroPositivo('SEM_SINAL_MINUTOS', 15));

  /// Quantos registros o app pede por página nas listagens da API.
  static const int tamanhoPagina = 100;

  /// Quantos eventos recentes de cada dispositivo o app busca.
  static const int eventosPorDispositivo = 20;

  static int _inteiroPositivo(String variavel, int padrao) {
    final valor = int.tryParse(Platform.environment[variavel] ?? '');
    return valor != null && valor > 0 ? valor : padrao;
  }
}
