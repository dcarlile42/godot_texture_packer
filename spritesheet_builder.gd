extends Node

# point this to a physical path anywhere in storage to load all .png images from there
const SpritePath : String = "res://sprites/"
const SpritePadding : int = 2  # I used 12 so they worked well with zooming and mipmaps

const AtlasWidth : int = 2048
const AtlasHeight : int = 2048

@export var sprite_name : String
@export var test_sprite : Sprite2D



func _ready() -> void:

	# get a list of Image instances in whatever way is suitable,
	# adding padding if needed - you can use the create_padded_image function
	# below to add padding in a way that supports mipmapping pretty well
	var sprite_images := load_sprites(SpritePath, SpritePadding)

	# pack the sprites into one or more Image instances, each of the specified size.
	# some packers will automatically expand the size to fit everything - this one doesn't do that,
	# but rather creates multiple spritesheets of the specified size until everything fits
	var atlases = TexturePacker.pack(AtlasWidth, AtlasHeight, sprite_images, SpritePadding)

	# the function returns a dictionary with information about the atlas,
	# the list of generated images, and the metadata about each sprite
	# including the atlas it was placed on, the pixel coordinates, and
	# the texture coordinates
	#var atlases : Dictionary = {
		#"atlas_width" : atlas_width,
		#"atlas_height" : atlas_height,
		#"images" : atlas_images,
		#"sprites" : sprite_assets
	#}

	# each sprite has metadata describing which atlas texture it lives on
	# and where it is
	# the name is derived from the filename in this implementation and
	# that's used as a key into the atases.sprites dictionary
	#var sprite_asset : Dictionary = {
		#"name" : image.resource_name,
		#"atlas" : atlas_image,
		#"region" : region,
		#"texture_region" : texture_region
	#}

	for image : Image in atlases.images:
		image.save_png("user://%s.png" % image.resource_name)

	#print(atlases)


	if (sprite_name != ""):
		test_sprite.texture = ImageTexture.create_from_image(atlases.images[0])
		var sprite_asset = atlases.sprites[sprite_name]
		test_sprite.region_rect = sprite_asset.region



func load_sprites(path : String, spite_padding : int) -> Array[Image]:

	var files := get_files(path, "png")
	var images : Array[Image] = []

	for file : String in files:
		var file_path := SpritePath + file

		var image := Image.new()
		image.load(file_path)

		image.resource_name = file.get_basename().to_lower()
		image.convert(Image.FORMAT_RGBA8)

		var image_width := image.get_width()
		var image_height := image.get_height()

		var padded_image = create_padded_image(image, 0, 0, image_width, image_height, spite_padding)
		padded_image.resource_path = file_path
		images.append(padded_image)

	return images


func get_files(path : String, extension : String) -> PackedStringArray:
	var files := DirAccess.get_files_at(path)

	var filtered := Array(files).filter(func(file_name : String):
		return file_name.get_extension().to_lower() == extension.to_lower()
	)

	return PackedStringArray(filtered)


static func create_padded_image(image : Image, x : int, y : int, w : int, h : int, padding : int) -> Image:
	var pw := w + padding * 2
	var ph := h + padding * 2

	var padded_image := Image.create_empty(pw, ph, false, image.get_format())
	padded_image.resource_name = image.resource_name

	# blit iamge into the middle
	padded_image.blit_rect(image, Rect2i(x, y, w, h), Vector2i(padding, padding))

	# duplicate edges and corners for padding
	for i : int in padding + 1:
		var sx := padding + 1 - i;
		var sy := padding + 1 - i;
		var sw := w + (i - 1) * 2;
		var sh := h + (i - 1) * 2;


		# left
		padded_image.blit_rect(padded_image, Rect2i(sx, sy, 1, sh), Vector2i(sx - 1, sy));

		# right
		padded_image.blit_rect(padded_image, Rect2i(sx + sw - 1, sy, 1, sh), Vector2i(sx + sw, sy));

		# bottom
		padded_image.blit_rect(padded_image, Rect2i(sx, sy, sw, 1), Vector2i(sx, sy - 1));

		# top
		padded_image.blit_rect(padded_image, Rect2i(sx, sy + sh - 1, sw, 1), Vector2i(sx, sy + sh));

		# bottom left corner
		padded_image.blit_rect(padded_image, Rect2i(sx, sy, 1, 1), Vector2i(sx - 1, sy - 1));

		# top left corner
		padded_image.blit_rect(padded_image, Rect2i(sx, sy + sh - 1, 1, 1), Vector2i(sx - 1, sy + sh));

		# bottom right corner
		padded_image.blit_rect(padded_image, Rect2i(sx + sw - 1, sy, 1, 1), Vector2i(sx + sw, sy - 1));

		# top right corner
		padded_image.blit_rect(padded_image, Rect2i(sx + sw - 1, sy + sh - 1, 1, 1), Vector2i(sx + sw, sy + sh));


	return padded_image
