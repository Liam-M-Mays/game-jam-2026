class_name VillageViewLayer
extends RefCounted
## One part of the picture of a village: the ground, the trees, the drops,
## the meeples.
##
## A layer reads the village and draws it. It never changes the village: a
## change is a command, sent with [method Village.send].
## [VillageView] calls the functions in this order: [method add_sprites] and
## [method shader] before the batch exists, [method start] once it does,
## [method update] in every frame, and [method close] at the end. Override
## the ones the layer needs. The list of layers is in [VillageLayers].


## Adds the sprites this layer draws to [param _atlas]. It runs before the
## atlas is built, so the sprite numbers can be kept for [method start].
func add_sprites(_village: Village, _atlas: SpriteAtlas) -> void:
	pass


## The batch shader this layer needs, or null when the plain one will do.
## The first layer that names one decides.
func shader() -> Shader:
	return null


## Runs once, when the batch of [param _view] exists. Put the things of
## [param _village] into [member VillageView.rows] here, and add own nodes
## with [method VillageView.add_under] or [method VillageView.add_over].
func start(_village: Village, _view: VillageView) -> void:
	pass


## Runs in every frame the picture is in the scene. Leave it empty when
## nothing of this layer moves.
func update(_village: Village, _view: VillageView) -> void:
	pass


## Runs once, when the picture is taken off its village. Let go of everything.
func close() -> void:
	pass
