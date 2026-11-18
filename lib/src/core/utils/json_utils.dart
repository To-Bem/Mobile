// Funções de leitura tolerante de JSON.
// A API pode mandar números como int ou double e datas em formatos diferentes;
// estas funções evitam que a aplicação quebre por causa disso.

int lerInt(Object? valor, [int padrao = 0]) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor) ?? padrao;
  return padrao;
}

int? lerIntOuNulo(Object? valor) {
  if (valor == null) return null;
  return lerInt(valor);
}

double? lerDouble(Object? valor) {
  if (valor is num) return valor.toDouble();
  if (valor is String) return double.tryParse(valor.replaceAll(',', '.'));
  return null;
}

String lerTexto(Object? valor, [String padrao = '']) {
  if (valor is String) return valor;
  if (valor == null) return padrao;
  return valor.toString();
}

/// dd/MM/yyyy, com hora opcional (dd/MM/yyyy HH:mm:ss).
final RegExp _dataBrasileira = RegExp(
  r'^(\d{2})/(\d{2})/(\d{4})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?$',
);

/// Lê as datas que a API Java devolve.
///
/// A API grava as datas como texto no formato brasileiro:
/// "12/03/1948" (dataNascimento) e "17/11/2026 14:05:09" (dataHora,
/// criadoEm, ultimoHeartbeat). Também aceita ISO ("2026-11-17T14:05:09").
DateTime? lerData(Object? valor) {
  if (valor is! String || valor.trim().isEmpty) return null;
  final texto = valor.trim();

  final br = _dataBrasileira.firstMatch(texto);
  if (br != null) {
    final dia = int.parse(br.group(1)!);
    final mes = int.parse(br.group(2)!);
    final ano = int.parse(br.group(3)!);
    final hora = int.parse(br.group(4) ?? '0');
    final minuto = int.parse(br.group(5) ?? '0');
    final segundo = int.parse(br.group(6) ?? '0');
    return DateTime(ano, mes, dia, hora, minuto, segundo);
  }
  return DateTime.tryParse(texto);
}

String _dois(int numero) => numero.toString().padLeft(2, '0');

/// Formato que o Java espera para LocalDate: yyyy-MM-dd.
String dataParaApi(DateTime data) =>
    '${data.year.toString().padLeft(4, '0')}-${_dois(data.month)}-'
    '${_dois(data.day)}';

/// Formato que o Java espera para LocalDateTime: yyyy-MM-ddTHH:mm:ss.
String dataHoraParaApi(DateTime momento) =>
    '${dataParaApi(momento)}T${_dois(momento.hour)}:${_dois(momento.minute)}:'
    '${_dois(momento.second)}';

/// Formato que o Java espera para LocalTime: HH:mm:ss.
String horaParaApi(int hora, int minuto) => '${_dois(hora)}:${_dois(minuto)}:00';

/// Lê uma lista de objetos JSON aplicando [converter] em cada item.
/// Itens que não são objetos são ignorados.
List<T> lerLista<T>(
  Object? valor,
  T Function(Map<String, dynamic> json) converter,
) {
  if (valor is! List) return <T>[];
  return valor.whereType<Map<String, dynamic>>().map(converter).toList();
}
