# Posto Avançado — Documento de Design (GDD)

> Simulador de gestão de um posto avançado na **Lua** ou em **Marte**. O jogador comanda
> uma tripulação de 4 pessoas e precisa equilibrar **suporte à vida, proteção contra
> radiação, energia e produção de alimentos** até o fim da missão. Cada decisão tem um
> custo — e o jogo mostra, com fatos reais, por que esses dilemas existem.

## 1. Visão e objetivo pedagógico

- **Fantasia:** "Sou o comandante. Se eu errar a conta de energia, alguém pode não voltar."
- **Aprendizado:** os recursos de uma base espacial são *acoplados*. Oxigênio vem da água
  (eletrólise); a estufa produz comida mas consome muita energia; a água que protege da
  radiação é a mesma que a tripulação bebe; a EVA que constrói blindagem expõe a equipe.
- **Fatos reais:** todo evento traz um quadro "Fato real" (Apollo 16/17, Opportunity,
  MOXIE, Chang'e 4, Mars‑500, ISS...). A tela final traz "Lições da missão" geradas a
  partir do que aconteceu na partida.

## 2. Loop principal (turno = 1 dia / 1 sol)

1. **Planejar:** distribuir energia entre os sistemas (sliders 0–150%) e alocar os 4
   tripulantes em tarefas.
2. **Prever:** o painel "Previsão para amanhã" mostra o saldo de cada recurso e alertas
   (CO₂ subindo, frio, apagão, estoque acabando em N dias).
3. **Construir:** gastar peças sobressalentes (1 construção por dia).
4. **Avançar o dia:** a simulação roda; pode surgir um **evento com escolha**.
5. Repetir até o fim da missão (Lua: 60 dias, Marte: 80 sóis).

## 3. Recursos

| Recurso | Fonte | Consumo | Se acabar |
|---|---|---|---|
| Oxigênio (kg) | Eletrólise (suporte de vida), estufa, ISRU | 0,84 kg/pessoa/dia, vazamentos | −30 saúde/dia |
| Água (L) | Reciclagem (93% a 100% de energia), ISRU, cargas | 3,5 L/pessoa/dia, eletrólise (1,125 L/kg O₂), estufa | −15 saúde/dia |
| Comida (rações) | Estufa (luz + agricultor + saúde das plantas), cargas | 1/pessoa/dia | −4 saúde/dia, moral cai |
| Energia (kWh) | Painéis solares, reator de fissão; bateria armazena | Soma dos sistemas | Apagão: todos os sistemas operam proporcionalmente menos |
| Peças | Estoque inicial, cargas (Lua), impressão 3D | Construções e reparos | Sem construir/reparar |
| Integridade (%) | Manutenção | Desgaste diário, impactos | <50%: vazamento de O₂ e máquinas perdem eficiência; 0% = perda do habitat |
| Moral (%) | Descanso, comida fresca da estufa | Isolamento, sobrecarga, apagões, mortes | Afeta produtividade; 0% = evacuação |
| Dose de radiação (mSv) | Ambiente, EVA, tempestades solares | — | >250 mSv (limite de missão): perda de saúde |
| Ciência (pts) | Laboratório + cientistas, expedições | — | Define o grau de sucesso |

## 4. Sistemas de energia (sliders)

| Sistema | Demanda a 100% | Efeito | Abaixo do ideal |
|---|---|---|---|
| Suporte de vida | 12 kWh/pessoa | Gera O₂, filtra CO₂, recicla água | <60%: CO₂ acumula (saúde) |
| Estufa | 35 kWh/módulo | Comida, um pouco de O₂, moral | <50%: plantas morrem aos poucos |
| Controle térmico | Lua: 8 (dia) / 30 (noite); Marte: 26 | Mantém o habitat habitável | <70%: frio (saúde) |
| Laboratório | 20 kWh | Ciência | — |
| ISRU | 30 kWh/unidade | Lua: água do gelo; Marte: O₂ do CO₂ | — |

Se a demanda passar de geração + bateria, ocorre **apagão proporcional**: o jogador
aprende a cortar o que é menos essencial antes que o sistema corte tudo.

## 5. Tarefas da tripulação

- **Manutenção:** +integridade (o desgaste é contínuo; poeira e tempestades aceleram).
- **Agricultura:** multiplica a produção da estufa (1 agricultor cuida bem de 2 módulos).
- **Ciência:** multiplica a produção do laboratório.
- **EVA:** constrói camadas de regolito sobre o habitat (−15% de radiação cada, até 4) e,
  em Marte, limpa os painéis. Risco de acidente e dose extra.
- **Descanso:** moral e recuperação de saúde.

Produtividade = 60% + 40% × moral.

## 6. Construções

| Construção | Custo | Efeito |
|---|---|---|
| Painel solar | 8 peças | Lua 30 kWh/dia (com sol), Marte 14 kWh/sol (com poeira) |
| Bateria | 6 peças | +150 kWh de armazenamento |
| Reator de fissão (tipo Kilopower) | 35 peças | +120 kWh/dia constantes, máx. 2 |
| Módulo de estufa | 14 peças | +1,5 rações/dia (ideal), máx. 4 |
| Unidade ISRU | 18 peças | Recursos locais, máx. 3 |
| Parede de água no abrigo | 5 peças + 300 L de água | Abrigo contra tempestade solar muito mais eficiente |

## 7. Os dois cenários

| | Lua — Borda de Shackleton | Marte — Cratera Jezero |
|---|---|---|
| Duração | 60 dias | 80 sóis |
| Radiação | 1,35 mSv/dia (sem atmosfera) | 0,65 mSv/sol (atmosfera fina ajuda) |
| Energia | Sol forte, mas **5 dias de escuridão** (mais penumbra) a cada ciclo de ~29 dias | Sol fraco + poeira nos painéis + **tempestades de poeira**; começa com reator |
| Apoio | Cargas da Terra nos dias 20 e 40 (escolha o que vem) | Sem reabastecimento; **conjunção solar** corta comunicação no sol 45 |
| Dificuldade | Planejamento de picos de energia e radiação | Autossuficiência de longo prazo |

## 8. Eventos (com escolha)

Tempestade de partículas solares · Tempestade de poeira · Micrometeoroide · Falha no
reciclador de água · Fungo na estufa · Conflito na tripulação · Tripulante doente ·
Descoberta científica · Desgaste por poeira lunar · Desligamento do reator · Impressão 3D
de peças · Mensagem da Terra · Redemoinhos de poeira · Chegada de carga (Lua) · Noite
lunar (aviso) · Conjunção solar (Marte).

Cada evento mostra os números da decisão (ex.: "abrigo: ~18 mSv; continuar: ~96 mSv").

## 9. Vitória e derrota

- **Derrota:** toda a tripulação morre, moral chega a 0 (evacuação) ou integridade 0.
- **Vitória:** sobreviver até o fim. Nota de **S a D**: sobreviventes (48), ciência vs. meta (25),
  dose média (17) e moral (10). Dose média acima do limite limita a nota a B.

## 10. Roadmap sugerido

1. ✅ Protótipo jogável (este repositório): simulação, UI, eventos, dois cenários.
2. Tripulantes com especialidade (engenheiro repara mais rápido, médico cura).
3. Atribuir tarefas por pessoa (quem faz EVA acumula dose).
4. Mapa da base com módulos posicionáveis e rede elétrica.
5. Gráficos de histórico (o estado já registra `history` diário).
6. Modo campanha: Lua → Marte com tecnologias desbloqueadas.
7. Arte, som ambiente e traduções.

## 11. Estrutura técnica

```
project.godot
scenes/main.tscn          cena raiz (só um Control com main.gd)
scripts/game_state.gd     simulação pura, sem UI (testável em headless)
scripts/events_db.gd      dados dos eventos e escolhas
scripts/main.gd           menu, HUD, painéis, diálogo de evento, tela final
scripts/base_view.gd      desenho 2D procedural da base
tests/balance_test.gd     simula centenas de partidas para calibrar o equilíbrio
```

Rodar o teste de balanceamento:

```
godot --headless --path . --script res://tests/balance_test.gd
```

Atalho de desenvolvimento (pula o menu e avança N dias):

```
godot --path . -- --autostart=moon --days=18
```

### Resultado atual do balanceamento (200 partidas por linha)

| Cenário | Política | Vitórias | Observação |
|---|---|---|---|
| Lua | passiva (não mexe em nada) | ~37% | morre na escuridão lunar; nota quase sempre D |
| Lua | atenta (antecipa a escuridão, constrói baterias/painéis) | ~97% | notas S/A |
| Marte | passiva | ~89% | sobrevive, mas dose alta e pouca ciência: notas B/C |
| Marte | heurística simples | variável | a parede de água + cortes no ISRU esgotam a água |

Próximo ajuste sugerido: deixar Marte passivo mais difícil (ex.: tempestades mais longas).
