# Posto Avançado — Documento de Design (GDD)

> Simulador de gestão de um posto avançado na **Lua**. O jogador comanda uma tripulação
> de 4 pessoas e constrói a base ao longo de 60 dias, equilibrando **energia, suporte à
> vida, proteção contra radiação e produção de alimentos**. O foco é a ciência e a
> engenharia da sobrevivência, não conflitos sociais.

## 1. Visão e objetivo pedagógico

- **Fantasia:** "Sou o comandante. Se eu errar a conta de energia, alguém pode não voltar."
- **Energia é o recurso central.** Tudo na base consome kWh, e cada sistema e cada
  construção mostra, ao passar o mouse, quanto gera, guarda ou consome.
- **Os recursos são acoplados:** o O₂ vem da água (eletrólise); a estufa produz comida
  mas consome muita energia; a água que protege da radiação é a que se bebe; a EVA que
  constrói blindagem expõe a equipe.
- A tela final traz "Lições da missão", geradas a partir do que aconteceu na partida.

## 2. Cenário: borda da cratera Shackleton (polo sul lunar)

- **Duração:** 60 dias.
- **Radiação:** 1,35 mSv/dia na superfície (sem atmosfera nem campo magnético).
- **Luz:** a cada ciclo de ~29 dias há **2 dias de penumbra, 5 de escuridão total e mais
  2 de penumbra** (a primeira escuridão começa no dia 22). Sem sol os painéis não geram
  e o aquecimento fica muito mais caro.
- **Começa pequeno:** a cúpula, 4 painéis solares, 1 bateria (150 kWh), 1 rack de
  estufa, 90 peças, 100 kg de O₂, 500 L de água e 180 rações. Não há reabastecimento.

## 3. Loop principal (turno = 1 dia)

1. **Planejar:** regular a energia de cada sistema (0–150%) e distribuir os 4 tripulantes
   entre as tarefas.
2. **Construir:** escolher obras (as peças são gastas na hora) que entram numa fila e
   avançam com a tarefa Construção.
3. **Prever:** o painel "Previsão para amanhã" mostra os saldos e alertas, incluindo
   quanto faltaria de energia para atravessar a próxima escuridão.
4. **Avançar o dia:** a simulação roda e pode surgir um evento com escolha.

## 4. Recursos

| Recurso | Fonte | Consumo | Se acabar |
|---|---|---|---|
| **Energia (kWh)** | Fontes de geração; armazenamento guarda o excedente | Todos os sistemas | Apagão: todos os sistemas perdem força proporcionalmente |
| Oxigênio (kg) | Eletrólise (suporte de vida), estufa, ISRU | 0,84 kg/pessoa/dia, vazamentos | −30 saúde/dia |
| Água (L) | Reciclagem (93%, ou 98% com melhoria), ISRU | 3,5 L/pessoa/dia, eletrólise (1,125 L/kg O₂), estufa | −15 saúde/dia |
| Comida (rações) | Estufa (luz + agricultor + saúde das plantas) | 1/pessoa/dia | −4 saúde/dia |
| Peças | Só o estoque inicial (90) | Construções | Sem novas obras |
| Integridade (%) | Manutenção | Desgaste diário (0,8%) | <50%: vazamento de O₂; 0% = derrota |
| Dose de radiação (mSv) | Ambiente, EVA, eventos | — | >250 mSv: perda de saúde |

A produtividade da equipe vale 50% + 50% × saúde média.

## 5. Sistemas (consumo de energia)

| Sistema | Consumo a 100% | Efeito | Abaixo do ideal |
|---|---|---|---|
| Suporte de vida | 12 kWh/pessoa | O₂, filtro de CO₂, reciclagem de água | <60%: CO₂ acumula |
| Estufa | 35 kWh/rack (23 com LEDs eficientes) | Comida e um pouco de O₂ | <50%: plantas morrem |
| Controle térmico | 8 (sol) / 18 (penumbra) / 30 (escuridão), menos economias | Calor | <70%: frio |
| ISRU | 30 kWh/unidade | +8 L de água e +1 kg de O₂ por dia | — |

## 6. Tarefas da tripulação

