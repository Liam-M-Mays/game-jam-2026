class_name EffectStyle
extends Resource
## The numbers of the effects: how long, how far, which colour.
##
## The toolkit holds no number of a game. A game saves its own values in a
## [code].tres[/code] file of this class and hands it to [SpriteEffects].
## Every value here starts at "off": 0, or plain white. Times are in seconds
## of game time. Distances are in art pixels.

@export_group("Flash")
## How long a flash takes to fade.
@export var flash_seconds: float = 0.0
## The colour of the flash of a refused action.
@export var reject_colour: Color = Color.WHITE

@export_group("Shake")
## How long the shake of a refused action takes.
@export var shake_seconds: float = 0.0
## How far the first swing of the shake goes to each side.
@export var shake_distance: float = 0.0

@export_group("Squash")
## How much wider and shorter a squash starts: 0.15 is 115% wide and 85% tall.
@export var squash_amount: float = 0.0
## How long a squash takes to spring back.
@export var squash_seconds: float = 0.0
## The size a thing starts with when it grows in, against its full size.
@export var grow_from: Vector2 = Vector2.ONE
## How long growing in takes.
@export var grow_seconds: float = 0.0

@export_group("Wobble")
## How far a wobble rocks to each side, in degrees.
@export var wobble_degrees: float = 0.0
## How long a wobble takes: right, left and back to upright.
@export var wobble_seconds: float = 0.0

@export_group("Pop")
## How much bigger a pop gets: 0.05 is 105%.
@export var pop_amount: float = 0.0
## How long a pop takes to get big.
@export var pop_rise_seconds: float = 0.0
## How long a pop takes to get back.
@export var pop_fall_seconds: float = 0.0

@export_group("Selected outline", "select_")
## The colour of the outline. A thing can tint it with its own colour.
@export var select_colour: Color = Color.WHITE
## The width of the solid line, in screen pixels.
@export var select_width: float = 0.0
## How far the soft glow reaches beyond the line, in screen pixels.
@export var select_glow_size: float = 0.0
## How strong the glow is next to the line, 0 to 1.
@export var select_glow_strength: float = 0.0
## How many times a second the outline pulses. 0 means it does not pulse.
@export var select_pulse_speed: float = 0.0
## How much of the outline the pulse takes away, 0 to 1.
@export var select_pulse_amount: float = 0.0

@export_group("Hover outline", "hover_")
## The colour of the outline.
@export var hover_colour: Color = Color.WHITE
## The width of the solid line, in screen pixels.
@export var hover_width: float = 0.0
## How far the soft glow reaches beyond the line, in screen pixels.
@export var hover_glow_size: float = 0.0
## How strong the glow is next to the line, 0 to 1.
@export var hover_glow_strength: float = 0.0
## How many times a second the outline pulses. 0 means it does not pulse.
@export var hover_pulse_speed: float = 0.0
## How much of the outline the pulse takes away, 0 to 1.
@export var hover_pulse_amount: float = 0.0

@export_group("Ghost", "ghost_")
## The colour of a blueprint ghost.
@export var ghost_colour: Color = Color.WHITE
## The colour of a ghost that is blocked.
@export var ghost_blocked_colour: Color = Color.WHITE
## How solid a sprite is that is drawn as a ghost itself, 0 to 1.
@export var ghost_opacity: float = 0.0
## How solid the ghost behind a sprite is, 0 to 1.
@export var ghost_under_opacity: float = 0.0
## The ghost colour is multiplied by this where the art is black.
@export var ghost_dark: float = 1.0
## The ghost colour is multiplied by this where the art is white.
@export var ghost_light: float = 1.0

@export_group("Cells", "cell_")
## The colour of the cells under a hovered thing. Its alpha is the strength.
@export var cell_hover_colour: Color = Color.WHITE
## The colour of the cells round the mouse while placing.
@export var cell_cursor_colour: Color = Color.WHITE
## The colour of the cells of a plot area.
@export var cell_area_colour: Color = Color.WHITE
## The colour of the plot area cells under the preview.
@export var cell_area_hover_colour: Color = Color.WHITE
