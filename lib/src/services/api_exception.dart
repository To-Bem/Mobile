/// Erro devolvido pela API ou na comunicação com ela.
/// [mensagem] já vem pronta para mostrar ao usuário.
class ApiException implements Exception {
  const ApiException(
    this.mensagem, {
    this.statusCode,
    this.campos = const {},
  });

  final String mensagem;
  final int? statusCode;

  /// Erros por campo, ex.: {"telefone": "obrigatório"}.
  final Map<String, String> campos;

  /// Monta a exceção a partir da resposta de erro da API Java.
  /// Aceita o formato combinado ({"mensagem": ...}) e o padrão do Spring ({"message": ...}).
  factory ApiException.daResposta(int statusCode, Object? corpo) {
    String? mensagem;
    var campos = <String, String>{};

    if (corpo is Map) {
      final texto = corpo['mensagem'] ?? corpo['message'] ?? corpo['erro'];
      if (texto is String && texto.isNotEmpty) mensagem = texto;

      final porCampo = corpo['campos'];
      if (porCampo is Map) {
        campos = porCampo.map<String, String>(
          (chave, valor) => MapEntry(chave.toString(), valor.toString()),
        );
      }
    }

    mensagem ??= _mensagemPadrao(statusCode);

    if (statusCode == 401 || statusCode == 403) {
      return NaoAutorizadoException(mensagem, statusCode: statusCode);
    }
    return ApiException(mensagem, statusCode: statusCode, campos: campos);
  }

  static String _mensagemPadrao(int statusCode) => switch (statusCode) {
        400 => 'Dados inválidos.',
        401 => 'Sessão expirada. Faça login novamente.',
        403 => 'Você não tem permissão para isso.',
        404 => 'Registro não encontrado.',
        >= 500 => 'Erro no servidor. Tente novamente em instantes.',
        _ => 'Erro inesperado ($statusCode).',
      };

  @override
  String toString() => mensagem;
}

/// 401 ou 403: token ausente, expirado ou sem permissão.
class NaoAutorizadoException extends ApiException {
  const NaoAutorizadoException(super.mensagem, {super.statusCode});
}

/// A API não respondeu: fora do ar, endereço errado ou sem internet.
class SemConexaoException extends ApiException {
  const SemConexaoException(super.mensagem);
}
