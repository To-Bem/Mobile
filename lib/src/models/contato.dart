import '../core/utils/json_utils.dart';

/// Vínculo entre um usuário (familiar/cuidador) e um idoso
/// (ContatoResponse do Java). Define quem é avisado, e em que ordem,
/// quando um alerta não é confirmado.
class Contato {
  const Contato({
    required this.id,
    required this.idosoId,
    required this.usuarioId,
    required this.parentesco,
    required this.ordemEscalonamento,
    this.nomeUsuario = '',
  });

  final int id;
  final int idosoId;
  final int usuarioId;
  final String parentesco;

  /// 1 = primeiro a ser avisado, 2 = segundo, e assim por diante.
  final int ordemEscalonamento;

  /// Preenchido pelo app quando a API permite consultar o usuário.
  final String nomeUsuario;

  factory Contato.fromJson(Map<String, dynamic> json) {
    return Contato(
      id: lerInt(json['id']),
      idosoId: lerInt(json['idosoId']),
      usuarioId: lerInt(json['usuarioId']),
      parentesco: lerTexto(json['parentesco']),
      ordemEscalonamento: lerInt(json['ordemEscalonamento'], 1),
    );
  }

  Contato copyWith({String? nomeUsuario}) {
    return Contato(
      id: id,
      idosoId: idosoId,
      usuarioId: usuarioId,
      parentesco: parentesco,
      ordemEscalonamento: ordemEscalonamento,
      nomeUsuario: nomeUsuario ?? this.nomeUsuario,
    );
  }
}
