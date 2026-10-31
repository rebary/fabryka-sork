class_name StarRow
extends Control
## Rząd gwiazdek rysowany kodem (domyślna czcionka nie ma znaku gwiazdki).
## filled = ile gwiazdek jest złotych; reveal animuje pojawianie się.

const GOLD := Color("#ffc93c")
const EMPTY := Color("#3b424c")

var count := 3
var filled := 0
var star_size := 56.0
var reveal := 3.0


func _init(p_size: float = 56.0, p_count: int = 3) -> void:
	star_size = p_size
	count = p_count
	custom_minimum_size = Vector2(count * star_size * 1.25, star_size * 1.1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_stars(n: int, animate: bool = false) -> void:
	filled = n
	reveal = 0.0 if animate else float(count)
	queue_redraw()


func _process(delta: float) -> void:
	if reveal < count:
		reveal = minf(reveal + delta * 4.0, count)
		queue_redraw()


func _draw() -> void:
	var w := star_size * 1.25
	var x0 := (size.x - w * count) / 2.0 + w / 2.0
	for i in count:
		var c := Vector2(x0 + i * w, size.y / 2.0)
		var on := i < filled
		var k := clampf(reveal - i, 0.0, 1.0) if on else 1.0
		var r := star_size / 2.0 * (0.6 + 0.4 * k)
		draw_colored_polygon(points(c, r, r * 0.45), GOLD.darkened(0.5) if not on else Color(GOLD, 0.35 + 0.65 * k))
		if not on:
			draw_colored_polygon(points(c, r * 0.8, r * 0.36), EMPTY)


static func points(c: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var r := r_out if k % 2 == 0 else r_in
		pts.append(c + Vector2.from_angle(-PI / 2.0 + k * PI / 5.0) * r)
	return pts


## Mała ikona gwiazdki jako tekstura (do przycisków i napisów).
static func texture(px: int = 28, col: Color = GOLD) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var poly := points(Vector2(px, px) / 2.0, px * 0.48, px * 0.22)
	for y in px:
		for x in px:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