- **Manutenção:** +1,3% de integridade por pessoa.
- **Agricultura:** 1 agricultor cuida bem de 2 racks; sem agricultor a estufa rende 65%.
- **Construção:** 1 ponto de obra por pessoa por dia, aplicado à fila em ordem.
- **EVA: blindagem:** 4 pessoas-dia = 1 camada de regolito sobre a cúpula (−15% de
  radiação cada, até 4). Dose extra e 3% de chance de acidente.
- **Descanso:** recuperação de saúde mais rápida.

## 7. Construções

A base cresce ao longo do tempo: cada obra aparece como um andaime com o progresso e,
quando fica pronta, a estrutura passa a ser desenhada na base.

**Geração de energia**

| Construção | Peças | Obra | Energia |
|---|---|---|---|
| Painel solar | 8 | 2 | +30 kWh/dia com sol, +12 na penumbra, 0 no escuro |
| Torre solar vertical | 14 | 3 | +45 com sol, +31 na penumbra, 0 no escuro |
| Gerador de radioisótopo (RTG) | 18 | 2 | +12 sempre; calor residual: aquecimento −4 |
| Linha até a crista iluminada | 24 | 8 | +40 sempre (painéis numa crista que não escurece) |
| Reator de fissão | 40 | 10 | +120 sempre (máx. 1) |

**Armazenamento de energia**

| Construção | Peças | Obra | Efeito |
|---|---|---|---|
| Bateria de íons de lítio | 8 | 2 | +150 kWh, eficiência de carga 90% |
| Célula a combustível regenerativa | 16 | 4 | +400 kWh, eficiência de carga 55% |
| Reservatório térmico de regolito | 10 | 3 | Aquecimento −10 kWh/dia na penumbra e no escuro |

**Suporte à vida**

| Construção | Peças | Obra | Efeito |
|---|---|---|---|
| Rack de estufa | 14 | 4 | até +1,5 ração/dia; consome 35 kWh/dia (máx. 4) |
| LEDs de alta eficiência | 10 | 3 | Estufa consome 35% menos |
| Reciclador de água avançado | 12 | 4 | Recuperação de água de 93% para 98% |
| Unidade ISRU | 18 | 5 | +8 L de água e +1 kg de O₂/dia; consome 30 kWh/dia |
| Parede de água do abrigo | 5 + 300 L | 2 | Dose de eventos de radiação no abrigo cai para 6% |

## 8. A cúpula central

A cúpula é desenhada grande, no centro, **em corte**, com o interior visível:

- **Andar superior:** estufa com até 4 racks (as plantas mudam de cor com a saúde e a luz
  muda com a regulagem de energia).
- **Andar inferior:** suporte de vida (racks com luzes e ventilador), abrigo de radiação
  (com a parede de água, se construída) e dormitório.
- **Tripulantes:** aparecem onde estão trabalhando: na manutenção, na estufa, no
  dormitório, do lado de fora empilhando regolito (EVA) ou junto das obras.
- **Por fora:** camadas de regolito sobre a casca; à esquerda a área de energia (painéis,
  torres, baterias, células, reservatórios); à direita ISRU, RTGs, reator e a linha até a
  crista iluminada no horizonte.

**Tooltips:** passar o mouse sobre qualquer sala, estrutura, obra ou tripulante mostra
seus números (kWh gerados, guardados ou consumidos, progresso da obra, saúde e dose).
Os mesmos textos aparecem nos botões de construção, nos controles de energia e no topo
da tela.

## 9. Vitória e derrota

- **Derrota:** toda a tripulação morre ou a integridade chega a 0.
- **Vitória:** sobreviver os 60 dias. Nota de **S a D**: sobreviventes (60 pts), dose
  média (25) e integridade final (15). Dose média acima do limite limita a nota a B.

## 10. Eventos

O jogo está **sem eventos** no momento: a lista em `scripts/events_db.gd` está vazia.

### Como adicionar eventos

Um evento é um dicionário dentro da lista retornada por `all()` em
`scripts/events_db.gd`. O topo desse arquivo tem um **modelo comentado** e a referência
de todos os campos. Exemplo mínimo:

