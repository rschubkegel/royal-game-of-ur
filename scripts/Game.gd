extends Node

export (PackedScene) var MainMenu
export (PackedScene) var Lobby
export (PackedScene) var JoinPopup
export (PackedScene) var Game

const MENU_BTN_PATH = 'rows/actions/menu_button'
const PLAY_BTN_PATH = 'hbox/vbox/play_local'
const HOST_BTN_PATH = 'hbox/vbox/hbox/host'
const JOIN_BTN_PATH = 'hbox/vbox/hbox/join'
const IP_LBL_PATH = 'hbox/vbox/ip_label'
const PLAY_LOBBY_BTN_PATH = 'hbox/vbox/play'
const MENU_LOBBY_BTN_PATH = 'hbox/vbox/menu'
const CONNECT_BTN_PATH = 'vbox/connect'
const CONNECT_IP_PATH = 'vbox/hbox/ip_selector'

# Reference: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
const IP_FORMAT = '192\\.168\\.\\d+\\.\\d+'
const SERVER_PORT = 8000
const MAX_PLAYERS = 2


# add main menu on application startup
func _ready():
	main_menu()


# add menu to tree and connect signals
func main_menu():
	var menu = MainMenu.instance()
	add_child(menu)
	menu.get_node(PLAY_BTN_PATH).connect('pressed', self, 'play_local')
	menu.get_node(PLAY_BTN_PATH).connect('pressed', menu, 'queue_free')
	
	menu.get_node(HOST_BTN_PATH).connect('pressed', self, 'host_game')
	menu.get_node(HOST_BTN_PATH).connect('pressed', menu, 'queue_free')
	
	menu.get_node(JOIN_BTN_PATH).connect('pressed', self, 'join_dialog', [menu])


# add game to tree and connect signals
func play_local():
	var game = Game.instance()
	add_child(game)
	game.get_node(MENU_BTN_PATH).connect('pressed', self, 'main_menu')
	game.get_node(MENU_BTN_PATH).connect('pressed', game, 'queue_free')


# show dialog to connect to existing game on the network
func join_dialog(menu):
	var popup = JoinPopup.instance()
	add_child(popup)
	popup.get_node(CONNECT_BTN_PATH).connect('pressed', self, 'join_game', [popup, menu])
	popup.popup_centered()


# remove popup and main menu from scene and
# join an existing game on the local network
func join_game(popup, menu):
	var ip = '192.168.0.%d' % popup.get_node(CONNECT_IP_PATH).value
	popup.queue_free()
	
	print('Joinging game at %s' % ip)
	var peer = NetworkedMultiplayerENet.new()
	var e = peer.create_client(ip, SERVER_PORT)
	if e:
		print('Could not connect to server at %s' % ip)
		peer.free()
	else:
		get_tree().network_peer = peer
		menu.queue_free()


# start server and enter lobby
func host_game():
	var lobby = Lobby.instance()
	add_child(lobby)
	
	var ip = init_server()
	if ip:
		lobby.get_node(IP_LBL_PATH).text = 'Server hosted at %s' % ip
		lobby.get_node(MENU_LOBBY_BTN_PATH).connect('pressed', self, 'main_menu')
		lobby.get_node(MENU_LOBBY_BTN_PATH).connect('pressed', lobby, 'queue_free')
	else:
		print('Could not create server')

# create a game server and return its ip address on success or null on failure
func init_server():
	var peer = NetworkedMultiplayerENet.new()
	var e = peer.create_server(SERVER_PORT, MAX_PLAYERS)
	if e:
		print('Error: could not create server')
		peer.queue_free()
		return null
	
	get_tree().network_peer = peer
	
	# connect network event callbacks
	get_tree().connect('network_peer_connected', self, 'player_connected')
	get_tree().connect('network_peer_disconnected', self, 'player_disconnected')
	
	return get_ip()


# returns the local IPv4 that server will be hosted on or null on failure
func get_ip():
	# get all IPv4 and IPv6 for computer and search for the correct format
	var addresses = IP.get_local_addresses()
	var ip = null
	var ip_regex = RegEx.new()
	ip_regex.compile(IP_FORMAT)
	var i = 0
	while i < addresses.size():
		if ip_regex.search(addresses[i]):
			ip = addresses[i]
			break
		i += 1
	return ip


func player_connected(id):
	print('Player %s connected' % str(id))


func player_disconnected(id):
	print('Player %s disconnected' % str(id))
