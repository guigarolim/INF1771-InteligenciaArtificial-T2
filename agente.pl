%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% INF1771 - Trabalho 2 - Agente logico
%%
%% Ciclo: acao -> verifica_player -> agente_percebe -> executa_acao
%%
%% IMPORTANTE: tile/3 (mapa real) so e lido pelos sensores.
%% Nada abaixo da secao "Sensores" olha o mapa.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:-dynamic percebeu/3.          % percebeu(X,Y,L): o que senti na casa (X,Y)
:-dynamic dano_em/2.           % casa onde tomei dano (tem inimigo)
:-dynamic teleporte_em/2.      % casa que me teleportou
:-dynamic destino/2.           % casa para onde mandei andar
:-dynamic plano/1.             % lista de acoes que ainda vou executar
:-dynamic energia_anterior/1.
:-dynamic ouros_coletados/1.
:-dynamic encerrado/0.
:-dynamic atravessando/0.      % so durante o planejamento de ultimo recurso
:-dynamic sem_risco/0.         % se existir, o agente nunca arrisca (usado nos testes)

limpa_agente :-
    retractall(percebeu(_,_,_)), retractall(dano_em(_,_)),
    retractall(teleporte_em(_,_)), retractall(destino(_,_)),
    retractall(plano(_)), retractall(encerrado), retractall(atravessando),
    retractall(energia_anterior(_)), retractall(ouros_coletados(_)),
    assert(energia_anterior(100)), assert(ouros_coletados(0)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Sensores - UNICA parte que olha o mapa real
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% lista do que da para sentir vindo das casas vizinhas
observacoes(X) :- adjacentes(L), findall(Y, observacao_adj(Y, L), X).

% junta o que vem das vizinhas (brisa, palmas, passos)
% com o que esta na propria casa (brilho, reflexo)
percepcoes_atuais(Lista) :-
    posicao(X, Y, _),
    tile(X, Y, Conteudo),
    observacoes(Vizinhas),
    findall(O, observacao_loc(O, [Conteudo]), Locais),
    append(Vizinhas, Locais, Todas),
    sort(Todas, Lista).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Atualizacao da base de conhecimento
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% chamado depois de cada acao
agente_percebe :-
    detecta_teleporte,
    detecta_dano,
    marca_visitado,
    registra_percepcao.

% mandei andar para uma casa e fui parar em outra: ela e um teleporte
detecta_teleporte :-
    destino(X, Y),
    \+ posicao(X, Y, _),
    !,
    assert_unico(teleporte_em(X, Y)),
    retractall(plano(_)),
    retractall(destino(_,_)).
detecta_teleporte :- retractall(destino(_,_)).

% a energia caiu: tem inimigo na casa onde estou
detecta_dano :-
    energia(E), energia_anterior(A),
    E < A,
    !,
    posicao(X, Y, _),
    assert_unico(dano_em(X, Y)),
    retractall(plano(_)),
    guarda_energia(E).
detecta_dano :- energia(E), guarda_energia(E).

guarda_energia(E) :- retractall(energia_anterior(_)), assert(energia_anterior(E)).

marca_visitado :- posicao(X, Y, _), assert_unico(visitado(X, Y)).

% guarda o que foi sentido; o retractall tira o brilho depois de pegar o ouro
registra_percepcao :-
    posicao(X, Y, _),
    percepcoes_atuais(Lista),
    retractall(percebeu(X, Y, _)),
    assert(percebeu(X, Y, Lista)).

assert_unico(Fato) :- Fato, !.
assert_unico(Fato) :- assert(Fato).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Geometria
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dentro(X, Y) :- map_size(MX, MY), X >= 1, X =< MX, Y >= 1, Y =< MY.

casa(X, Y) :- map_size(MX, MY), between(1, MX, X), between(1, MY, Y).

vizinha(X, Y, A, B) :-
    member((DX, DY), [(1,0), (-1,0), (0,1), (0,-1)]),
    A is X + DX, B is Y + DY,
    dentro(A, B).

frente(X, Y, norte, X, B) :- B is Y + 1.
frente(X, Y, sul,   X, B) :- B is Y - 1.
frente(X, Y, leste, A, Y) :- A is X + 1.
frente(X, Y, oeste, A, Y) :- A is X - 1.

direita(norte, leste).
direita(leste, sul).
direita(sul, oeste).
direita(oeste, norte).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Regras de inferencia
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% cada perigo e a percepcao que ele causa nas vizinhas
perigo(poco, brisa).
perigo(inimigo, passos).
perigo(teleporte, palmas).

% descartado(Tipo,X,Y): tenho certeza de que NAO ha esse perigo em (X,Y)
descartado(poco, X, Y) :- visitado(X, Y), !.
descartado(teleporte, X, Y) :- visitado(X, Y), !.
descartado(inimigo, X, Y) :- visitado(X, Y), \+ dano_em(X, Y), !.
descartado(Tipo, X, Y) :-
    perigo(Tipo, Sinal),
    vizinha(X, Y, A, B),
    percebeu(A, B, L),
    \+ memberchk(Sinal, L),
    !.

% casas vizinhas de (A,B) que ainda podem conter o perigo
possiveis(Tipo, A, B, Lista) :-
    findall((X, Y), (vizinha(A, B, X, Y), \+ descartado(Tipo, X, Y)), Lista).

% confirmado(Tipo,X,Y): tenho certeza de que HA esse perigo em (X,Y)
confirmado(teleporte, X, Y) :- teleporte_em(X, Y), !.
confirmado(inimigo, X, Y) :- dano_em(X, Y), !.
confirmado(Tipo, X, Y) :-
    perigo(Tipo, Sinal),
    vizinha(X, Y, A, B),
    percebeu(A, B, L),
    memberchk(Sinal, L),
    possiveis(Tipo, A, B, [(X, Y)]),   % ela e a unica explicacao do sinal
    !.

% uma casa e segura quando os tres perigos foram descartados
seguro(X, Y) :-
    descartado(poco, X, Y),
    descartado(inimigo, X, Y),
    descartado(teleporte, X, Y).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Avaliacao de risco
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% chance de cada perigo em uma casa sem nenhuma pista (dados do enunciado)
priori(poco, P)      :- P is 8 / 144.
priori(inimigo, P)   :- P is 4 / 144.
priori(teleporte, P) :- P is 4 / 144.

% probabilidade estimada de haver o perigo em (X,Y)
prob(Tipo, X, Y, 0.0) :- descartado(Tipo, X, Y), !.
prob(Tipo, X, Y, 1.0) :- confirmado(Tipo, X, Y), !.
prob(Tipo, X, Y, P) :-
    perigo(Tipo, Sinal),
    findall(Q, (vizinha(X, Y, A, B), percebeu(A, B, L), memberchk(Sinal, L),
                chance_por_sinal(Tipo, A, B, Q)), Qs),
    (Qs = [] -> priori(Tipo, P) ; max_list(Qs, P)).

% se um perigo confirmado ja explica o sinal, ele nao diz nada sobre as outras
chance_por_sinal(Tipo, A, B, P) :-
    possiveis(Tipo, A, B, Lista),
    member((X, Y), Lista),
    confirmado(Tipo, X, Y),
    !,
    priori(Tipo, P).
chance_por_sinal(Tipo, A, B, P) :-
    possiveis(Tipo, A, B, Lista),
    length(Lista, N),
    P is 1 / N.

% chance de morrer se entrar em uma casa de inimigo (dano de 25 a 80)
chance_morrer(E, 0.1) :- E > 80, !.
chance_morrer(E, 0.4) :- E > 50, !.
chance_morrer(_, 0.8).

% PPoco: chance de cair em poco; PMorte: chance de morrer de qualquer forma.
% Um teleporte manda para uma casa sorteada, entao soma a chance do destino.
chances(X, Y, PPoco, PMorte) :-
    prob(poco, X, Y, Pp),
    prob(inimigo, X, Y, Pi),
    prob(teleporte, X, Y, Pt),
    energia(E),
    chance_morrer(E, M),
    PPoco is Pp + Pt * 8 / 140,
    PInimigo is Pi + Pt * 4 / 140,
    PMorte is PPoco + PInimigo * M.

% quanto ainda da para ganhar: ouro restante x parte do mapa desconhecida
ganho_esperado(G) :-
    ouros_coletados(C),
    aggregate_all(count, (casa(X, Y), \+ visitado(X, Y)), Desconhecidas),
    G is (3 - C) * 495 * Desconhecidas / 144.

% valor esperado de entrar na casa (positivo = vale a pena)
valor_casa(X, Y, V) :-
    ganho_esperado(G),
    chances(X, Y, PPoco, PMorte),
    V is (1 - PMorte) * G - PPoco * 1000.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Planejamento (busca em largura em X, Y e direcao, pois virar tambem custa)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% caminho_ate(+Alvos, -Acoes): menor lista de acoes ate uma casa de Alvos
caminho_ate(Alvos, Acoes) :-
    posicao(X, Y, D),
    bfs([no(X, Y, D, [])], [(X, Y, D)], Alvos, Invertido),
    reverse(Invertido, Acoes).

bfs([no(X, Y, _, Acoes) | _], _, Alvos, Acoes) :-
    memberchk((X, Y), Alvos), !.
bfs([no(X, Y, D, Acoes) | Fila], Vistos, Alvos, Resposta) :-
    findall(no(NX, NY, ND, [A | Acoes]),
            (sucessor(X, Y, D, A, NX, NY, ND, Alvos),
             \+ memberchk((NX, NY, ND), Vistos)),
            Novos),
    findall((NX, NY, ND), member(no(NX, NY, ND, _), Novos), Estados),
    append(Vistos, Estados, Vistos2),
    append(Fila, Novos, Fila2),
    bfs(Fila2, Vistos2, Alvos, Resposta).

sucessor(X, Y, D, virar_direita, X, Y, ND, _) :- direita(D, ND).
sucessor(X, Y, D, virar_esquerda, X, Y, ND, _) :- direita(ND, D).
sucessor(X, Y, D, andar, NX, NY, D, Alvos) :-
    frente(X, Y, D, NX, NY),
    dentro(NX, NY),
    pode_pisar(NX, NY, Alvos).

% so anda por casas conhecidas; casa desconhecida so se for o alvo
pode_pisar(X, Y, Alvos) :- memberchk((X, Y), Alvos), !.
pode_pisar(X, Y, _) :- visitado(X, Y), \+ dano_em(X, Y), !.
pode_pisar(X, Y, _) :- atravessando, dano_em(X, Y).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Politica de acoes (regras em ordem de prioridade)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

executa_acao(A) :- decide(A), registra_decisao(A), !.

decide(parar) :- encerrado, !.
decide(parar) :- ouros_coletados(3), !.
decide(pegar) :- aqui(brilho), !.
decide(A)     :- estou_em_inimigo, fugir(A), !.
decide(pegar) :- aqui(reflexo), energia(E), E =< 80, !.
decide(A)     :- plano([A | Resto]), troca_plano(Resto), !.
decide(A)     :- novo_plano([A | Resto]), troca_plano(Resto), !.
decide(parar).

aqui(Sinal) :- posicao(X, Y, _), percebeu(X, Y, L), memberchk(Sinal, L).

estou_em_inimigo :- posicao(X, Y, _), dano_em(X, Y).

troca_plano(Resto) :- retractall(plano(_)), assert(plano(Resto)).

% memoria do que foi decidido, para detectar teleporte e contar ouro
registra_decisao(andar) :-
    posicao(X, Y, D), frente(X, Y, D, A, B),
    retractall(destino(_,_)), assert(destino(A, B)), !.
registra_decisao(pegar) :-
    aqui(brilho),
    ouros_coletados(C), retractall(ouros_coletados(_)),
    C1 is C + 1, assert(ouros_coletados(C1)), !.
registra_decisao(_).

% 1) recuperar energia  2) explorar casa segura  3) arriscar se valer a pena
novo_plano(Acoes) :-
    energia(E), E =< 80,
    posicao(PX, PY, _),
    findall((X, Y), (percebeu(X, Y, L), memberchk(reflexo, L), (X, Y) \= (PX, PY)), Alvos),
    Alvos \= [],
    caminho_ate(Alvos, Acoes), !.
