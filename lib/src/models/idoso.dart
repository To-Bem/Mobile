import '../core/utils/json_utils.dart';
import 'enums.dart';

/// Idoso acompanhado.
/// [status], [ultimaAtividade] e [alertasAbertos] são calculados pela API
/// e só aparecem na leitura (não são enviados no cadastro).
class Idoso {
  const Idoso({
    this.id,
    required this.nome,
    this.dataNascimento,
    this.telefone = '',
    this.endereco = '',
    this.modo = ModoIdoso.normal,
    this.status = StatusIdoso.ok,
    this.ultimaAtividade,
    this.alertasAbertos = 0,
  });

  final int? id;
  final String nome;
  final DateTime? dataNascimento;
  final String telefone;
  final String endereco;
  final ModoIdoso modo;
  final StatusIdoso status;
  final DateTime? ultimaAtividade;
  final int alertasAbertos;

  int? get idade {
    final nascimento = dataNascimento;
    if (nascimento == null) return null;
    final hoje = DateTime.now();
    var anos = hoje.year - nascimento.year;
    final aindaNaoFezAniversario =
        hoje.month < nascimento.month ||
        (hoje.month == nascimento.month && hoje.day < nascimento.day);
    if (aindaNaoFezAniversario) anos--;
    return anos;
  }

  bool get estaAusente => modo == ModoIdoso.ausente;

  factory Idoso.fromJson(Map<String, dynamic> json) {
    return Idoso(
      id: lerIntOuNulo(json['id']),
      nome: lerTexto(json['nome']),
      dataNascimento: lerData(json['dataNascimento']),
      telefone: lerTexto(json['telefone']),
      endereco: lerTexto(json['endereco']),
      modo: enumDaApi(ModoIdoso.values, json['modo'], ModoIdoso.normal),
      status: enumDaApi(StatusIdoso.values, json['status'], StatusIdoso.ok),
      ultimaAtividade: lerData(json['ultimaAtividade']),
      alertasAbertos: lerInt(json['alertasAbertos']),
    );
  }

  /// Corpo do POST/PUT /idosos. Só os campos que o usuário preenche.
  Map<String, dynamic> toJson() {
    final nascimento = dataNascimento;
    return {
      'nome': nome,
      if (nascimento != null) 'dataNascimento': dataParaApi(nascimento),
      'telefone': telefone,
      'endereco': endereco,
      'modo': enumParaApi(modo),
    };
  }

  Idoso copyWith({
    ModoIdoso? modo,
    StatusIdoso? status,
    DateTime? ultimaAtividade,
    int? alertasAbertos,
  }) {
    return Idoso(
      id: id,
      nome: nome,
      dataNascimento: dataNascimento,
      telefone: telefone,
      endereco: endereco,
      modo: modo ?? this.modo,
      status: status ?? this.status,
      ultimaAtividade: ultimaAtividade ?? this.ultimaAtividade,
      alertasAbertos: alertasAbertos ?? this.alertasAbertos,
    );
  }
}
