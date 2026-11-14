extends RefCounted
## Banco de eventos. Cada evento tem escolhas com custos e efeitos (ver GameState.apply_effects).
## Placeholders {work}, {shelter}, {name}... são preenchidos ao disparar o evento.


static func get_event(id: String) -> Dictionary:
	for e in all():
		if e["id"] == id:
			return e
	return {}


static func all() -> Array:
	return [
		{
			"id": "spe",
			"title": "Alerta: tempestade de partículas solares",
			"text": "Satélites detectaram uma ejeção de massa coronal. Prótons de alta energia chegam em menos de uma hora.\n\nDose estimada por tripulante: [b]{work} mSv[/b] se continuarem trabalhando, ou [b]{shelter} mSv[/b] no abrigo ({wall}). Ficar no abrigo para todo o trabalho de amanhã.",
			"fact": "Em agosto de 1972, entre as missões Apollo 16 e 17, ocorreu uma das maiores tempestades solares já registradas. Astronautas na superfície lunar sem abrigo poderiam ter sofrido doença aguda da radiação.",
			"where": ["moon", "mars"],
			"weight": 3.0, "min_day": 4, "cooldown": 12,
			"choices": [
				{"label": "Todos para o abrigo", "desc": "~{shelter} mSv. Nenhum trabalho amanhã, moral cai pelo confinamento.", "effects": {"spe": "shelter"}},
				{"label": "Continuar trabalhando", "desc": "~{work} mSv. Doses acima de 100 mSv causam dano imediato à saúde.", "effects": {"spe": "work"}},
			],
		},
		{
			"id": "dust_storm",
			"title": "Tempestade de poeira regional",
			"text": "Uma tempestade de poeira se forma e deve cobrir a região por uma ou duas semanas. A luz solar nos painéis cairá cerca de 75% e o desgaste dos equipamentos aumenta.",
			"fact": "Em 2018 uma tempestade global de poeira cobriu Marte por meses. O rover Opportunity, movido a energia solar, ficou sem energia e a missão foi encerrada após 15 anos.",
			"where": ["mars"],
			"weight": 2.5, "min_day": 6, "cooldown": 20,
			"choices": [
				{"label": "Desligar o laboratório durante a tempestade", "desc": "Economiza 20 kWh/sol. Você pode religá-lo manualmente.", "effects": {"mods": {"dust_storm": [7, 12]}, "set_alloc": {"lab": 0.0}}},
				{"label": "Manter todos os sistemas ligados", "desc": "Contar com a bateria e o reator.", "effects": {"mods": {"dust_storm": [7, 12]}}},
			],
		},
		{
			"id": "micrometeoroid",
			"title": "Impacto de micrometeoroide",
			"text": "Um grão de rocha a dezenas de km/s perfurou a parede de um módulo de armazenamento. O ar está escapando pelo furo.",
			"fact": "A ISS é atingida por micrometeoroides com frequência. Seus módulos usam escudos Whipple: camadas finas espaçadas que pulverizam o projétil antes que atinja o casco.",
			"where": ["moon", "mars"],
			"weight": 1.5, "min_day": 5, "cooldown": 15,
			"on_trigger": {"integrity": -12.0, "o2": -6.0},
			"choices": [
				{"label": "Reparo emergencial externo", "desc": "4 peças. Recupera a integridade, mas a EVA tem risco.", "cost": {"parts": 4},
					"effects": {"integrity": 10.0, "dose_team": 1.5, "risk": {"chance": 0.15, "log": "Um tripulante se feriu durante o reparo.", "effects": {"health_random": -20.0}}}},
				{"label": "Selar a escotilha e isolar o módulo", "desc": "Sem custo, mas perde os suprimentos guardados ali.", "effects": {"food": -18.0, "morale": -4.0}},
			],
		},
		{
			"id": "recycler_fail",
			"title": "Falha no reciclador de água",
			"text": "A bomba do processador de urina e condensado travou. Sem ela, a recuperação de água cai pela metade.",
			"fact": "O sistema de recuperação de água da ISS atingiu 98% de reaproveitamento em 2023. Uma falha nele obriga a gastar as reservas de água, que também alimentam a produção de oxigênio.",
			"where": ["moon", "mars"],
			"weight": 1.5, "min_day": 6, "cooldown": 18, "requires": {"no_mod": "recycler_fail"},
			"choices": [
				{"label": "Trocar a bomba agora", "desc": "6 peças. Problema resolvido.", "cost": {"parts": 6}, "effects": {"log": "Bomba substituída."}},
				{"label": "Operar em modo degradado", "desc": "Recuperação de água pela metade por 10 dias.", "effects": {"mods": {"recycler_fail": 10}}},
			],
		},
		{
			"id": "blight",
			"title": "Fungo na estufa",
			"text": "Manchas brancas aparecem nas folhas. A umidade alta e a ventilação fraca favoreceram um fungo.",
			"fact": "Em 2016, as zínias cultivadas na ISS foram atacadas por mofo por excesso de umidade. O astronauta Scott Kelly ajustou a rega e salvou parte das plantas, que acabaram florescendo.",
			"where": ["moon", "mars"],
			"weight": 1.5, "min_day": 8, "cooldown": 20, "requires": {"greenhouse": 1, "no_mod": "blight"},
			"choices": [
				{"label": "Esterilizar a estufa", "desc": "Perde metade das plantas agora, mas elimina o fungo.", "effects": {"crop_health": -50.0}},
				{"label": "Tratar só as plantas afetadas", "desc": "O fungo continua por 5 dias (-9 saúde das plantas por dia).", "effects": {"mods": {"blight": 5}}},
			],
		},
		{
			"id": "conflict",
			"title": "Tensão na tripulação",
			"text": "Semanas de confinamento, rotina pesada e falta de privacidade. Uma discussão no jantar terminou em silêncio.",
			"fact": "No experimento Mars-500 (2010-2011), seis voluntários ficaram 520 dias isolados em Moscou. Vários desenvolveram distúrbios de sono, letargia e houve momentos de conflito.",
			"where": ["moon", "mars"],
			"weight": 2.0, "min_day": 8, "cooldown": 12, "requires": {"morale_below": 55.0},
			"choices": [
				{"label": "Dia de folga para todos", "desc": "Ninguém trabalha amanhã. +12 de moral.", "effects": {"work_block": "day_off", "morale": 12.0}},
				{"label": "Conversa com a psicóloga da missão", "desc": "+5 de moral.", "effects": {"morale": 5.0}},
				{"label": "Ignorar e manter o cronograma", "desc": "-8 de moral.", "effects": {"morale": -8.0}},
			],
		},
		{
			"id": "illness",
			"title": "{name} está doente",
			"text": "{name} acordou com febre e tontura (-20 de saúde). A médica suspeita de infecção; o sistema imunológico enfraquece no espaço.",
			"fact": "Estudos com astronautas da ISS mostram que o voo espacial altera o sistema imunológico e pode reativar vírus latentes, como o herpes-zóster.",
			"where": ["moon", "mars"],
			"weight": 1.2, "min_day": 5, "cooldown": 14,
			"choices": [
				{"label": "Usar o kit médico avançado", "desc": "3 peças (suprimentos médicos). +25 de saúde.", "cost": {"parts": 3}, "effects": {"health_sick": 25.0}},
				{"label": "Repouso e observação", "desc": "Sem custo. +5 de saúde, moral -3.", "effects": {"health_sick": 5.0, "morale": -3.0}},
			],
		},
		{
			"id": "discovery",
			"title": "Possível descoberta científica",
			"text": "Os dados orbitais indicam um alvo promissor a alguns quilômetros da base. Uma expedição longa poderia render amostras valiosas.",
			"fact": "Em 2018 instrumentos da sonda indiana Chandrayaan-1 confirmaram gelo de água nas crateras permanentemente sombreadas dos polos da Lua. Em Marte, a cratera Jezero foi escolhida por ser um antigo delta de rio.",
			"where": ["moon", "mars"],
			"weight": 1.5, "min_day": 6, "cooldown": 15,
			"choices": [
				{"label": "Enviar expedição de 2 tripulantes", "desc": "+25 ciência. Dose extra e 20% de risco de acidente.", "effects": {"science": 25.0, "dose_team": [3.0, 6.0], "risk": {"chance": 0.2, "log": "O veículo atolou e um tripulante se machucou no resgate.", "effects": {"health_random": -25.0}}}},
				{"label": "Analisar apenas por dados remotos", "desc": "+6 ciência, sem risco.", "effects": {"science": 6.0}},
			],
		},
		{
			"id": "regolith_wear",
			"title": "Poeira lunar danifica painéis",
			"text": "O regolito lunar, afiado como vidro moído, foi levantado pela EVA e arranhou a superfície de um painel solar.",
			"fact": "Os astronautas da Apollo descreveram a poeira lunar como extremamente abrasiva: ela gastou camadas das botas, emperrou zíperes e causou irritação nos olhos e na garganta.",
			"where": ["moon"],
			"weight": 1.0, "min_day": 8, "cooldown": 20, "requires": {"solar": 2},
			"choices": [
				{"label": "Substituir as células danificadas", "desc": "5 peças.", "cost": {"parts": 5}, "effects": {"log": "Painel restaurado."}},
				{"label": "Aceitar a perda do painel", "desc": "-1 painel solar.", "effects": {"lose_building": "solar"}},
			],
		},
		{
			"id": "reactor_scram",
			"title": "Desligamento automático do reator",
			"text": "Um sensor de temperatura disparou o desligamento de segurança (SCRAM) do reator de fissão.",
			"fact": "O experimento KRUSTY da NASA (2018) testou o reator Kilopower, pensado para gerar de 1 a 10 kW na Lua ou em Marte, independentemente de sol ou poeira.",
			"where": ["moon", "mars"],
			"weight": 1.0, "min_day": 6, "cooldown": 20, "requires": {"reactor": 1, "no_mod": "reactor_off"},
			"choices": [
				{"label": "Inspecionar e religar", "desc": "2 peças. Reator volta amanhã.", "cost": {"parts": 2}, "effects": {"mods": {"reactor_off": 1}}},
				{"label": "Aguardar o ciclo automático de verificação", "desc": "Reator desligado por 3 dias.", "effects": {"mods": {"reactor_off": 3}}},
			],
		},
		{
			"id": "printing",
			"title": "Impressora 3D pronta",
			"text": "A engenharia adaptou a impressora 3D para fabricar peças a partir de plástico reciclado e regolito sinterizado.",
			"fact": "Desde 2014 a ISS tem impressoras 3D. Agências testam a sinterização de regolito para fabricar tijolos e peças na Lua.",
			"where": ["moon", "mars"],
			"weight": 1.2, "min_day": 5, "cooldown": 14,
			"choices": [
				{"label": "Imprimir peças sobressalentes", "desc": "+6 peças, mas gasta 40 kWh da bateria.", "effects": {"parts": 6, "battery": -40.0}},
				{"label": "Imprimir instrumentos científicos", "desc": "+10 ciência, gasta 40 kWh.", "effects": {"science": 10.0, "battery": -40.0}},
			],
		},
		{
			"id": "earth_message",
			"title": "Mensagem da Terra",
			"text": "Uma escola enviou vídeos de crianças fazendo perguntas sobre a vida na base.",
			"fact": "O programa ARISS permite que estudantes conversem com astronautas da ISS via rádio amador desde 2000.",
			"where": ["moon", "mars"],
			"weight": 1.0, "min_day": 4, "cooldown": 20, "requires": {"no_mod": "conjunction"},
			"choices": [
				{"label": "Gravar respostas para as crianças", "desc": "+8 moral.", "effects": {"morale": 8.0}},
			],
		},
		{
			"id": "dust_devil",
			"title": "Redemoinho de poeira",
			"text": "Um redemoinho de poeira passou sobre a base e varreu a sujeira acumulada nos painéis.",
			"fact": "Os rovers Spirit e Opportunity tiveram seus painéis limpos várias vezes por ventos e redemoinhos de poeira, o que estendeu suas missões por anos.",
			"where": ["mars"],
			"weight": 1.2, "min_day": 8, "cooldown": 12, "requires": {"dust_below": 0.85, "no_mod": "dust_storm"},
			"choices": [
				{"label": "Que sorte!", "desc": "Painéis limpos.", "effects": {"dust": 1.0}},
			],
		},
		{
			"id": "resupply",
			"scheduled": true,
			"title": "Nave de carga a caminho",
			"text": "A Terra confirma o lançamento da próxima nave de carga. Há espaço para um tipo de carga prioritária. O que a base precisa mais?",
			"fact": "A Lua fica a cerca de 3 dias da Terra, o que permite reabastecimento. Marte só tem janelas de lançamento a cada ~26 meses e a viagem leva de 6 a 9 meses.",
			"where": ["moon"],
			"choices": [
				{"label": "Alimentos", "desc": "+110 rações.", "effects": {"food": 110.0}},
				{"label": "Peças sobressalentes", "desc": "+35 peças.", "effects": {"parts": 35}},
				{"label": "Água e oxigênio", "desc": "+180 L de água e +50 kg de O2.", "effects": {"water": 180.0, "o2": 50.0}},
			],
		},
		{
			"id": "lunar_night",
			"scheduled": true,
			"title": "Escuridão se aproximando",
			"text": "Em 2 dias o Sol começará a se esconder atrás das cristas próximas. Serão 2 dias de penumbra, 5 de escuridão total e mais 2 de penumbra: painéis sem energia e aquecimento muito mais caro.\n\nVerifique a bateria e decida o que pode ser desligado.",
			"fact": "Mesmo nos pontos mais iluminados do polo sul lunar (os 'picos de luz quase eterna') há períodos de escuridão. No equador a noite lunar dura cerca de 14 dias terrestres, a -170 °C.",
			"where": ["moon"],
			"choices": [
				{"label": "Entendido", "desc": "", "effects": {}},
			],
		},
		{
			"id": "conjunction",
			"scheduled": true,
			"title": "Conjunção solar",
			"text": "O Sol está entre a Terra e Marte. Por 14 sóis não haverá comunicação: nenhuma ajuda do controle da missão, nenhuma mensagem da família.",
			"fact": "A cada ~26 meses ocorre a conjunção solar de Marte. A NASA suspende comandos aos rovers por cerca de duas semanas, porque o plasma solar pode corromper os sinais.",
			"where": ["mars"],
			"choices": [
				{"label": "Preparar a tripulação", "desc": "Moral cai um pouco a cada sol durante a conjunção.", "effects": {"mods": {"conjunction": 14}, "morale": -3.0}},
			],
		},
	]
