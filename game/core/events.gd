class_name EventsService
extends Node
## The Events service: news that belongs to no village and not to the session.
##
## It is loaded as the global [code]Events[/code], and it is part of the
## bottom layer, so it knows no village. The news of a village comes from the
## village itself, and the UI listens to the village in view. The news of the
## session (villages, pause, speed) comes from the Game service.
## It is empty today. Toasts come with #70.
