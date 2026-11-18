import '../core/utils/json_utils.dart';
import 'enums.dart';

/// Lâmpada ou base instalada na casa do idoso (DispositivoResponse do Java).
/// O [id] é o número que vai no firmware do ESP32.
class Dispositivo {
  const Dispositivo({
    this.id,
    required this.tipo,
    required this.comodo,
    this.status = StatusDispositivo.online,
    this.ultimoHeartbeat,
    this.ultimoSinal,
    this.idosoId,
  });

  final int? id;
  final TipoDispositivo tipo;
  final String comodo;
  final StatusDispositivo status;
  final DateTime? ultimoHeartbeat;

  /// O mais recente entre o heartbeat e o último evento enviado.
  /// Calculado pelo app no painel do idoso.
  final DateTime? ultimoSinal;
  final int? idosoId;

  String get nome => '${tipo.rotulo} (${comodo.isEmpty ? 'sem cômodo' : comodo})';

  /// Online quando a API diz ONLINE e houve sinal dentro do [limite].
  bool estaOnline(DateTime agora, Duration limite) {
    final sinal = ultimoSinal ?? ultimoHeartbeat;
    if (status != StatusDispositivo.online || sinal == null) return false;
    return agora.difference(sinal) <= limite;
  }

  factory Dispositivo.fromJson(Map<String, dynamic> json) {
    return Dispositivo(
      id: lerIntOuNulo(json['id']),
      tipo: enumDaApi(
        TipoDispositivo.values,
        json['tipo'],
        TipoDispositivo.lampada,
      ),
      comodo: lerTexto(json['comodo']),
      status: enumDaApi(
        StatusDispositivo.values,
        json['status'],
        StatusDispositivo.offline,
      ),
      ultimoHeartbeat: lerData(json['ultimoHeartbeat']),
      idosoId: lerIntOuNulo(json['idosoId']),
    );
  }

  /// Corpo do POST /api/idosos/{id}/dispositivo (DispositivoRequest do Java).
  Map<String, dynamic> toJson() => {
    'tipo': enumParaApi(tipo),
    'comodo': comodo,
    'status': enumParaApi(status),
  };

  Dispositivo copyWith({DateTime? ultimoSinal}) {
    return Dispositivo(
      id: id,
      tipo: tipo,
      comodo: comodo,
      status: status,
      ultimoHeartbeat: ultimoHeartbeat,
      ultimoSinal: ultimoSinal ?? this.ultimoSinal,
      idosoId: idosoId,
    );
  }
}
