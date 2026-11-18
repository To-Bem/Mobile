// Enums do domínio.
// O nome de cada valor em MAIÚSCULAS é exatamente o texto que a API Java usa
// (ex.: NivelAlerta.atencao <-> "ATENCAO").

/// Permissão do usuário na API (enum Role do Java).
enum Perfil {
  admin('Administrador'),
  manager('Gerente'),
  member('Familiar/cuidador');

  const Perfil(this.rotulo);
  final String rotulo;

  /// ADMIN e MANAGER veem todos os idosos e podem alterar cadastros.
  bool get ehGestao => this == Perfil.admin || this == Perfil.manager;
}

/// Vínculo do usuário com os idosos (enum UsuarioPapel do Java).
enum Papel {
  familiar('Familiar'),
  cuidador('Cuidador');

  const Papel(this.rotulo);
  final String rotulo;
}

enum ModoIdoso {
  normal('Em casa'),
  ausente('Fora de casa');

  const ModoIdoso(this.rotulo);
  final String rotulo;
}

/// Situação atual do idoso. O app calcula a partir dos alertas abertos e
/// do sinal dos dispositivos (a API não devolve este campo).
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

enum TipoDispositivo {
  lampada('Lâmpada'),
  base('Base');

  const TipoDispositivo(this.rotulo);
  final String rotulo;
}

enum StatusDispositivo {
  online('Online'),
  offline('Offline');

  const StatusDispositivo(this.rotulo);
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

/// Igual a [enumDaApi], mas devolve null quando o texto não é reconhecido.
T? enumDaApiOuNulo<T extends Enum>(List<T> valores, Object? texto) {
  if (texto is! String) return null;
  final busca = texto.trim().toUpperCase();
  for (final valor in valores) {
    if (valor.name.toUpperCase() == busca) return valor;
  }
  return null;
}

/// Converte o enum no texto que a API espera ("ATENCAO").
String enumParaApi(Enum valor) => valor.name.toUpperCase();
