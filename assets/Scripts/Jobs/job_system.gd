extends Node
## Holds the jobs and the meeples that do them. Once a frame it gives each new job to the nearest
## free builder, and each builder that became free a waiting job: the oldest site's nearest haul, or
## a nearer job that is not a haul, such as a marked tree. A new haul never jumps an older site's waiting one.
## When no job waits and builders stand idle, sites ask for more than their max_hauls, oldest first.
## Meeples with a workplace never take these jobs: their building gives them work.
## A builder carrying a loose drop to a pile counts as free: these jobs come first. A haul for a site
## takes over a store trip when that drop is nearer to the site than any other.

signal changed

var workers : Array[Meeple] = []
var _pending : Array[Job] = []
var _active : Array[Job] = []
var _fresh : Array[Job] = []
var _freed : Array[Meeple] = []
var _open_slots : Array[Building] = []
var _slot_opened := false
var _changed := false
var _last_changed := -Inventory.CHANGED_EVERY_MS
var _last_build_order := 0
## Store trips under way, so a haul for a site can take one over.
var _store_trips : Array[StoreJob] = []
## Set when builders may have become idle: offer them to the sites at the next match.
var _offer_idle := false
## The most drops one offer to idle builders asks for. The next offer comes CHANGED_EVERY_MS later.
const IDLE_OFFER_BATCH := 8
var _last_idle_offer := -Inventory.CHANGED_EVERY_MS

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta : float) -> void:
	match_jobs()
	var now := Time.get_ticks_msec()
	if _changed and now - _last_changed >= Inventory.CHANGED_EVERY_MS:
		_changed = false
		_last_changed = now
		changed.emit()

func reset() -> void:
	for job in _pending + _active:
		job.cancelled = true
	_pending.clear()
	_active.clear()
	_fresh.clear()
	_freed.clear()
	_open_slots.clear()
	_store_trips.clear()
	_offer_idle = false
	_last_idle_offer = -Inventory.CHANGED_EVERY_MS
	_changed = true

## Gives a construction site its place in the build order. Older sites get lower numbers, and free builders take their hauls first.
func next_build_order() -> int:
	_offer_idle = true
	_last_build_order += 1
	return _last_build_order

## A building put back from a save keeps its place in the build order. Later sites come after it.
func note_build_order(order : int) -> void:
	_last_build_order = maxi(_last_build_order, order)

func job_count() -> int:
	return _pending.size() + _active.size()

## The player's jobs that no meeple has taken yet.
func waiting_player_jobs() -> int:
	var count := 0
	for job in _pending:
		if job is HarvestJob:
			count += 1
	return count

## Cancels the player's jobs that no meeple has taken yet and takes their marks off.
## A meeple already walking to a job or working on it keeps that job.
func clear_waiting_player_jobs() -> void:
	for job in _pending.duplicate():
		if job is HarvestJob:
			job.target.cancel_job()

## Adds a job for the next match. A haul that took over a store trip goes straight to that trip's meeple.
func add(job : Job) -> void:
	if job is HaulJob and (job as HaulJob).carrier != null:
		_active.append(job)
		_changed = true
		(job as HaulJob).carrier.take_job(job)
		return
	_pending.push_back(job)
	_fresh.push_back(job)
	_changed = true

## Tells the jobs that `worker` has nothing to do, so it takes a waiting job at the next match.
func worker_freed(worker : Meeple) -> void:
	_freed.push_back(worker)
	_offer_idle = true
	# A worker sent back to being a builder lands here too, so the HUD counts it again.
	_changed = true

## How many alive meeples work in a building's slot. The rest are builders. The HUD asks at most
## every CHANGED_EVERY_MS, so counting them each time is cheap even with thousands of meeples.
func count_in_slots() -> int:
	var count := 0
	for worker in workers:
		if worker.workplace != null:
			count += 1
	return count

