# Integração do app com a API Java (to_bem_api)

O app consome a API Java real (Spring Boot, JWT). Não há dados mockados no app:
todas as telas leem e gravam pela API em `API_URL` (padrão `http://localhost:8080`).

A imitação da API em `test/apoio/api_java_falsa.dart` existe **só para os testes
automatizados** (`dart test`) e responde nas mesmas rotas e formatos do Java.

## Autenticação

| Ação | Rota | Observação |
|---|---|---|
| Entrar | `POST /api/auth/login` `{email, password}` | Devolve `{token, tokenType, expiresInSeconds, email, role}` |
| Dados do usuário | `GET /api/auth/me` | O login não traz id/nome; o app busca aqui |
| Criar conta | `POST /api/auth/register` `{name, email, password}` | Cria MEMBER; senha de 8 a 72 caracteres; 409 se o e-mail existir |

Todas as outras chamadas levam `Authorization: Bearer <token>`.
401 (token ausente/expirado) e 403 (sem permissão) viram `NaoAutorizadoException`.

## O que o app chama, por tela

| Tela | ADMIN / MANAGER | MEMBER (familiar/cuidador) |
|---|---|---|
| Lista de idosos, menu, monitoramento | `GET /api/idosos?page=0&size=100&sort=nome` | `GET /api/usuarios/{meuId}/withContatos` |
| Situação de cada idoso | `GET /api/idosos/{id}/withAll` + `GET /api/eventos/byOtherFilter?dispositivoId=&sort=id&direction=DESC` | igual |
| Nomes dos contatos | `GET /api/usuarios/{id}` | só o próprio nome (os outros aparecem como "Usuário #id") |
| Alertas | `GET /api/alertas?sort=id&direction=DESC` | `GET /api/alertas/byOtherFilter?idosoId=` (um por idoso) |
| Confirmar alerta | `PUT /api/alertas/{id}` com `status: RESOLVIDO` (reenvia tipo, nível e escalonamento) | igual |
| Cadastrar idoso | `POST /api/usuarios/{meuId}/idoso?parentesco=&ordemEscalonamento=1` | igual |
| Cadastrar dispositivo | `POST /api/idosos/{id}/dispositivo` `{tipo, comodo, status}` | igual |
| Cadastrar rotina | `POST /api/idosos/{id}/rotina` `{diaSemana, horaPrimeiraAtividade, mediaLevantadasPorNoite}` | igual |
| Fora de casa / voltou | `PUT /api/idosos/{id}` (cadastro completo com o novo `modo`) | opção não aparece (a API só permite ADMIN/MANAGER) |

### Formatos

- Listagens vêm em `PageResponse`: `{content, page, size, totalElements, totalPages, last}`.
- Datas **enviadas**: `dataNascimento` `yyyy-MM-dd`, `dataHora` `yyyy-MM-ddTHH:mm:ss`, hora `HH:mm:ss`.
- Datas **recebidas**: `dd/MM/yyyy` e `dd/MM/yyyy HH:mm:ss` (a API grava como texto).
- Erros: `{status, error, message}` ou, na validação, `{status, error, errors: [{field, message}]}`.
  O app mostra a mensagem e cada campo.

## Situação do idoso (calculada no app)

A API não devolve status nem última atividade, então o app calcula a partir do `withAll`:

1. alerta aberto (ABERTO ou ESCALONADO) mais grave: **Crítico**, **Alerta** ou **Atenção**;
2. sem nenhum dispositivo ONLINE com sinal recente: **Sem sinal**
   (sinal = o mais recente entre `ultimoHeartbeat` e o último evento; limite em `SEM_SINAL_MINUTOS`, padrão 15);
3. senão, **Tudo bem**.

Última atividade = evento mais recente que mostra a pessoa ativa
(MOVIMENTO, PRESENCA_PARADA, BOTAO_*, LUZ_*, GELADEIRA_ABERTA, ALERTA_RESOLVIDO_MOVIMENTO).

## Pontos para alinhar com Java e IoT

1. **O firmware do ESP32 envia para `POST /api/eventos`, rota que não existe.** A rota real é
   `POST /api/dispositivos/{id}/evento` e exige token ADMIN/MANAGER. O firmware precisa fazer login
   (ou a API precisa de uma rota própria para dispositivos, com chave do aparelho).
2. **`dataHora` com fuso** (`...-03:00`, como o firmware manda) não é aceito por `LocalDateTime`: enviar sem fuso.
3. **`valor` é `Integer`**: temperaturas como 27.5 perdem a casa decimal. Sugestão: `Double`.
4. **Evento não gera alerta sozinho.** Hoje o alerta é criado por `POST /api/eventos/{id}/alerta`
   (ADMIN/MANAGER). O `tool/simular.dart` faz as duas chamadas; o ideal é a API abrir o alerta
   ao receber `ALERTA_QUEDA_N2` / `ALERTA_INATIVIDADE_N2`.
5. **Heartbeat** (`POST /api/dispositivos/{id}/heartbeat`) também exige ADMIN/MANAGER.
6. **MEMBER não consegue marcar "fora de casa"** (`PUT /api/idosos/{id}` é ADMIN/MANAGER).
   Sugestão: `PATCH /api/idosos/{id}/modo` liberado para o contato do idoso.
7. **Não há rota para vincular um 2º contato** a um idoso já cadastrado (`ContatoController` não tem POST).
8. **Contato não tem nome/telefone** e MEMBER não pode consultar outros usuários:
   o app mostra "Usuário #id" para os demais contatos.
9. **Status e última atividade** são calculados no app com várias chamadas por idoso.
   Um endpoint de resumo (ex.: `GET /api/idosos/{id}/painel`) reduziria as chamadas.
10. O cadastro público não define `papel` (vem `null`).
