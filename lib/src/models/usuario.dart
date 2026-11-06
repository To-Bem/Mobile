import '../core/utils/json_utils.dart';
import 'enums.dart';

/// Usuário logado (familiar, cuidador ou admin).
class Usuario {
  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.papel,
  });

  final int id;
  final String nome;
  final String email;
  final Papel papel;

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: lerInt(json['id']),
      nome: lerTexto(json['nome']),
      email: lerTexto(json['email']),
      papel: enumDaApi(Papel.values, json['papel'], Papel.familiar),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'email': email,
    'papel': enumParaApi(papel),
  };
}

/// Resposta do login: token JWT + dados do usuário.
class Sessao {
  const Sessao({required this.token, required this.usuario});

  final String token;
  final Usuario usuario;

  factory Sessao.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'];
    return Sessao(
      token: lerTexto(json['token']),
      usuario: Usuario.fromJson(
        usuario is Map<String, dynamic> ? usuario : <String, dynamic>{},
      ),
    );
  }
}