## Gives new jobs to the nearest free meeple, then gives meeples that became free the best waiting job
## (see _next_waiting_job). A new haul gives its meeple the oldest site's waiting haul instead. Runs once a
## frame. Tests call it directly.
func match_jobs() -> void:
	if not _open_slots.is_empty() and (_slot_opened or not _freed.is_empty()):
		_slot_opened = false
		_fill_slots()
	if _pending.is_empty():
		_fresh.clear()
		_freed.clear()
		_offer_idle_builders()
		return
	var fresh := _fresh
	var freed := _freed
	_fresh = []
	_freed = []
	for job in fresh:
		if not _pending.has(job):
			continue
		var take : Job = _oldest_waiting_haul() if job is HaulJob else job
		var extra := take is HaulJob and (take as HaulJob).extra
		var worker := _nearest_free_worker(take.place(), extra)
		if worker == null:
			if extra:
				continue
			break
		_give(take, worker)
	for worker in freed:
		if _pending.is_empty():
			break
		if worker.is_free() and not worker.job is HaulJob and workers.has(worker):
			_give(_next_waiting_job(worker), worker)

func _give(job : Job, worker : Meeple) -> void:
	_pending.erase(job)
	_active.append(job)
	_changed = true
	worker.take_job(job)

## The free meeple nearest `place`. With `skip_hauls`, one walking to an extra haul does not count: for another
## extra haul it would only swap, and a worker slot would take it with the haul still on.
func _nearest_free_worker(place : Vector2, skip_hauls := false) -> Meeple:
	var best : Meeple = null
	var best_dist := INF
	var grid : Grid = null
	var local := Vector2.ZERO
	for worker in workers:
		if not worker.is_free() or (skip_hauls and worker.job is HaulJob):
			continue
		if worker.grid != grid:
			grid = worker.grid
			local = grid.to_local(place)
		var dist := worker.position.distance_squared_to(local)
		if dist < best_dist:
			best_dist = dist
			best = worker
	return best

## The waiting haul of the site placed first, extra hauls last. Among one site's hauls, the one that waited longest.
func _oldest_waiting_haul() -> HaulJob:
	var oldest : HaulJob = null
	for job in _pending:
		if job is HaulJob and (oldest == null or _goes_before(job as HaulJob, oldest)):
			oldest = job
	return oldest

## True when haul `a` should be taken before haul `b`: hauls within a site's cap before extra ones, then the older site's.
func _goes_before(a : HaulJob, b : HaulJob) -> bool:
	if a.extra != b.extra:
		return b.extra
	return a.site.build_order < b.site.build_order

## No job waits: offers the builders with nothing to do to the construction sites, oldest first, which
## ask for at least that many more drops past their max_hauls. Runs at most every CHANGED_EVERY_MS, and only after
## a builder became free or a site was placed, so counting the builders stays cheap.
func _offer_idle_builders() -> void:
	var now := Time.get_ticks_msec()
	if not _offer_idle or now - _last_idle_offer < Inventory.CHANGED_EVERY_MS:
		return
	_offer_idle = false
	_last_idle_offer = now
	var sites := get_tree().get_nodes_in_group(Building.CONSTRUCTION_GROUP)
	if sites.is_empty():
		return
	var idle := 0
	for worker in workers:
		if worker.job == null and worker.is_free():
			idle += 1
	# A few at a time: every new haul is matched against every meeple, so thousands at once would stall a frame.
	idle = mini(idle, IDLE_OFFER_BATCH)
	if idle == 0:
		return
	sites.sort_custom(func(a : Building, b : Building) -> bool: return a.build_order < b.build_order)
	for site : Building in sites:
		var asked := site.ask_past_cap(idle)
		if asked > 0:
			# Some of them may still have nothing to do once these hauls are matched: offer again.
			_offer_idle = true
		idle -= asked
		if idle <= 0:
			return

## The waiting job `worker` takes next: the nearest haul of the oldest site that has one waiting, unless
## a job that is not a haul, such as a marked tree, is nearer. Then that job.
func _next_waiting_job(worker : Meeple) -> Job:
	var from := worker.global_position
	var haul : HaulJob = null
	var haul_dist := INF
	var other : Job = null
	var other_dist := INF
	for job in _pending:
		var dist := from.distance_squared_to(job.place())
		if job is HaulJob:
			var same := haul != null and (job as HaulJob).extra == haul.extra and (job as HaulJob).site.build_order == haul.site.build_order
			if haul == null or _goes_before(job as HaulJob, haul) or (same and dist < haul_dist):
				haul = job as HaulJob
				haul_dist = dist
		elif dist < other_dist:
			other = job
			other_dist = dist
	return other if other_dist < haul_dist else haul

