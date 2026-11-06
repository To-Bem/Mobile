import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/config/app_config.dart';
import 'api_exception.dart';

/// Cliente HTTP da API Java, feito só com `dart:io` (sem pacotes externos).
/// Guarda o token JWT depois do login e o envia em todas as chamadas.
class ApiClient {
  ApiClient({
    String? baseUrl,
    this.tempoLimite = const Duration(seconds: 15),
  }) : baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceFirst(
          RegExp(r'/+$'),
          '',
        );

  final String baseUrl;
  final Duration tempoLimite;
  final HttpClient _http = HttpClient();

  /// Token JWT da sessão atual. Preenchido pelo AuthService no login.
  String? token;

  Future<dynamic> get(String caminho, {Map<String, String>? parametros}) =>
      _enviar('GET', caminho, parametros: parametros);

  Future<dynamic> post(String caminho, Object? corpo) =>
      _enviar('POST', caminho, corpo: corpo);

  Future<dynamic> patch(String caminho, [Object? corpo]) =>
      _enviar('PATCH', caminho, corpo: corpo);

  /// Libera as conexões abertas. Chamar ao encerrar a aplicação.
  void fechar() => _http.close(force: true);

  Uri montarUri(String caminho, [Map<String, String>? parametros]) {
    final uri = Uri.parse('$baseUrl$caminho');
    if (parametros == null || parametros.isEmpty) return uri;
    return uri.replace(queryParameters: parametros);
  }

  Future<dynamic> _enviar(
    String metodo,
    String caminho, {
    Object? corpo,
    Map<String, String>? parametros,
  }) async {
    final uri = montarUri(caminho, parametros);

    try {
      final requisicao = await _http.openUrl(metodo, uri).timeout(tempoLimite);
      requisicao.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final tokenAtual = token;
      if (tokenAtual != null) {
        requisicao.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $tokenAtual');
      }

      if (corpo != null) {
        final bytes = utf8.encode(jsonEncode(corpo));
        requisicao.headers.contentType = ContentType.json;
        requisicao.contentLength = bytes.length;
        requisicao.add(bytes);
      }

      final resposta = await requisicao.close().timeout(tempoLimite);
      final texto =
          await resposta.transform(utf8.decoder).join().timeout(tempoLimite);
      final json = _decodificar(texto);

      if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
        return json;
      }
      throw ApiException.daResposta(resposta.statusCode, json);
    } on TimeoutException {
      throw const SemConexaoException(
        'A API demorou demais para responder. Tente novamente.',
      );
    } on SocketException {
      throw SemConexaoException(
        'Não foi possível conectar à API ($baseUrl). '
        'Verifique se ela está no ar e se o endereço está certo.',
      );
    } on IOException catch (erro) {
      throw SemConexaoException('Falha na comunicação com a API: $erro');
    }
  }

  Object? _decodificar(String texto) {
    if (texto.trim().isEmpty) return null;
    try {
      return jsonDecode(texto);
    } on FormatException {
      return texto;
    }
  }

  /// Extrai a lista de uma resposta da API. Aceita os três formatos que o
  /// Spring pode devolver: lista pura, página (`content`) ou HATEOAS (`_embedded`).
  static List<Map<String, dynamic>> listaDaResposta(Object? corpo) {
    Object? lista = corpo;

    if (corpo is Map) {
      final conteudo = corpo['content'];
      final embutido = corpo['_embedded'];
      if (conteudo is List) {
        lista = conteudo;
      } else if (embutido is Map) {
        final listas = embutido.values.whereType<List>();
        lista = listas.isEmpty ? const [] : listas.first;
      }
    }

    if (lista is! List) return [];
    return lista.whereType<Map<String, dynamic>>().toList();
  }

  /// Garante que a resposta é um objeto JSON.
  static Map<String, dynamic> objetoDaResposta(Object? corpo) {
    if (corpo is Map<String, dynamic>) return corpo;
    throw const ApiException('Resposta inesperada da API.');
  }
}
