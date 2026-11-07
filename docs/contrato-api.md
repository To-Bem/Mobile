# Contrato Aplicação Dart ↔ API Java

Este é o formato que a aplicação Dart espera. Quem faz a API Java usa este arquivo como
referência para os DTOs; se algo mudar no Java, atualize aqui também.

## Regras gerais

- **Autenticação:** todas as rotas, menos `/auth/login`, recebem `Authorization: Bearer <token>`.
- **Enums em MAIÚSCULAS:** `FAMILIAR`, `ATENCAO`, `ABERTO`...
- **Datas:** `LocalDate` → `"1948-03-12"`; `LocalDateTime` → `"2026-11-06T09:40:00"` (sem fuso).
- **Fuso horário:** o container da API precisa rodar em `America/Sao_Paulo`
  (`TZ=America/Sao_Paulo` no compose ou `-Duser.timezone=America/Sao_Paulo` na JVM).
  A VM da Azure roda em UTC; sem isso, os horários aparecem 3 h adiantados.
- **HATEOAS:** a aplicação ignora `_links`. Nas listas, ela aceita uma lista pura, uma página do
  Spring (`content`) ou um `_embedded`. Sugestão para o Java: `@Relation(collectionRelation = "idosos")`
  e `@Relation(collectionRelation = "alertas")`, para a chave do `_embedded` ficar previsível.
- **Erros:** a aplicação mostra o campo `mensagem` ao usuário.

```json
{ "status": 400, "mensagem": "Dados inválidos", "campos": { "telefone": "obrigatório" } }
```

## Endpoints usados

| Método | Rota | Uso na aplicação | Resposta |
|---|---|---|---|
| POST | `/auth/login` | Login | 200 `Sessao` |
| GET | `/idosos` | Listar meus idosos | 200 lista de `Idoso` |
| POST | `/idosos` | Cadastrar idoso | 201 `Idoso` |
| GET | `/idosos/{id}/painel` | Detalhe do idoso | 200 `PainelIdoso` |
| PATCH | `/idosos/{id}/modo` | Marcar "fora de casa" / "em casa" | 200 `Idoso` |
| GET | `/idosos/{id}/contatos` | Contatos no detalhe do idoso | 200 lista de `Contato` |
| POST | `/idosos/{id}/contatos` | Cadastrar contato | 201 `Contato` |
| GET | `/alertas?status=&nivel=&idosoId=` | Listar alertas | 200 lista de `Alerta` |
| PATCH | `/alertas/{id}/confirmar` | Confirmar alerta | 200 `Alerta` |

O FAMILIAR e o CUIDADOR só recebem em `/idosos` e `/alertas` os idosos ligados a eles.

### Regras de acesso e erros esperados

| Situação | Resposta |
|---|---|
| CUIDADOR tenta `POST /idosos` | 403 "Cuidadores não podem cadastrar idosos." |
| FAMILIAR cadastra um idoso | o idoso passa a ser dele (vínculo criado automaticamente) |
| Idoso ou alerta de outra família | 404 |
| Confirmar alerta já resolvido | 409 "Este alerta já foi confirmado." |
| Campos inválidos em POST/PATCH | 400 com `campos` |
| Idoso cadastrado sem nenhum sinal do dispositivo | `status: OFFLINE`, `ultimaAtividade: null` |

## Formatos

### Login

Requisição:
```json
{ "email": "ana@email.com", "senha": "123456" }
```

Resposta (`Sessao`):
```json
{
  "token": "eyJhbGciOi...",
  "usuario": { "id": 1, "nome": "Ana", "email": "ana@email.com", "papel": "FAMILIAR" }
}
```

### Idoso

```json
{
  "id": 7,
  "nome": "Dona Maria",
  "dataNascimento": "1948-03-12",
  "telefone": "11988887777",
  "endereco": "Rua das Flores, 120",
  "modo": "NORMAL",
  "status": "OK",
  "ultimaAtividade": "2026-11-06T09:40:00",
  "alertasAbertos": 0
}
```

- `modo`: `NORMAL` | `AUSENTE`
- `status`: `OK` | `ATENCAO` | `ALERTA` | `CRITICO` | `OFFLINE`. Calculado pela API: o pior alerta
  aberto ou `OFFLINE` se o último heartbeat do dispositivo estiver velho.
- `status`, `ultimaAtividade` e `alertasAbertos` são só de leitura. O POST e o PUT enviam apenas
  `nome`, `dataNascimento`, `telefone`, `endereco` e `modo`.

PATCH `/idosos/{id}/modo`:
```json
{ "modo": "AUSENTE" }
```

### PainelIdoso

```json
{
  "idoso": { "...": "mesmo formato de Idoso" },
  "temperatura": 31.5,
  "umidade": 58,
  "eventosHoje": [
    { "id": 120, "tipo": "PRESENCA", "valor": null, "dataHora": "2026-11-06T07:10:00", "comodo": "Corredor" }
  ]
}
```

### Alerta

```json
{
  "id": 3,
  "idosoId": 7,
  "idosoNome": "Dona Maria",
  "tipo": "PESSOA_PARADA",
  "descricao": "Sem movimento no banheiro há 40 min",
  "nivel": "CRITICO",
  "status": "ABERTO",
  "nivelEscalonamento": 1,
  "criadoEm": "2026-11-06T10:05:00",
  "resolvidoEm": null
}
```

- `nivel`: `ATENCAO` | `ALERTA` | `CRITICO`
- `status`: `ABERTO` | `ESCALONADO` | `RESOLVIDO`

### Contato

```json
{
  "id": 4,
  "idosoId": 7,
  "usuarioId": null,
  "nome": "Vizinha Rosa",
  "telefone": "11999990000",
  "parentesco": "Vizinha",
  "ordemEscalonamento": 2
}
```

> Diferença em relação ao diagrama ER: o Contato ganhou `nome` e `telefone`, e `usuario_id`
> passou a ser opcional. Assim dá para cadastrar um vizinho que não tem conta no sistema.
> Alinhar com quem faz o Java e o PL/SQL.

## Tipos de evento (alinhar com IoT e .NET)

O ESP32 envia estes tipos para a API .NET, e a aplicação traduz cada um na linha do tempo:

| Tipo | Texto exibido |
|---|---|
| `PRESENCA` | Movimento detectado |
| `PESSOA_PARADA` | Pessoa parada por muito tempo |
| `BOTAO_ESTOU_BEM` | Apertou "Estou bem" |
| `BOTAO_SAIU` | Avisou que saiu de casa |
| `BOTAO_VOLTOU` | Avisou que voltou para casa |
| `PORTA_GELADEIRA` | Abriu a geladeira |
| `TEMPERATURA` | Leitura de temperatura |
| `HEARTBEAT` | Dispositivo online |

Um tipo que não estiver na lista aparece com o próprio nome, sem quebrar nada.