## Tells the jobs that `building` has a worker slot with nobody in it.
func open_slot(building : Building) -> void:
	_open_slots.append(building)
	_slot_opened = true

## Takes back one of `building`'s slots that nobody filled yet. Returns false when it had none.
func close_slot(building : Building) -> bool:
	var index := _open_slots.rfind(building)
	if index < 0:
		return false
	_open_slots.remove_at(index)
	return true

## Each open slot takes the nearest free builder, as long as there is one.
func _fill_slots() -> void:
	while not _open_slots.is_empty():
		var building : Building = _open_slots[0]
		var builder := _nearest_free_worker(building.global_position, true)
		if builder == null:
			return
		_open_slots.pop_front()
		building.add_worker(builder)
		_changed = true

## A store trip started: a haul may take it over until it ends.
func store_trip_started(trip : StoreJob) -> void:
	_store_trips.append(trip)

## A store trip ended: stored, put down, or taken over by a haul.
func store_trip_ended(trip : StoreJob) -> void:
	_store_trips.erase(trip)

## The store trip of a free builder with a drop of `kind` nearest to `place`, in world space, whose pile can do without
## that drop. Null when there is none.
func nearest_store_trip(kind : String, place : Vector2) -> StoreJob:
	var best : StoreJob = null
	var best_dist := INF
	for trip in _store_trips:
		if trip.kind() != kind or trip.site.unclaimed() <= 0 or not trip.meeple.is_free():
			continue
		var dist := place.distance_squared_to(trip.spot())
		if dist < best_dist:
			best_dist = dist
			best = trip
	return best

func take_partner(job : HaulJob) -> HaulJob:
	for other in _pending:
		if other is HaulJob and job.pairs_with(other):
			_pending.erase(other)
			_active.append(other)
			return other
	return null

func recall_hauls(site : Building) -> void:
	for worker in workers:
		if worker.job is HaulJob and worker.job.site == site:
			worker.abandon_job()

## The hauls, waiting or under way, that claimed a drop in `pile` and have not picked it up yet.
func hauls_from(pile : Storage) -> Array[HaulJob]:
	var found : Array[HaulJob] = []
	for job in _pending + _active:
		if job is HaulJob and job.takes_from(pile):
			found.append(job)
	return found

func take_pending_hauls(site : Building) -> Array[HaulJob]:
	var taken : Array[HaulJob] = []
	for job in _pending.duplicate():
		if job is HaulJob and job.site == site:
			_pending.erase(job)
			taken.append(job)
	if not taken.is_empty():
		_changed = true
	return taken

## A builder left `haul`, an extra haul it had not picked up, for another job. Its site stops waiting for the drop.
func give_back(haul : HaulJob) -> void:
	_active.erase(haul)
	_changed = true
	haul.site.give_back(haul)

## A site was placed: gives back every extra haul whose drop nobody picked up yet, waiting or walked to, so the
## new site gets builders and stock before the older sites' extra stages.
func drop_extra_hauls() -> void:
	for worker in workers:
		if worker.job is HaulJob and (worker.job as HaulJob).gives_way():
			worker.drop_extra_haul()
	for job in _pending.duplicate():
		if job is HaulJob and (job as HaulJob).extra:
			_pending.erase(job)
			(job as HaulJob).site.give_back(job)
	_changed = true

func finish(job : Job) -> void:
	_active.erase(job)
	_changed = true

func requeue(job : Job, worker : Meeple) -> void:
	job.abort(worker)
	_active.erase(job)
	if not job.cancelled:
		add(job)
	_changed = true

func cancel(job : Job) -> void:
	job.cancelled = true
	_pending.erase(job)
	_active.erase(job)
	_changed = true

func add_worker(worker : Meeple) -> void:
	workers.append(worker)
	worker_freed(worker)
	_changed = true

func remove_worker(worker : Meeple) -> void:
	workers.erase(worker)
	_changed = true