```gdscript
static func all() -> Array:
	return [
		{
			"id": "vazamento_valvula",
			"title": "Vazamento em uma válvula",
			"text": "{name} ouviu um chiado perto da eclusa. Uma válvula está perdendo ar.",
			"fact": "Em 2020 a tripulação da ISS rastreou um vazamento usando folhas de chá.",
			"weight": 1.5, "min_day": 5, "cooldown": 15,
			"on_trigger": {"o2": -5},
			"choices": [
				{"label": "Trocar a válvula", "desc": "3 peças.",
					"cost": {"parts": 3}, "effects": {"integrity": 5}},
				{"label": "Remendar com fita", "desc": "30% de chance de piorar.",
					"effects": {"risk": {"chance": 0.3, "log": "O remendo cedeu!", "effects": {"o2": -10}}}},
			],
		},
	]
```

**Quando o evento acontece**
- *Aleatório:* todo dia (a partir do dia 3) há 38% de chance de sortear um evento entre os
  elegíveis, ponderado por `weight`. `min_day`, `cooldown` e `requires` filtram quem entra.
- *Agendado:* `"on_days": [20, 40]` dispara exatamente nesses dias;
  `"on_moon_phase": 17` dispara em todo ciclo lunar (2 dias antes da penumbra).

**Condições (`requires`):** `integrity_below`, `energy_below`, `no_mod`, `dark`, ou o
nome de uma construção com a quantidade mínima (`{"reactor": 1}`).

**Custos (`cost`):** `parts`, `water`, `energy`. O botão fica desativado se faltar.

**Efeitos:** `o2`, `water`, `food`, `parts`, `energy`, `integrity`, `crop_health`,
`shield_layers`, `health_all`, `health_target`, `health_random`, `dose_all`,
`dose_team`, `radiation`, `mods`, `remove_mods`, `work_block`, `set_alloc`,
`add_building`, `lose_building`, `risk`, `log`. Os valores podem ser fixos (`10`) ou um
intervalo sorteado (`[5, 15]`).

**Texto:** `{name}` é um tripulante sorteado (afete-o com `health_target`). Eventos com
`"radiation": [min, max]` preenchem `{work}` e `{shelter}` com as doses previstas, e as
escolhas usam `{"radiation": "shelter"}` ou `{"radiation": "work"}`.

**Modificadores temporários** (`"mods": {"nome": dias}`): `recycler_fail`, `blight`,
`reactor_off`, `solar_dim`. Para criar um novo: adicione o nome em `MODIFIER_NAMES` no
`game_state.gd` e use `modifiers.has("nome")` dentro de `compute_flows()`.

Um efeito com nome errado gera o aviso "Efeito desconhecido em evento" no painel Saída.

### Como adicionar uma construção

1. Acrescente a entrada em `BUILDINGS` (nome, custo, obra, limite, descrição, fato) e o
   id na categoria certa de `BUILD_CATEGORIES`, em `scripts/game_state.gd`.
2. Dê o efeito: geração em `unit_generation()` e `generation_breakdown()`,
   armazenamento em `storage_capacity()`, ou consumo/produção em `compute_flows()`.
3. Escreva a linha de energia em `building_tooltip()`.
4. Desenhe-a em `scripts/base_view.gd` (`_draw_building()` e uma posição numa das zonas).

## 11. Roadmap sugerido

1. ✅ Protótipo jogável com base construída ao longo do tempo e cúpula em corte.
2. Escrever os eventos da missão (radiação solar, falhas, impactos).
3. Gráfico do histórico de energia (o estado já registra `history` diário).
4. Atribuir tarefas por pessoa (quem faz EVA acumula dose).
5. Arte, som ambiente e traduções.

## 12. Estrutura técnica

```
project.godot
scenes/main.tscn          cena raiz (só um Control com main.gd)
scripts/game_state.gd     simulação, catálogo de construções e textos de tooltip
scripts/events_db.gd      eventos (vazio) + modelo e referência
scripts/main.gd           menu, HUD, painéis, diálogo de evento, tela final
scripts/base_view.gd      desenho 2D da cúpula em corte e da base, com tooltips
tests/balance_test.gd     simula 200 partidas para calibrar o equilíbrio
```

Rodar o teste de balanceamento:

```
godot --headless --path . --script res://tests/balance_test.gd
```

Atalho de desenvolvimento (pula o menu e avança N dias):

```
godot --path . -- --autostart --days=18
```

### Balanceamento atual (sem eventos, 200 partidas)

| Política | Vitórias | Observação |
|---|---|---|
| Passiva (não constrói nada) | 0% | morre na primeira escuridão |
| Atenta (baterias, linha até a crista, reservatório térmico, estufa + LEDs) | 100% | nota S |
