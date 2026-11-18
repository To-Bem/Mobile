/// Erro devolvido pela API ou na comunicação com ela.
/// [mensagem] já vem pronta para mostrar ao usuário.
class ApiException implements Exception {
  const ApiException(this.mensagem, {this.statusCode, this.campos = const {}});

  final String mensagem;
  final int? statusCode;

  /// Erros por campo, ex.: {"telefone": "telefone é obrigatorio"}.
  final Map<String, String> campos;

  /// Monta a exceção a partir da resposta de erro da API Java.
  ///
  /// A API usa dois formatos (GlobalExceptionHandler):
  /// - ErrorCustomResponse: `{"status": 404, "error": "...", "message": "..."}`
  /// - ValidationErrorResponse: `{"status": 400, "errors": [{"field", "message"}]}`
  factory ApiException.daResposta(int statusCode, Object? corpo) {
    String? mensagem;
    final campos = <String, String>{};

    if (corpo is Map) {
      final texto = corpo['message'] ?? corpo['mensagem'];
      if (texto is String && texto.trim().isNotEmpty) mensagem = texto.trim();

      final erros = corpo['errors'];
      if (erros is List) {
        for (final erro in erros.whereType<Map>()) {
          final campo = erro['field'];
          final problema = erro['message'];
          if (campo != null && problema != null) {
            campos['$campo'] = '$problema';
          }
        }
      }
    }

    if (mensagem == null && campos.isNotEmpty) {
      mensagem = 'Dados inválidos. Confira os campos:';
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
    409 => 'Conflito com os dados já cadastrados.',
    >= 500 => 'Erro no servidor. Tente novamente em instantes.',
    _ => 'Erro inesperado ($statusCode).',
  };

  @override
  String toString() => mensagem;
}

/// 401 (token ausente, inválido ou expirado) ou 403 (sem permissão).
class NaoAutorizadoException extends ApiException {
  const NaoAutorizadoException(super.mensagem, {super.statusCode});
}

/// A API não respondeu: fora do ar, endereço errado ou sem internet.
class SemConexaoException extends ApiException {
  const SemConexaoException(super.mensagem);
}
