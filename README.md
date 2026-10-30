# Projeto-Analu

Cronograma SES-DF 2027
======================

Como abrir
----------
1. Dê dois cliques em Iniciar.bat.
2. O navegador abre sozinho. Se não abrir, acesse http://127.0.0.1:8765/
3. Deixe a janela preta aberta enquanto estiver estudando.
   Fechar essa janela encerra o salvamento em arquivo.

Onde ficam os dados
-------------------
Pasta dados\cronograma.json
(ao lado deste arquivo, dentro da pasta do cronograma).

O arquivo é criado quando você abre pelo Iniciar.bat.
Cada revisão, aula e plantão é gravado nele automaticamente.

Se você já usava o cronograma neste navegador, na primeira
abertura pelo Iniciar.bat o progresso guardado no navegador
é copiado para esse arquivo.

Como fazer backup
-----------------
Copie a pasta dados para um pendrive, OneDrive ou outro lugar.
Para voltar um backup, feche a janela preta, substitua a pasta
dados e abra de novo pelo Iniciar.bat.

Se a porta estiver ocupada
--------------------------
A janela preta avisa que a porta 8765 já está em uso.

Isso acontece quando o cronograma já está aberto: feche a
janela preta extra e use a janela que já estava aberta.

Se não houver outra janela do cronograma, outro programa está
usando essa porta. Feche esse programa e dê dois cliques em
Iniciar.bat outra vez.

Se abrir o arquivo HTML direto
------------------------------
O cronograma precisa do Iniciar.bat para gravar no arquivo.
Se você abrir o HTML com dois cliques, a tela avisa e o
progresso fica só naquele navegador.

Como usar a tela
----------------
A tela tem três abas (no celular, ficam na barra de baixo):

- Semana: a semana em foco, com as revisões para marcar, os
  pendentes de semanas anteriores, o campo para registrar uma
  aula assistida (digite e aperte Enter) e os dias de plantão.
  As setas trocam de semana e "Ir para semana atual" volta.
  Em Revisões, use Editar para renomear, adicionar ou remover
  temas (e, se quiser, remover a semana inteira).
- Cronograma: todas as semanas em lista ou em calendário.
  Clique numa semana (ou num dia do calendário) para ver só as
  tarefas dela. Em Editar, o "⋯" vira um X vermelho para
  remover a semana; no fim da lista dá para adicionar outra.
  Para editar temas, use a aba Semana.
- Aulas: histórico de todas as aulas registradas, com busca.

No header, o botão "Adicionar Atividades" abre um modal para
enviar um .txt ou escrever subtópicos de Clínica, Cirurgia,
Preventivo e Pediatria. Ao salvar, o sistema cria semanas no
final do cronograma, misturando um subtópico de cada área
(e preenchendo as sobras quando as listas têm tamanhos
diferentes).

Data de início
--------------
No fim da aba Semana, use "Definir data de início" e escolha o
dia em que a semana 1 começa. As semanas vão de segunda a
domingo, e a semana atual é sempre a que contém a data de
hoje (não depende do status das revisões). Sem data de início,
nenhuma semana fica marcada como atual. A data também é
gravada no arquivo.