novo_plano(Acoes) :-
    findall((X, Y), (casa(X, Y), \+ visitado(X, Y), seguro(X, Y)), Alvos),
    Alvos \= [],
    caminho_ate(Alvos, Acoes), !.
novo_plano(Acoes) :-
    \+ sem_risco,
    opcoes_de_risco(Opcoes),
    member((X, Y), Opcoes),
    caminho_ate([(X, Y)], Acoes), !.
novo_plano(Acoes) :-      % ultimo recurso: preso atras de um inimigo conhecido
    \+ sem_risco,
    energia(E), E > 50,
    opcoes_de_risco(Opcoes),
    assert(atravessando),
    (   member((X, Y), Opcoes), caminho_ate([(X, Y)], Acoes)
    ->  retract(atravessando)
    ;   retract(atravessando), fail
    ).

% casas na fronteira do conhecido com valor positivo, da melhor para a pior
opcoes_de_risco(Opcoes) :-
    findall(V-(X, Y), (fronteira(X, Y), valor_casa(X, Y, V), V > 0), Pares),
    keysort(Pares, Crescente),
    reverse(Crescente, Decrescente),
    findall(C, member(_-C, Decrescente), Opcoes).

fronteira(X, Y) :-
    casa(X, Y),
    \+ visitado(X, Y),
    \+ confirmado(poco, X, Y),
    \+ confirmado(inimigo, X, Y),
    once((vizinha(X, Y, A, B), visitado(A, B))).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Fuga: cada acao parada em casa de inimigo causa dano de novo
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fugir(Acao) :-
    posicao(X, Y, D),
    findall(C-A, opcao_fuga(X, Y, D, C, A), Opcoes),
    keysort(Opcoes, [_-Acao | _]).

