/// Biblioteca principal do projeto.
/// O bin/ e os testes importam só este arquivo; cada camada nova
/// acrescenta aqui os seus exports.
library;

export 'src/core/config/app_config.dart';
export 'src/core/ui/entrada.dart';
export 'src/core/ui/terminal.dart';
export 'src/core/utils/json_utils.dart';
export 'src/core/validacao/validadores.dart';
export 'src/models/alerta.dart';
export 'src/models/contato.dart';
export 'src/models/enums.dart';
export 'src/models/evento.dart';
export 'src/models/idoso.dart';
export 'src/models/painel_idoso.dart';
export 'src/models/usuario.dart';
export 'src/services/alerta_service.dart';
export 'src/services/api_client.dart';
export 'src/services/api_exception.dart';
export 'src/services/auth_service.dart';
export 'src/services/idoso_service.dart';
export 'src/telas/comum/erros_api.dart';
export 'src/telas/comum/formatacao.dart';
export 'src/telas/tela_alertas.dart';
export 'src/telas/tela_cadastro_contato.dart';
export 'src/telas/tela_cadastro_idoso.dart';
export 'src/telas/tela_detalhe_idoso.dart';
export 'src/telas/tela_lista_idosos.dart';
export 'src/telas/tela_login.dart';
export 'src/telas/tela_menu_principal.dart';
