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