opcao_fuga(X, Y, D, Custo, Acao) :-
    giro(D, ND, Giros, Acao),
    frente(X, Y, ND, NX, NY),
    dentro(NX, NY),
    \+ confirmado(poco, NX, NY),
    \+ confirmado(inimigo, NX, NY),
    chances(NX, NY, _, PMorte),
    Custo is PMorte + 0.5 * Giros.

giro(D, D, 0, andar).
giro(D, ND, 1, virar_direita)  :- direita(D, ND).
giro(D, ND, 1, virar_esquerda) :- direita(ND, D).
giro(D, ND, 2, virar_direita)  :- direita(D, M), direita(M, ND).

parar :- assert(encerrado).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Mostra na interface o que o agente sabe (memory e certeza sao lidos pelo gmap.py)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

atualiza_interface :-
    retractall(memory(_,_,_)),
    retractall(certeza(_,_)),
    forall(casa(X, Y), mostra_casa(X, Y)).

mostra_casa(X, Y) :-
    findall(Sinal, sinal_da_casa(X, Y, Sinal), Sinais),
    (Sinais \= [] -> assert(memory(X, Y, Sinais)) ; true),
    (certa(X, Y) -> assert(certeza(X, Y)) ; true).

certa(X, Y) :- seguro(X, Y), !.
certa(X, Y) :- perigo(Tipo, _), confirmado(Tipo, X, Y), !.

sinal_da_casa(X, Y, Sinal) :- percebeu(X, Y, L), member(Sinal, [brilho, reflexo]), memberchk(Sinal, L).
sinal_da_casa(X, Y, Sinal) :-
    perigo(Tipo, Sinal),
    \+ descartado(Tipo, X, Y),
    tem_pista(Tipo, X, Y).

tem_pista(Tipo, X, Y) :- confirmado(Tipo, X, Y), !.
tem_pista(Tipo, X, Y) :- perigo(Tipo, S), vizinha(X, Y, A, B), percebeu(A, B, L), memberchk(S, L), !.
