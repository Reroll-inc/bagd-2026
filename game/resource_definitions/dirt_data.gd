extends Resource
class_name DirtData

#Este enum es el vocabulario común de TODO el juego: lo leen SpellData
#(a qué objeto anima), ToolData (qué limpia) y DirtData (qué es este parche).
#Vive acá porque la mugre es lo que define el problema; el resto responde a ella.
#Agregar un tipo nuevo = agregar UNA línea acá y crear los .tres correspondientes.
enum Type { DUST, COBWEB }

#La orientación decide dónde se pega el parche y cómo se rota el sprite.
#No afecta cómo se limpia
enum Orientation { FLOOR, WALL, CEILING }

@export var type: Type = Type.DUST                  
@export var orientation: int = Orientation.FLOOR 

#Cuántos "golpes" aguanta antes de desaparecer. Es la unidad de medida de
#todo el balance: el talento "escoba al doble" es cleaning_power x2 contra esto.
@export_range(1, 20) var passes_required: int = 3 


#Magia que entrega CADA pase, no el parche entero. Con el reloj corriendo, el jugador
#necesita ver la barra subir en cada golpe; de a saltos parece que no pasa nada.
#El total que da un parche es passes_required * magic_per_pass.
@export_range(1, 50) var magic_per_pass: int = 5


@export var texture: Texture2D


#Tamaño en píxeles que el parche debe ocupar en pantalla, sin importar la resolución de
#la imagen. El sprite se escala solo para calzar acá. Así el arte se reemplaza sin tener
#que reajustar el scale del Sprite2D a mano en cada escena.
@export var display_size: Vector2 = Vector2(48, 48)