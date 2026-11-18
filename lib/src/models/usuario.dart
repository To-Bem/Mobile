import '../core/utils/json_utils.dart';
import 'enums.dart';

/// Usuário da API (UsuarioResponse do Java).
class Usuario {
  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    this.papel,
  });

  final int id;
  final String nome;
  final String email;

  /// Pode vir nulo: o cadastro público (/api/auth/register) não define papel.
  final Papel? papel;

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: lerInt(json['id']),
      nome: lerTexto(json['nome']),
      email: lerTexto(json['email']),
      papel: enumDaApiOuNulo(Papel.values, json['papel']),
    );
  }
}

/// Sessão aberta no login: token JWT, perfil (Role) e dados do usuário.
class Sessao {
  const Sessao({
    required this.token,
    required this.perfil,
    required this.usuario,
  });

  final String token;
  final Perfil perfil;
  final Usuario usuario;

  bool get ehGestao => perfil.ehGestao;
}
