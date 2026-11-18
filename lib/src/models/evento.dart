import '../core/utils/json_utils.dart';

/// Evento registrado por um dispositivo (EventoResponse do Java).
/// Os tipos são os que o firmware do ESP32 envia.
class Evento {
  const Evento({
    required this.id,
    required this.tipo,
    required this.dataHora,
    this.valor,
    this.dispositivoId,
    this.comodo,
  });

  final int id;
  final String tipo;
  final DateTime dataHora;
  final double? valor;
  final int? dispositivoId;

  /// Preenchido pelo app a partir do dispositivo que enviou o evento.
  final String? comodo;

  static const Map<String, String> _descricoes = {
    'INICIADO': 'Dispositivo ligado',
    'HEARTBEAT': 'Dispositivo online',
    'MOVIMENTO': 'Movimento detectado',
    'PRESENCA_PARADA': 'Pessoa parada no cômodo',
    'SEM_PRESENCA': 'Ninguém no cômodo',
    'ALERTA_QUEDA_N1': 'Possível queda (aviso na lâmpada)',
    'ALERTA_QUEDA_N2': 'Possível queda (família avisada)',
    'ALERTA_INATIVIDADE_N1': 'Sem movimento (aviso na lâmpada)',
    'ALERTA_INATIVIDADE_N2': 'Sem movimento (família avisada)',
    'ALERTA_RESOLVIDO_MOVIMENTO': 'Voltou a se mexer: alerta encerrado',
    'BOTAO_OK': 'Apertou "Estou bem"',
    'BOTAO_AUSENTE': 'Avisou que saiu de casa',
    'BOTAO_VOLTEI': 'Avisou que voltou para casa',
    'LUZ_LIGADA': 'Luz acesa',
    'LUZ_DESLIGADA': 'Luz apagada',
    'GELADEIRA_ABERTA': 'Abriu a geladeira',
    'TEMPERATURA': 'Leitura de temperatura',
    'TEMPERATURA_ALTA': 'Temperatura alta',
  };

  /// Eventos que mostram que a pessoa está ativa em casa.
  static const Set<String> _tiposDeAtividade = {
    'MOVIMENTO',
    'PRESENCA_PARADA',
    'ALERTA_RESOLVIDO_MOVIMENTO',
    'BOTAO_OK',
    'BOTAO_AUSENTE',
    'BOTAO_VOLTEI',
    'LUZ_LIGADA',
    'LUZ_DESLIGADA',
    'GELADEIRA_ABERTA',
  };

  String get descricao => _descricoes[tipo] ?? tipo;

  bool get indicaAtividade => _tiposDeAtividade.contains(tipo);

  bool get ehTemperatura =>
      tipo == 'TEMPERATURA' || tipo == 'TEMPERATURA_ALTA';

  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      id: lerInt(json['id']),
      tipo: lerTexto(json['tipo']).toUpperCase(),
      dataHora: lerData(json['dataHora']) ?? DateTime.now(),
      valor: lerDouble(json['valor']),
      dispositivoId: lerIntOuNulo(json['dispositivoId']),
    );
  }

  Evento copyWith({String? comodo}) {
    return Evento(
      id: id,
      tipo: tipo,
      dataHora: dataHora,
      valor: valor,
      dispositivoId: dispositivoId,
      comodo: comodo ?? this.comodo,
    );
  }
}
