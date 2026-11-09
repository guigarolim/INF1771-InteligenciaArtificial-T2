%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Testes sem interface
%% uso: swipl -q -g rodar_testes -g halt testes.pl
%% O mapa real so e usado aqui para dizer a causa da morte no relatorio.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:-consult('main.pl').

mapas(['mapa-facil.pl','mapa_facil.pl','mapa.pl','mapa-dificil.pl','mapa_dificil.pl']).
sementes(100).
limite_acoes(3000).

rodar_testes :-
    open('resultados/resultados.csv', write, S),
    format(S, "mapa,modo,semente,pontuacao,ouro,energia,sobreviveu,acoes,fim~n", []),
    mapas(Mapas), sementes(N),
    forall((member(M, Mapas), member(Modo, [com_risco, sem_risco]), between(1, N, Sem)),
           (partida(M, Modo, Sem, Linha), format(S, "~w,~w,~w,~w,~w,~w,~w,~w,~w~n", Linha))),
    close(S).

partida(Mapa, Modo, Sem, [Mapa, Modo, Sem, P, O, E, V, A, Fim]) :-
    set_random(seed(Sem)),
    retractall(sem_risco),
    (Modo = sem_risco -> assert(sem_risco) ; true),
    reiniciar(Mapa),
    verifica_player, agente_percebe,
    joga(0, A, Fim),
    pontuacao(P), ouros_coletados(O), energia(E),
    (posicao(_, _, morto) -> V = nao ; V = sim).

joga(N, N, morte_poco)    :- posicao(X, Y, morto), tile(X, Y, 'P'), !.
joga(N, N, morte_inimigo) :- posicao(_, _, morto), !.
joga(N, N, limite)        :- limite_acoes(N), !.
joga(N, Total, Fim) :-
    executa_acao(Acao),
    (Acao = parar -> Total = N, (ouros_coletados(3) -> Fim = todos_ouros ; Fim = parou)
    ; call(Acao), verifica_player, agente_percebe,
      N1 is N + 1, joga(N1, Total, Fim)).
