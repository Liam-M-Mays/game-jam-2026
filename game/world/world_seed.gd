class_name WorldSeed
extends RefCounted
## Picks the seed of a new game, and words the line that prints it.
##
## A fixed seed is a dev setting: [member DevSettings.world_seed]. With no
## fixed seed every new game gets a new random one, as in the jam game.

## The dev setting that means "pick a new random seed".
const RANDOM := 0
## The highest random seed. It fits the noise, which takes 31 bits.
const HIGHEST := 0x7FFFFFFF


## Returns [param fixed_seed], or a new random seed from 1 to
## [constant HIGHEST] when it is [constant RANDOM].
static func pick(fixed_seed: int) -> int:
	if fixed_seed != RANDOM:
		return fixed_seed
	var dice := RandomNumberGenerator.new()
	dice.randomize()
	return dice.randi_range(1, HIGHEST)


## The console line that tells the seed of a world. It is the jam game's line.
static func line(world_seed: int) -> String:
	return "World seed: %d" % world_seed
