class_name TexturePacker

static func pack(
		atlas_width : int,
		atlas_height : int,
		images : Array[Image],
		padding : int,
		) -> Dictionary:

	var atlas_images : Array[Image] = []
	var sprite_assets : Dictionary

	var rects : Array[Rect2i] = []
	var skipped_images : Array[Image] = []

	while true:
		var atlas_image := Image.create_empty(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
		atlas_image.resource_name = "atlas_%d" % atlas_images.size()

		if not Packer.Pack(atlas_image, images, rects, skipped_images):
			printerr("Could not pack any textures into an empty atlas.")
			break

		atlas_images.append(atlas_image)

		for i : int in images.size():
			var image : Image = images[i]
			var region : Rect2i = rects[i]

			# adjust region to exclude padding
			var rx := region.position.x + padding;
			var ry := region.position.y + padding;
			var sx := region.size.x - (padding * 2);
			var sy := region.size.y - (padding * 2);

			region = Rect2i(rx, ry, sx, sy)

			# calculate the texture coordinates based on the texture atlas size
			var texture_region := Rect2(float(rx) / float(atlas_width), \
									float(ry) / float(atlas_height), \
									float(sx) / float(atlas_width), \
									float(sy) / float(atlas_height));

			var sprite_asset : Dictionary = {
				"name" : image.resource_name,
				"atlas" : atlas_image,
				"region" : region,
				"texture_region" : texture_region
			}

			sprite_assets[image.resource_name] = sprite_asset

		# if there are no skipped textures then we've packed everything,
		# otherwise loop back around and create the next atlas with
		# the remaining images
		if skipped_images.size() == 0:
			break

		images.clear()
		images.append_array(skipped_images)

	var atlases : Dictionary = {
		"atlas_width" : atlas_width,
		"atlas_height" : atlas_height,
		"images" : atlas_images,
		"sprites" : sprite_assets
	}

	return atlases


class Packer:
	static func Pack(atlas_image : Image,
				  images : Array[Image],
				  rects : Array[Rect2i],
				  skipped_images : Array[Image]) -> bool:

		images.sort_custom(func(a : Image, b : Image):
			return b.get_height() > a.get_height()  # taller first
		)

		var atlas_width := atlas_image.get_width()
		var atlas_height := atlas_image.get_height()

		var free_rects : Array[Rect2i] = []

		# get packing rectangles
		# after this call, images will only contain the images that could be
		# packed and skipped_images will contain those that couldn't
		# TryPack only return false if it can't pack *any* of the images, meaning
		# they're all too big to fit the specified atlas dimensions
		if not TryPack(atlas_width, atlas_height, images, rects, skipped_images, free_rects):
			return false

		# blit the images into the atlas at their packed positions
		for i : int in images.size():
			var image := images[i]
			var rect := rects[i];
			atlas_image.blit_rect(image, Rect2(0, 0, rect.size.x, rect.size.y), rect.position)

		# DEBUG : highlight free rects
		#if rects.size() > 0:
			#for r : Rect2i in free_rects:
				#atlas_image.fill_rect(r, RandomColor())


		atlas_image.generate_mipmaps()
		#atlas_image.premultiply_alpha()

		return images.size() > 0


	static func TryPack(atlas_width : int,
				 atlas_height : int,
				 images : Array[Image],
				 rects : Array[Rect2i],
				 skipped_images : Array[Image],
				 free_rects : Array[Rect2i]) -> bool:

		var rect_queue : Array[Rect2i] = []
		var split = func Split(image_width : int,
							   image_height : int,
							   rect_x : int,
							   rect_y : int,
							   rect_width : int,
							   rect_height : int) -> void:

			# we'll be left with up to two new rects after placing this one
			# create the new rectangles depending on the largest horizontal
			# or vertical side of the rect to we maximize their sizes

			# if we fit exactly then no new rects to generate
			if rect_width == image_width and rect_height == image_height: return

			var new_rect : Rect2i

			# a single new rect below if we fit exactly horizontally
			if rect_width == image_width:
				new_rect = Rect2i(rect_x, rect_y + image_height, image_width, rect_height - image_height)
				rect_queue.push_back(new_rect)
				return

			# a single new rect to the right if we fit exactly vertically
			if rect_height == image_height:
				new_rect = Rect2i(rect_x + image_width, rect_y, rect_width - image_width, image_height)
				rect_queue.push_back(new_rect)
				return
#

			# NOTE : different datasets may work differently with where it's most
			# beneficial to split, but with primarily sprite based, similarly sized textures
			# it seems to work best to always go horizontal
			# TODO : we could pre-analyze the input data and if most are wider than longer
			# than prefer that split, otherwise prefer the vertical split?

			if true or image_height >= image_width:
				# the section to the right of the rect and the same height as the rect
				new_rect = Rect2i(rect_x + image_width, rect_y, rect_width - image_width, image_height)
				rect_queue.push_back(new_rect)

				# the section below the rect (full width of rect)
				new_rect = Rect2i(rect_x, rect_y + image_height, rect_width, rect_height - image_height)
				rect_queue.push_back(new_rect)
			else:
				# the section below the rect and the same width as the rect
				new_rect = Rect2i(rect_x, rect_y + image_height, image_width, rect_height - image_height)
				rect_queue.push_back(new_rect)

				# the section to the right (full height of rect)
				new_rect = Rect2i(rect_x + image_width, rect_y, rect_width - image_width, rect_height)
				rect_queue.push_back(new_rect)



		var image_queue : Array[Image] = images.duplicate()
		var skipped_image_queue : Array[Image] = []
		var skipped_rects : Array[Rect2i] = []
		var total_images := images.size()

		rects.clear()
		skipped_images.clear()

		# we're going to rebuild images so it's in the same order as rects
		images.clear()

		# start with the entire atlas rect
		rect_queue.push_back(Rect2i(0, 0, atlas_width, atlas_height))


		while true:
			var before_count := image_queue.size()

			while image_queue.size() > 0:
				var image : Image = image_queue.pop_front()
				var image_width := image.get_width()
				var image_height := image.get_height()

				while rect_queue.size() > 0:
					var rect : Rect2i = rect_queue.pop_front()
					var rx := rect.position.x
					var ry := rect.position.y
					var rw := rect.size.x
					var rh := rect.size.y

					# if the image fits, add the rect and split the free rect
					if image_width <= rw and image_height <= rh:
						images.append(image)
						rects.append(Rect2i(rx, ry, image_width, image_height))
						image = null
						split.call(image_width, image_height, rx, ry, rw, rh)
						break

					# if it doesn't fit then skip this rect and
					# keep looking through additional rects to see
					# if the iamge fits in one of those
					skipped_rects.push_back(rect)

				# if we didn't find a rect the image fits in then
				# save it for later, but keep on trying to fit
				# other images
				if image != null:
					skipped_image_queue.push_back(image)


				# add back the skipped rects so the next image can check them
				rect_queue.append_array(skipped_rects)
				skipped_rects.clear()

				# merge split rects back together where possible so we have more
				# chance of finding fits as we continue on
				MergeRects(rect_queue)

			image_queue.append_array(skipped_image_queue)
			skipped_image_queue.clear();

			# if we didn't skip anything then we're done
			if image_queue.size() == 0: break

			# if we didn't pack anything during the latest pass then
			#  we can't fit anymore in the allowed space
			if image_queue.size() == before_count: break


		if image_queue.size() > 0:
			print("Couldn't find space for %d out of %d images." % [image_queue.size(), total_images])
			skipped_images.append_array(image_queue)

		free_rects.clear()
		free_rects.append_array(rect_queue)

		return images.size() > 0


	static func MergeRects(input_queue : Array[Rect2i]) -> void:
		while true:
			var last_count := input_queue.size()
			MergeVertical(input_queue)
			MergeHorizontal(input_queue)
			if input_queue.size() == last_count: break



	static func MergeVertical(input_queue : Array[Rect2i]) -> void:
		var all_rects : Array[Rect2i] = input_queue.duplicate()

		# sort by horizontal position, vertical position, and width
		# which will put potentially adjacent rects in sequence
		all_rects.sort_custom(func(a : Rect2i, b : Rect2i):
			return (sign(a.position.x - b.position.x) * 100 + \
				   sign(a.position.y - b.position.y) * 10 + \
				   sign(a.size.x - b.size.x) * 1) <= 0
		)

		input_queue.clear()

		for i : int in range(0, all_rects.size(), 2):
			var r := all_rects[i]

			if i + 1 >= all_rects.size():
				input_queue.push_back(r)
				break

			var r2 := all_rects[i + 1]

			# if the left side and width match then we have a potential match
			# if r2 is just below r then we can merge these two into 1
			if r.position.x == r2.position.x and \
			   r.size.x == r2.size.x and \
			   r.position.y + r.size.y == r2.position.y:
				input_queue.push_back(Rect2i(r.position.x, r.position.y, r.size.x, r.size.y + r2.size.y))
			else:
				input_queue.push_back(r)
				input_queue.push_back(r2)


	static func MergeHorizontal(input_queue : Array[Rect2i]) -> void:
		var all_rects : Array[Rect2i] = input_queue.duplicate()

		# sort by vertical position, horizontal position, and height
		# which will put potentially adjacent rects in sequence
		all_rects.sort_custom(func(a : Rect2i, b : Rect2i):
			return (sign(a.position.y - b.position.y) * 100 + \
				   sign(a.position.x - b.position.x) * 10 + \
				   sign(a.size.y - b.size.y) * 1) <= 0
		)

		input_queue.clear()

		for i : int in range(0, all_rects.size(), 2):
			var r := all_rects[i]

			if i + 1 >= all_rects.size():
				input_queue.push_back(r)
				break

			var r2 := all_rects[i + 1]

			# if the top side and height match then we have a potential match
			# if r2 is just to the right of r then we can merge these two into 1
			if r.position.y == r2.position.y and \
			   r.size.y == r2.size.y and \
			   r.position.x + r.size.x == r2.position.x:
				input_queue.push_back(Rect2i(r.position.x, r.position.y, r.size.x + r2.size.x, r.size.y))
			else:
				input_queue.push_back(r)
				input_queue.push_back(r2)



	static var goldenRatioConjugate : float = 0.618033988749895;
	static var random_hue : float = 4143.0;

	static func RandomColor() -> Color:
		var c := Color.from_hsv(random_hue, 0.70, 0.70);
		random_hue += goldenRatioConjugate;
		random_hue = fmod(random_hue, 1.0)
		return c;
