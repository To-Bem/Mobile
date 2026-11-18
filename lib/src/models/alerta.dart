import '../core/utils/json_utils.dart';
import 'enums.dart';

/// Alerta gerado quando algo foge da rotina do idoso (AlertaResponse do Java).
class Alerta {
  const Alerta({
    required this.id,
    required this.idosoId,
    required this.tipo,
    required this.nivel,
    required this.status,
    required this.criadoEm,
    this.idosoNome = '',
    this.nivelEscalonamento = 1,
    this.usuarioId,
  });

  final int id;
  final int idosoId;

  /// Preenchido pelo app (a API devolve só o idosoId).
  final String idosoNome;
  final String tipo;
  final NivelAlerta nivel;
  final StatusAlerta status;

  /// Ordem do contato que está sendo avisado agora (1 = primeiro da fila).
  final int nivelEscalonamento;
  final DateTime criadoEm;

  /// Usuário avisado agora (destinatário atual do alerta).
  final int? usuarioId;

  bool get estaAberto => status != StatusAlerta.resolvido;

  factory Alerta.fromJson(Map<String, dynamic> json) {
    return Alerta(
      id: lerInt(json['id']),
      idosoId: lerInt(json['idosoId']),
      tipo: lerTexto(json['tipo']).toUpperCase(),
      nivel: enumDaApi(NivelAlerta.values, json['nivel'], NivelAlerta.atencao),
      status: enumDaApi(
        StatusAlerta.values,
        json['status'],
        StatusAlerta.aberto,
      ),
      nivelEscalonamento: lerInt(json['nivelEscalonamento'], 1),
      criadoEm: lerData(json['criadoEm']) ?? DateTime.now(),
      usuarioId: lerIntOuNulo(json['usuarioId']),
    );
  }

  /// Corpo do PUT /api/alertas/{id} (AlertaRequest do Java).
  /// A API exige todos os campos, então os atuais são reenviados.
  Map<String, dynamic> paraAtualizar({StatusAlerta? novoStatus}) => {
    'tipo': tipo,
    'nivel': enumParaApi(nivel),
    'status': enumParaApi(novoStatus ?? status),
    'nivelEscalonamento': nivelEscalonamento < 1 ? 1 : nivelEscalonamento,
  };

  Alerta copyWith({StatusAlerta? status, String? idosoNome}) {
    return Alerta(
      id: id,
      idosoId: idosoId,
      idosoNome: idosoNome ?? this.idosoNome,
      tipo: tipo,
      nivel: nivel,
      status: status ?? this.status,
      nivelEscalonamento: nivelEscalonamento,
      criadoEm: criadoEm,
      usuarioId: usuarioId,
    );
  }
}
