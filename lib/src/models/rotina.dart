import '../core/utils/json_utils.dart';

/// Rotina aprendida do idoso (RotinaResponse do Java). Serve de base para
/// saber quando a falta de movimento é estranha.
class Rotina {
  const Rotina({
    this.id,
    required this.diaSemana,
    required this.horaPrimeiraAtividade,
    required this.mediaLevantadasPorNoite,
  });

  final int? id;

  /// SEGUNDA, TERCA, ... DOMINGO ou TODOS.
  final String diaSemana;

  /// "07:30:00" (formato da API).
  final String horaPrimeiraAtividade;
  final int mediaLevantadasPorNoite;

  /// "07:30".
  String get horaCurta => horaPrimeiraAtividade.length >= 5
      ? horaPrimeiraAtividade.substring(0, 5)
      : horaPrimeiraAtividade;

  factory Rotina.fromJson(Map<String, dynamic> json) {
    return Rotina(
      id: lerIntOuNulo(json['id']),
      diaSemana: lerTexto(json['diaSemana']).toUpperCase(),
      horaPrimeiraAtividade: lerTexto(json['horaPrimeiraAtividade']),
      mediaLevantadasPorNoite: lerInt(json['mediaLevantadasPorNoite']),
    );
  }

  /// Corpo do POST /api/idosos/{id}/rotina (RotinaRequest do Java).
  Map<String, dynamic> toJson() => {
    'diaSemana': diaSemana,
    'horaPrimeiraAtividade': horaPrimeiraAtividade,
    'mediaLevantadasPorNoite': mediaLevantadasPorNoite,
  };
}
