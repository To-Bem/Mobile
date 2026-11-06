// Enums do domínio.
// O nome de cada valor em MAIÚSCULAS é exatamente o texto que a API Java usa
// (ex.: NivelAlerta.atencao <-> "ATENCAO").

enum Papel {
  familiar('Familiar'),
  cuidador('Cuidador'),
  admin('Administrador');

  const Papel(this.rotulo);
  final String rotulo;
}

enum ModoIdoso {
  normal('Em casa'),
  ausente('Fora de casa');

  const ModoIdoso(this.rotulo);
  final String rotulo;
}

/// Situação atual do idoso, calculada pela API a partir dos eventos e da rotina.
enum StatusIdoso {
  ok('Tudo bem'),
  atencao('Atenção'),
  alerta('Alerta'),
  critico('Crítico'),
  offline('Sem sinal do dispositivo');

  const StatusIdoso(this.rotulo);
  final String rotulo;
}

enum NivelAlerta {
  atencao('Atenção'),
  alerta('Alerta'),
  critico('Crítico');

  const NivelAlerta(this.rotulo);
  final String rotulo;
}

enum StatusAlerta {
  aberto('Aberto'),
  escalonado('Escalonado'),
  resolvido('Resolvido');

  const StatusAlerta(this.rotulo);
  final String rotulo;
}

/// Converte o texto da API ("ATENCAO") no enum correspondente.
/// Valor desconhecido ou ausente devolve [padrao], sem quebrar a aplicação.
T enumDaApi<T extends Enum>(List<T> valores, Object? texto, T padrao) {
  if (texto is! String) return padrao;
  final busca = texto.trim().toUpperCase();
  for (final valor in valores) {
    if (valor.name.toUpperCase() == busca) return valor;
  }
  return padrao;
}

/// Converte o enum no texto que a API espera ("ATENCAO").
String enumParaApi(Enum valor) => valor.name.toUpperCase();
