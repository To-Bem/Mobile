// Funções de leitura tolerante de JSON.
// A API pode mandar números como int ou double e datas com ou sem milissegundos;
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
  if (valor is String) return double.tryParse(valor);
  return null;
}

String lerTexto(Object? valor, [String padrao = '']) {
  if (valor is String) return valor;
  if (valor == null) return padrao;
  return valor.toString();
}

/// Lê LocalDate ("1948-03-12") ou LocalDateTime ("2026-11-06T12:30:00") do Java.
DateTime? lerData(Object? valor) {
  if (valor is String && valor.isNotEmpty) return DateTime.tryParse(valor);
  return null;
}

/// Formato que o Java espera para LocalDate: yyyy-MM-dd.
String dataParaApi(DateTime data) {
  final ano = data.year.toString().padLeft(4, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final dia = data.day.toString().padLeft(2, '0');
  return '$ano-$mes-$dia';
}

/// Lê uma lista de objetos JSON aplicando [converter] em cada item.
/// Itens que não são objetos são ignorados.
List<T> lerLista<T>(
  Object? valor,
  T Function(Map<String, dynamic> json) converter,
) {
  if (valor is! List) return <T>[];
  return valor.whereType<Map<String, dynamic>>().map(converter).toList();
}
