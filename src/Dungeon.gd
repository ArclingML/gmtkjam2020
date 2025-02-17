extends Node2D

const CURTAIN_RIGHT_BOUND = 587
const CURTAIN_LEFT_BOUND = -217
const CURTAIN_CLOSED_BOUND = 250
const CURTAIN_SPEED = 50

const FLOOR_CHANGE = 10

# world things
onready var mapgen = $MapGen
onready var tilemap = $TileMap
onready var enemies = $Enemies
onready var chests = $Chests
onready var battles = $Battles
onready var exit : Area2D = $Exit
onready var dialogue = $UI/Dialogue
onready var curtain = $UI/Curtain

# party things
onready var party = $Party
onready var player = $Party/Player

var cur_level = 0
enum STATE{
	roaming,
	paused,
	loading
}
var cur_state = STATE.loading
var foreground_color : Color = Color.blue
var background_color : Color = Color.coral
var background_music : AudioStreamPlayer = null

var astar_data = null

const dark_colors = [
	Color("#002b36"),
	Color("#073642"),
	Color("#586e75"),
	Color("#657b83"),
	Color("#839496"),
	Color("#93a1a1"),
	Color("#eee8d5"),
	Color("#fdf6e3")
]

const light_colors = [
	Color("#b58900"),
	Color("#cb4b16"),
	Color("#dc322f"),
	Color("#d33682"),
	Color("#6c71c4"),
	Color("#268bd2"),
	Color("#2aa198"),
	Color("#859900")
]

func get_rand_from_arr(arr):
	return arr[randi() % arr.size()]

func roll_colors():
	var light_color = get_rand_from_arr(light_colors)
	var dark_color = get_rand_from_arr(dark_colors)
	if randi() % 2 == 0:
		foreground_color = light_color
		background_color = dark_color
	else:
		foreground_color = dark_color
		background_color = light_color

func roll_music():
	if(background_music != null):
		background_music.playing = false
	background_music = $Music.get_child(randi() % $Music.get_child_count())

func _ready():
	randomize()
	mapgen.init(self, tilemap, party, enemies, chests, exit)
	for child in party.get_children():
		child.init(self, tilemap, party, enemies, chests, exit)
	for child in battles.get_children():
		child.init(self, tilemap, party, enemies, chests, exit)
	dialogue.start("res://dialogue/opening2.json")
	go_to_next_level()

func _physics_process(delta):
	match cur_state:
		STATE.loading:
			close_curtain(delta)
		STATE.paused:
			pass
		STATE.roaming:
			open_curtain(delta)
			for child in party.get_children() + enemies.get_children():
				child.call("roaminghandler", delta)
			if !background_music.playing:
				background_music.play()

func world_to_map(pos: Vector2):
	var vcoords = tilemap.world_to_map(pos)
	var coords = [int(round(vcoords.x)), int(round(vcoords.y))]
	return coords

func _on_Exit_body_entered(body):
	if(body.get_name() == "Player"):
		for p in party.get_children():
			if p.get_combatant_data().in_battle == true:
				print("a teammate remains, you cannot leave!")
				p.announce_stuck()
				return
		go_to_next_level()

func get_all_quips():
	var path = "res://dialogue/quips/"
	var files = []
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()
	
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			files.append(path + file)
	return files

func go_to_next_level():
	cur_state = STATE.loading
	for child in chests.get_children() + enemies.get_children():
		child.queue_free()
	for child in party.get_children():
		if child.get_combatant_data().dead():
			child.queue_free()
	yield(get_tree().create_timer(1.0), "timeout")
	
	astar_data = mapgen.generate_world(cur_level)
	for child in enemies.get_children():
		child.init(self, tilemap, party, enemies, chests, exit)
		child.update_astar(astar_data)
		child.level_enemy(cur_level)
	for child in party.get_children():
		child.update_astar(astar_data)
	if cur_level % FLOOR_CHANGE == 0:
		roll_music()
		roll_colors()
	change_foreground_color(foreground_color)
	change_background_color(background_color)

	cur_level += 1
	if randi() % 4 == 0:
		dialogue.start(get_rand_from_arr(get_all_quips()))
	cur_state = STATE.roaming

func close_curtain(delta):
	if curtain.get_position()[0] < CURTAIN_LEFT_BOUND:
		curtain.set_position(Vector2(CURTAIN_RIGHT_BOUND, curtain.get_position()[1]))
	elif curtain.get_position()[0] > CURTAIN_CLOSED_BOUND:
		curtain.set_position(curtain.get_position()+Vector2(-CURTAIN_SPEED,0))

func open_curtain(delta):
	if curtain.get_position()[0] > CURTAIN_CLOSED_BOUND:
		curtain.set_position(Vector2(CURTAIN_CLOSED_BOUND, curtain.get_position()[1]))
	elif curtain.get_position()[0] > CURTAIN_LEFT_BOUND:
		curtain.set_position(curtain.get_position()+Vector2(-CURTAIN_SPEED,0))

func change_foreground_color(color: Color):
	# tileset
	var tileset = tilemap.get_tileset()
	for tile in tileset.get_tiles_ids():
		tileset.tile_set_modulate(tile, color)
	# sprites
	for child in party.get_children() + chests.get_children() + enemies.get_children():
		child.change_color(color)
	exit.change_color(color)

func change_background_color(color: Color):
	VisualServer.set_default_clear_color(color)

func init_battle(position):
	for battle in battles.get_children():
		if !battle.fighting:
			battle.global_position = position
			yield(get_tree().create_timer(0.2), "timeout")
			battle.start_battle()
			return

func return_to_menu():
	cur_state = STATE.loading
	yield(get_tree().create_timer(0.5), "timeout")
	get_tree().change_scene("res://MainMenu.tscn")

func game_over():
	cur_state = STATE.loading
	yield(get_tree().create_timer(0.5), "timeout")
	get_tree().change_scene("res://Gameover.tscn")
