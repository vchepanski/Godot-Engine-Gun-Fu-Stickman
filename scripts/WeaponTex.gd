extends Node

const SOURCE := "res://assets/weapons/pistol.png"
const DEST := "res://assets/weapons/pistol_clean.png"

static func get_clean_texture() -> ImageTexture:
	var img := Image.new()
	img.load(SOURCE)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			if c.r > 0.94 and c.g > 0.94 and c.b > 0.94:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
	var tex := ImageTexture.create_from_image(img)
	return tex