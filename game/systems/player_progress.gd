extends Node

##La bolsa de magia del jugador y las mejoras que compró. Se registra como autoload con
##el nombre PlayerProgress.
##
##Es global porque es lo ÚNICO que tiene que sobrevivir al nivel. RunState vive dentro
##del nivel justamente para morir con él y que cada run arranque limpia (ver su doc); la
##magia necesita lo contrario. Poner las dos cosas en el mismo nodo obligaría a elegir, y
##cualquiera de las dos elecciones rompe la otra mitad.
##
##NO lleva class_name: el nombre PlayerProgress ya lo ocupa el autoload, y declarar los
##dos hace que choquen. Mismo caso que AudioManager.
##
##VIVE EN MEMORIA, no en disco.

##Emitida cada vez que cambia la magia disponible. La escucha la tienda.
signal magic_changed(total: int)

##Emitida al comprar, con la mejora y el nivel que quedó comprado.
signal upgrade_bought(upgrade: Upgrade, level: int)


##Las cuatro mejoras de la tienda. El orden de este enum es el orden en que se listan.
enum Upgrade { EXTRA_BROOM, BONUS_TIME, FASTER_CAST, AUTO_BROOM }

##Cuántas veces se puede comprar cada una. AUTO_BROOM es 1 porque la tenés o no la tenés;
##FASTER_CAST tiene techo porque sin él el cooldown llegaría a 0 y el juego se rompería.
const MAX_LEVEL: Dictionary[Upgrade, int] = {
	Upgrade.EXTRA_BROOM: 3,
	Upgrade.BONUS_TIME: 5,
	Upgrade.FASTER_CAST: 4,
	Upgrade.AUTO_BROOM: 1,
}

# El precio sube con cada compra: costo = base * (nivel_actual + 1). Sin eso, la mejora
#más barata se compra infinitas veces y ninguna otra se mira.
#Referencia de balance: el nivel de 8 parches da ~120 de magia limpiando todo con la
#escoba y ~72 a puro hechizo. O sea dos o tres compras por run.
const BASE_COST: Dictionary[Upgrade, int] = {
	Upgrade.EXTRA_BROOM: 60,
	Upgrade.BONUS_TIME: 90,
	Upgrade.FASTER_CAST: 45,
	Upgrade.AUTO_BROOM: 80,
}

##Nombre que ve el jugador. Vive acá y no en la escena de la tienda para que agregar una
##mejora sea tocar un solo archivo.
const UPGRADE_NAME: Dictionary[Upgrade, String] = {
	Upgrade.EXTRA_BROOM: "Escoba extra",
	Upgrade.BONUS_TIME: "Tiempo extra",
	Upgrade.FASTER_CAST: "Reduce cooldown",
	Upgrade.AUTO_BROOM: "Escoba automática",
}

##Segundos que suma cada nivel de BONUS_TIME.
const SECONDS_PER_LEVEL: float = 15.0

##Cuánto recorta del cooldown cada nivel de FASTER_CAST. Con el techo de 4 niveles el
##cooldown queda en el 20% del original, nunca en 0.
const CAST_CUT_PER_LEVEL: float = 0.2

@export var print_events: bool = true

var _magic: int = 0

#Cuántas veces se compró cada mejora. Arranca vacío: una mejora sin entrada vale 0.
var _levels: Dictionary[Upgrade, int] = {}


# ═══════════════ MAGIA ═══════════════


##La magia que el jugador tiene para gastar.
func get_magic() -> int:
	return _magic


##Acredita lo juntado en una run. La llama Main cuando la run termina, gane o pierda.
func add_magic(amount: int) -> void:
	if amount <= 0:
		return

	_magic += amount
	magic_changed.emit(_magic)

	if print_events:
		print("[Progress] +%d de magia → %d disponibles" % [amount, _magic])


# ═══════════════ MEJORAS ═══════════════


##Cuántas veces se compró esta mejora.
func get_level(upgrade: Upgrade) -> int:
	return _levels.get(upgrade, 0)


##Si todavía se puede comprar otra vez.
func is_maxed(upgrade: Upgrade) -> bool:
	return get_level(upgrade) >= MAX_LEVEL[upgrade]


##Lo que cuesta la PRÓXIMA compra de esta mejora. Sube con cada nivel comprado.
##Devuelve 0 si ya está al máximo: no hay próxima compra que cotizar.
func get_cost(upgrade: Upgrade) -> int:
	if is_maxed(upgrade):
		return 0

	return BASE_COST[upgrade] * (get_level(upgrade) + 1)


##Si alcanza la magia y todavía queda nivel por comprar.
func can_afford(upgrade: Upgrade) -> bool:
	if is_maxed(upgrade):
		return false

	return _magic >= get_cost(upgrade)


##Compra una mejora. Devuelve true solo si la compra se concretó.
##Devuelve bool en vez de no devolver nada para que la tienda no tenga que repetir
##la validación: pide la compra y dibuja según lo que pasó de verdad.
func buy(upgrade: Upgrade) -> bool:
	if not can_afford(upgrade):
		if print_events:
			print("[Progress] compra rechazada: %s" % UPGRADE_NAME[upgrade])
		return false

	#El costo se lee ANTES de subir el nivel: subirlo primero cobraría el precio del
	#nivel siguiente, que es el bug más fácil de escribir acá.
	var cost: int = get_cost(upgrade)

	_magic -= cost
	_levels[upgrade] = get_level(upgrade) + 1

	magic_changed.emit(_magic)
	upgrade_bought.emit(upgrade, _levels[upgrade])

	if print_events:
		print("[Progress] comprado %s nivel %d por %d → quedan %d" % [
			UPGRADE_NAME[upgrade], _levels[upgrade], cost, _magic
		])

	return true


# ═══════════════ EFECTOS ═══════════════
# Lo que el resto del juego le pregunta. Devuelven el valor ya calculado para que nadie
# más tenga que saber cómo se guardan los niveles.


##Escobas de más que arrancan en el nivel, además de las que ya trae la escena.
func get_extra_brooms() -> int:
	return get_level(Upgrade.EXTRA_BROOM)


##Segundos que se le suman al reloj de la run.
func get_bonus_seconds() -> float:
	return float(get_level(Upgrade.BONUS_TIME)) * SECONDS_PER_LEVEL


##Factor por el que se multiplica el cooldown del hechizo. 1.0 = sin mejorar.
##maxf() contra 0.1 es un piso de seguridad: si alguien sube MAX_LEVEL sin mirar esto,
##el peor caso es un hechizo muy rápido y no una división por cero más adelante.
func get_cast_cooldown_scale() -> float:
	var scale: float = 1.0 - float(get_level(Upgrade.FASTER_CAST)) * CAST_CUT_PER_LEVEL

	return maxf(scale, 0.1)


##Si el jugador compró la escoba que limpia sola.
func has_auto_broom() -> bool:
	return get_level(Upgrade.AUTO_BROOM) > 0


##Borra la magia y las mejoras. Todavía no la llama nadie: cuándo se empieza de cero
##(¿al volver al título? ¿al ganar?) se decide junto con el flujo de la tienda.
func reset() -> void:
	_magic = 0
	_levels.clear()

	magic_changed.emit(_magic)

	if print_events:
		print("[Progress] progreso reiniciado")
