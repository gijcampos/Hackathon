extends RefCounted
## Banco de eventos do jogo.
##
## A lista em all() está VAZIA: o jogo roda normalmente sem eventos.
## Para criar um evento, copie o MODELO abaixo para dentro de all(), tire os "#"
## e ajuste os campos. Veja GDD.md, seção "Como adicionar eventos".
##
## ---------------------------------------------------------------- MODELO
##	{
##		"id": "vazamento_valvula",            # único, sem espaços
##		"title": "Vazamento em uma válvula",
##		"text": "{name} ouviu um chiado perto da eclusa. Uma válvula está perdendo ar.",
##		"fact": "Em 2020 a tripulação da ISS rastreou um vazamento no módulo Zvezda usando folhas de chá.",
##
##		# --- QUANDO acontece (escolha um jeito) ---
##		"weight": 1.5,        # aleatório: peso no sorteio (maior = mais frequente)
##		"min_day": 5,         # aleatório: não acontece antes deste dia
##		"cooldown": 15,       # aleatório: dias mínimos até poder repetir
##		"requires": {"integrity_below": 90},   # aleatório: condições (opcional)
##		# "on_days": [20, 40],                 # agendado: acontece exatamente nesses dias
##		# "on_moon_phase": 17,                 # agendado: todo ciclo, 2 dias antes da penumbra
##
##		# --- efeitos imediatos ao aparecer (opcional) ---
##		"on_trigger": {"o2": -5, "integrity": -8},
##
##		# --- escolhas (1 a 4) ---
##		"choices": [
##			{"label": "Trocar a válvula", "desc": "3 peças. Problema resolvido.",
##				"cost": {"parts": 3}, "effects": {"integrity": 8}},
##			{"label": "Remendar com fita", "desc": "Sem custo, 30% de chance de piorar.",
##				"effects": {"risk": {"chance": 0.3, "log": "O remendo cedeu!", "effects": {"o2": -10}}}},
##		],
##	},
##
## ---------------------------------------------------------------- CONDIÇÕES ("requires")
##	"energy_below": 100       energia armazenada abaixo de 100 kWh
##	"integrity_below": 70     integridade abaixo de 70
##	"no_mod": "blight"        só se o modificador NÃO estiver ativo
##	"dark": true              só durante a escuridão lunar (false = só com sol)
##	"reactor": 1              qualquer construção: precisa ter pelo menos N
##	                          (solar, vsat, rtg, ridge_cable, reactor, battery, rfc,
##	                           wadi, greenhouse, led, recycler, isru, water_wall)
##
## ---------------------------------------------------------------- CUSTOS ("cost")
##	"parts", "water", "energy"    o botão fica desativado se não houver o suficiente
##
## ---------------------------------------------------------------- EFEITOS
## Números podem ser fixos (10) ou um intervalo sorteado ([5, 15]).
##	"o2", "water", "food", "parts", "energy"     soma ao estoque (use negativo para tirar)
##	"integrity", "crop_health"                   soma (0 a 100)
##	"shield_layers"                              soma (0 a 4)
##	"health_all"       saúde de todos os vivos
##	"health_target"    saúde do tripulante citado como {name} no texto
##	"health_random"    saúde de um tripulante aleatório
##	"dose_all"         mSv para todos;  "dose_team": mSv para 2 tripulantes
##	"mods": {"recycler_fail": 10}   ativa modificadores por N dias:
##	        recycler_fail, blight, reactor_off, solar_dim
##	"remove_mods": ["blight"]
##	"work_block": "shelter"    ninguém trabalha amanhã: todos no abrigo
##	"set_alloc": {"lab": 0.0}  muda um controle de energia
##	"add_building" / "lose_building": "solar"   (ganha/perde uma construção pronta)
##	"risk": {"chance": 0.2, "log": "texto", "effects": {...}}   efeito com chance
##	"log": "texto"              escreve no diário de bordo
##
## ---------------------------------------------------------------- RADIAÇÃO
## Um evento com "radiation": [40, 180] sorteia uma dose e preenche {work} e {shelter}
## no texto com a dose prevista. Nas escolhas, use "effects": {"radiation": "shelter"}
## (vai ao abrigo, sem trabalho amanhã) ou {"radiation": "work"}.
##
## ---------------------------------------------------------------- TEXTO
## {name} = um tripulante vivo sorteado. Aceita BBCode: [b]negrito[/b], [i]itálico[/i].


static func get_event(id: String) -> Dictionary:
	for e in all():
		if e["id"] == id:
			return e
	return {}


static func all() -> Array:
	return [
		# Adicione seus eventos aqui.
	]
