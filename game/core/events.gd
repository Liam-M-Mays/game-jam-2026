class_name EventsService
extends Node
## The Events service: news for whoever cares to listen.
##
## A lower layer never calls a higher one. It sends an event here, and whoever
## cares listens. It is loaded as the global [code]Events[/code].
## It is part of the bottom layer, so it knows nothing about villages: news
## about the villages of the session is sent by the Game service itself.
## Today it carries pause and speed. Toasts come with #70.

## The game was paused or started again.
signal paused_changed(paused: bool)
## The game speed changed. 3.0 means x3.
signal speed_changed(speed: float)
