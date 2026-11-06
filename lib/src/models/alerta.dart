import '../core/utils/json_utils.dart';
import 'enums.dart';

/// Alerta gerado quando algo foge da rotina do idoso.
class Alerta {
  const Alerta({
    required this.id,
    required this.idosoId,
    required this.tipo,
    required this.nivel,
    required this.status,
    required this.criadoEm,
    this.idosoNome = '',
    this.descricao = '',
    this.nivelEscalonamento = 1,
    this.resolvidoEm,
  });

  final int id;
  final int idosoId;
  final String idosoNome;
  final String tipo;
  final String descricao;
  final NivelAlerta nivel;
  final StatusAlerta status;

  /// 1 = familiar, 2 = segundo contato, 3 = cuidador/agente de saúde.
  final int nivelEscalonamento;
  final DateTime criadoEm;
  final DateTime? resolvidoEm;

  bool get estaAberto => status != StatusAlerta.resolvido;

  factory Alerta.fromJson(Map<String, dynamic> json) {
    return Alerta(
      id: lerInt(json['id']),
      idosoId: lerInt(json['idosoId']),
      idosoNome: lerTexto(json['idosoNome']),
      tipo: lerTexto(json['tipo']).toUpperCase(),
      descricao: lerTexto(json['descricao']),
      nivel: enumDaApi(NivelAlerta.values, json['nivel'], NivelAlerta.atencao),
      status: enumDaApi(
        StatusAlerta.values,
        json['status'],
        StatusAlerta.aberto,
      ),
      nivelEscalonamento: lerInt(json['nivelEscalonamento'], 1),
      criadoEm: lerData(json['criadoEm']) ?? DateTime.now(),
      resolvidoEm: lerData(json['resolvidoEm']),
    );
  }

  Alerta copyWith({StatusAlerta? status, DateTime? resolvidoEm}) {
    return Alerta(
      id: id,
      idosoId: idosoId,
      idosoNome: idosoNome,
      tipo: tipo,
      descricao: descricao,
      nivel: nivel,
      status: status ?? this.status,
      nivelEscalonamento: nivelEscalonamento,
      criadoEm: criadoEm,
      resolvidoEm: resolvidoEm ?? this.resolvidoEm,
    );
  }
}
