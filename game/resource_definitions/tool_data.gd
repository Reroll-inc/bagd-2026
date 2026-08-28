extends Resource
class_name ToolData

@export var display_name: String = ""

#Un objeto limpia UN tipo. Escoba → polvo, plumero → telaraña.
#Si algún día existe el talento "escoba universal", esto pasa a Array[DirtData.Type]
#y el == se vuelve .has().
@export var cleans: DirtData.Type = DirtData.Type.DUST

#Cuántos passes le saca a la mugre por golpe. (Los talentos pueden multiplicar ESTO).
@export_range(1, 10) var cleaning_power: int = 1 

#Segundos entre golpe y golpe. Junto con cleaning_power define la velocidad
#de limpieza. Dos perillas en vez de una porque se SIENTEN distinto:
#power alto = golpes fuertes y espaciados; interval bajo = frenesí.
@export_range(0.1, 3.0, 0.05) var clean_interval: float = 0.5 

@export_range(10.0, 300.0, 5.0) var move_speed: float = 60.0 

@export var texture: Texture2D

@export var display_size: Vector2 = Vector2(32, 64)