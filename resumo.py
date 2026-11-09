# Le resultados/resultados.csv e gera resultados/resumo.md
import csv
from collections import defaultdict

grupos = defaultdict(list)
with open('resultados/resultados.csv', encoding='utf-8') as f:
    for l in csv.DictReader(f):
        grupos[(l['mapa'], l['modo'])].append(l)

media = lambda ls, c: sum(float(l[c]) for l in ls) / len(ls)
linhas = ['| Mapa | Modo | Partidas | Pontuação média | Ouro médio | Sobrevivência | Ações médias | Mortes em poço | Mortes por inimigo | Limite |',
          '|---|---|---|---|---|---|---|---|---|---|']
for (mapa, modo), ls in grupos.items():
    vivos = sum(l['sobreviveu'] == 'sim' for l in ls) / len(ls) * 100
    conta = lambda x: sum(l['fim'] == x for l in ls)
    linhas.append(f"| {mapa} | {modo} | {len(ls)} | {media(ls,'pontuacao'):.0f} | {media(ls,'ouro'):.2f} | {vivos:.0f}% | "
                  f"{media(ls,'acoes'):.0f} | {conta('morte_poco')} | {conta('morte_inimigo')} | {conta('limite')} |")
texto = '\n'.join(linhas) + '\n'
open('resultados/resumo.md', 'w', encoding='utf-8').write(texto)
print(texto)
