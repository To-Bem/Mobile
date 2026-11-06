import '../core/utils/json_utils.dart';

/// Pessoa avisada quando um alerta não é confirmado.
/// Pode ser um usuário do sistema (familiar/cuidador) ou alguém sem conta (ex.: vizinho).
class Contato {
  const Contato({
    this.id,
    this.idosoId,
    this.usuarioId,
    required this.nome,
    required this.telefone,
    required this.parentesco,
    required this.ordemEscalonamento,
  });

  final int? id;
  final int? idosoId;
  final int? usuarioId;
  final String nome;
  final String telefone;
  final String parentesco;

  /// 1 = primeiro a ser avisado, 2 = segundo, e assim por diante.
  final int ordemEscalonamento;

  factory Contato.fromJson(Map<String, dynamic> json) {
    return Contato(
      id: lerIntOuNulo(json['id']),
      idosoId: lerIntOuNulo(json['idosoId']),
      usuarioId: lerIntOuNulo(json['usuarioId']),
      nome: lerTexto(json['nome']),
      telefone: lerTexto(json['telefone']),
      parentesco: lerTexto(json['parentesco']),
      ordemEscalonamento: lerInt(json['ordemEscalonamento'], 1),
    );
  }

  /// Corpo do POST /idosos/{id}/contatos.
  Map<String, dynamic> toJson() => {
    if (usuarioId != null) 'usuarioId': usuarioId,
    'nome': nome,
    'telefone': telefone,
    'parentesco': parentesco,
    'ordemEscalonamento': ordemEscalonamento,
  };
}
