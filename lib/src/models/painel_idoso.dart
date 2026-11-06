import '../core/utils/json_utils.dart';
import 'evento.dart';
import 'idoso.dart';

/// Tudo o que o detalhe do idoso precisa numa única chamada:
/// GET /idosos/{id}/painel (endpoint com @Cacheable no Java).
class PainelIdoso {
  const PainelIdoso({
    required this.idoso,
    this.temperatura,
    this.umidade,
    this.eventosHoje = const [],
  });

  final Idoso idoso;
  final double? temperatura;
  final double? umidade;

  /// Do mais recente para o mais antigo.
  final List<Evento> eventosHoje;

  factory PainelIdoso.fromJson(Map<String, dynamic> json) {
    final idoso = json['idoso'];
    final eventos = lerLista(json['eventosHoje'], Evento.fromJson)
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));
    return PainelIdoso(
      idoso: Idoso.fromJson(
        idoso is Map<String, dynamic> ? idoso : <String, dynamic>{},
      ),
      temperatura: lerDouble(json['temperatura']),
      umidade: lerDouble(json['umidade']),
      eventosHoje: eventos,
    );
  }
}
