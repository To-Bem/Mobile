import '../core/utils/json_utils.dart';

/// Evento registrado por um dispositivo (lâmpada ou base).
/// Os tipos precisam bater com o que o ESP32 envia para a API .NET.
class Evento {
  const Evento({
    required this.id,
    required this.tipo,
    required this.dataHora,
    this.valor,
    this.comodo,
  });

  final int id;
  final String tipo;
  final DateTime dataHora;
  final double? valor;
  final String? comodo;

  static const Map<String, String> _descricoes = {
    'PRESENCA': 'Movimento detectado',
    'PESSOA_PARADA': 'Pessoa parada por muito tempo',
    'BOTAO_ESTOU_BEM': 'Apertou "Estou bem"',
    'BOTAO_SAIU': 'Avisou que saiu de casa',
    'BOTAO_VOLTOU': 'Avisou que voltou para casa',
    'PORTA_GELADEIRA': 'Abriu a geladeira',
    'TEMPERATURA': 'Leitura de temperatura',
    'HEARTBEAT': 'Dispositivo online',
  };

  String get descricao => _descricoes[tipo] ?? tipo;

  factory Evento.fromJson(Map<String, dynamic> json) {
    final comodo = json['comodo'];
    return Evento(
      id: lerInt(json['id']),
      tipo: lerTexto(json['tipo']).toUpperCase(),
      dataHora: lerData(json['dataHora']) ?? DateTime.now(),
      valor: lerDouble(json['valor']),
      comodo: comodo is String ? comodo : null,
    );
  }
}
