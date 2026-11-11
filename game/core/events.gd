class_name EventsService
extends Node
## The Events service: news that the simulation sends up to the UI.
##
## A lower layer never calls a higher one. It sends an event here, and whoever
## cares listens. It is loaded as the global [code]Events[/code].
## Today it only carries the news of the Game service. Toasts come with #70.

## A village joined the session.
signal village_added(village: Village)
## A village left the session and was closed.
signal village_removed(village: Village)
## Another village is in view now. [param village] is null when none is.
signal village_in_view_changed(village: Village)
## The game was paused or started again.
signal paused_changed(paused: bool)
## The game speed changed. 3.0 means x3.
signal speed_changed(speed: float)
