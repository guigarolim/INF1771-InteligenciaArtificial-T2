# INF1771 - Trabalho 2 - Agente Lógico (Pitfall)

Agente autônomo em SWI-Prolog, com interface em Python, feito a partir do projeto-base da disciplina.

## Como executar

Requisitos: SWI-Prolog, `pip install pyswip pygame`. Testado com SWI-Prolog 9.0.4, PySwip 0.3.3 e pygame 2.6 (o projeto-base recomenda o SWI-Prolog 8.4.3 no Windows).

```
python gmap.py                    # usa mapa.pl
python gmap.py mapa-dificil.pl    # escolhe o mapa
swipl -q -g rodar_testes -g halt testes.pl   # roda os testes
python resumo.py                  # gera resultados/resumo.md
```

Na interface, a tecla `M` mostra o mapa real, apenas para depuração. Para jogar manualmente, use `auto_play = False` no `gmap.py`.

## Arquivos

| Arquivo | Papel |
|---|---|
| `agente.pl` | Base de conhecimento, inferência, risco, planejamento e decisão |
| `main.pl` | Regras do jogo e carregamento de mapas |
| `gmap.py` | Interface gráfica |
| `testes.pl`, `resumo.py` | Testes sem interface e resumo |
| `resultados/` | CSV com cada partida e tabela resumida |

## Estratégia

Ciclo: ação → `verifica_player` → `agente_percebe` → `executa_acao`.

**Conhecimento.** `percebeu/3` guarda o que foi sentido em cada casa visitada. `dano_em/2` registra casas onde a energia caiu (inimigo). `teleporte_em/2` registra a casa em que o agente mandou andar e não chegou.

**Inferência** (`agente.pl`, seção "Regras de inferencia"):
- `descartado(Tipo,X,Y)`: a casa foi visitada, ou tem vizinha visitada sem o sinal daquele perigo.
- `confirmado(Tipo,X,Y)`: a casa é a única explicação possível para um sinal, ou o perigo foi vivido diretamente.
- `seguro(X,Y)`: os três perigos foram descartados.

**Decisão**, em ordem de prioridade:
1. Parar com os 3 ouros.
2. Pegar ouro.
3. Fugir de casa de inimigo, porque cada ação parado nela causa dano de novo.
4. Pegar item de energia se E ≤ 80.
5. Seguir o plano atual.
6. Criar plano: buscar item conhecido → explorar casa segura → arriscar se valer a pena → atravessar inimigo conhecido como último recurso.
7. Parar.

**Risco.** Valor de entrar em uma casa: `V = (1 - PMorte) * G - PPoco * 1000`, em que `G = ouros_restantes * 495 * casas_nao_visitadas / 144`. O agente só arrisca se `V > 0` e escolhe o maior valor. Teletransporte conhecido entra como opção, com as chances do sorteio do destino.

**Planejamento.** Busca em largura sobre `(X, Y, direção)`, passando apenas por casas já visitadas, pois andar e virar custam 1.

**Isolamento do mapa real.** `tile/3` só é lido pelos sensores (`percepcoes_atuais` e `adjacentes`). Nos testes, escondemos `tile/3` durante cada decisão e os resultados foram idênticos.

## Mudanças no projeto-base

- `executa_acao/1` aleatório substituído pela política em `agente.pl`.
- Removida a inferência antiga (`atualiza_obs` e `set_real`), que podia concluir uma certeza errada. `memory/3` e `certeza/2` agora são preenchidos a partir da nova base, só para a interface.
- Mapas carregados por parâmetro, com `reiniciar/1` restaurando o ouro.
- Nova ação `parar` como condição de encerramento: 3 ouros ou nenhuma opção que valha o risco.
- A tecla `M` não aplica mais dano.
- `auto_play` ligado por padrão.

## Resultados

100 partidas por mapa e modo; `sem_risco` desliga a tomada de risco. Tabela completa em `resultados/resumo.md`.

| Mapa | Modo | Pontuação média | Ouro médio | Sobrevivência | Ações médias |
|---|---|---|---|---|---|
| Fácil | com risco | 1301 | 3,00 | 100% | 187 |
| Fácil | sem risco | 1301 | 3,00 | 100% | 187 |
| Médio (`mapa.pl`) | com risco | 629 | 2,00 | 100% | 359 |
| Médio (`mapa.pl`) | sem risco | -17 | 0,00 | 100% | 17 |
| Difícil | com risco | 1037 | 2,88 | 100% | 385 |
| Difícil | sem risco | 300 | 1,00 | 100% | 196 |

`mapa.pl`, `mapa-medio.pl` e `mapa_medio.pl` têm o mesmo conteúdo. As versões com hífen e com sublinhado dos mapas fácil e difícil diferem só em linhas em branco.

## Limitações

- As probabilidades são estimativas simples, não inferência bayesiana exata. Sinais combinados de várias casas não são considerados em conjunto.
- A contagem total de perigos não é usada para deduzir segurança, porque o mapa fácil tem menos poços e teletransportes que o enunciado.
- Os resultados de 100% de sobrevivência valem para estes mapas. O agente ainda pode cair em poço em mapas novos, já que às vezes precisa arriscar.
- `chance_morrer` e o limiar de energia são valores aproximados.
- O agente usa a posição fornecida pelo jogo depois de um teletransporte, como no projeto-base.
- Depois dos 3 ouros, ele para em vez de voltar a [1,1]: o retorno só custaria pontos, pois não há recompensa no código-base.
