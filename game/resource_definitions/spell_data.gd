class_name SpellData
extends Resource

@export var display_name: String = ""

#Qué objeto anima este hechizo. Se compara contra ToolData.cleans:
#si no coinciden, el proyectil atraviesa y muere solo.
@export var animates: DirtData.Type = DirtData.Type.DUST

#El HUD entero en un campo: WandSprite.modulate = spell.color.
#Sabés qué hechizo tenés activo sin mirar ninguna barra.
@export var color: Color = Color.WHITE

@export_range(0.05, 2.0, 0.05) var cooldown: float = 0.35      
@export_range(100.0, 2000.0, 10.0) var projectile_speed: float = 600.0 

#Segundos antes de autodestruirse. Es lo que evita que los proyectiles que
#no pegan a nada se acumulen para siempre fuera de pantalla.
@export_range(0.1, 5.0, 0.1) var lifetime: float = 1.5 

@export_range(0, 100) var energy_cost: int = 0

@export var texture: Texture2D


@export_group("Limpieza directa")

#para que el jugador tenga una segunda vía de limpiar ahora que se gana eliminando TODA la
#mugre. Se apaga poniendo cleaning_power en 0: el hechizo vuelve a solo animar.
@export_range(0, 20) var cleaning_power: int = 1

#Es un factor sobre la magia normal del parche, no
#un número aparte: así balancear magic_per_pass sigue moviendo las dos vías a la vez.
#0.5 = el hechizo rinde la mitad que la escoba por cada pase que saca.
@export_range(0.0, 1.0, 0.05) var magic_scale: float = 0.5
