extends Node

@onready var sendBtn:Button = $sendBtn
@onready var txtLine = $inputTxtBox
@onready var textLog = $logLbl

var game_peer = ENetMultiplayerPeer.new()

func _ready() -> void:
	connect_to_game_server(NetworkMng.game_ip,NetworkMng.game_port,NetworkMng.room_id)
	sendBtn.pressed.connect(_on_pressed_sendmsgbtn)
	
# ฟังก์ชันนี้ทำงานเมื่อ Client เชื่อมต่อสำเร็จ (จากสเต็ปที่ 3 เดิม)
func connect_to_game_server(ip: String , port: int, room_id: String):
	
	var err = game_peer.create_client(ip, port)
	if err != OK: return
	
	multiplayer.multiplayer_peer = game_peer

	
	multiplayer.connected_to_server.connect(_on_connected_ok)

func _on_connected_ok():
	print("✅ Connected to Game Server successfully!")
	textLog.text += "\n" + str("✅ Connected to Game Server successfully!")
	# [จุดเชื่อมโยง] ส่งข้อมูลไปหาเซิร์ฟเวอร์เพื่อลงทะเบียน 
	# สั่งรันฟังก์ชัน register_player_on_server บนเครื่อง Server
	rpc("register_player_on_server", "Player_" + str(multiplayer.get_unique_id()))

# ----------------------------------------------------
# โดเมน RPC (ฝั่ง Client)
# ----------------------------------------------------

# @rpc("any_peer") ฝั่งเซิร์ฟเวอร์ต้องใส่ตัวนี้ไว้เพื่อให้ Client เรียกหาได้
@rpc("any_peer")
func register_player_on_server(username: String):
	pass # ฝั่ง Client ไม่ต้องใส่โค้ดในฟังก์ชันนี้ เพราะมันจะไปทำงานบนเครื่อง Server

# @rpc("authority") = บอกว่าฟังก์ชันนี้ "เซิร์ฟเวอร์เท่านั้น" ที่มีสิทธิ์สั่งให้รันบนจอผู้เล่นได้
@rpc("authority")
func announce_to_all_players(message: String):
	# โค้ดตรงนี้จะทำงานบนหน้าจอของผู้เล่นทุกคน!
	print("📢 [Broadcast] " + message)
	textLog.text += "\n" + str(message)
	# คุณสามารถนำข้อความนี้ไปใส่ใน Label บนหน้าจอ UI ของเกมได้เลย

#ฟังก์ชันนี้จะถูก Client เรียก
@rpc("any_peer")
func action_player_on_send_msg(username: String,message:String):
	pass
# ----------------------------------------------------
# function สำหรับ UI
# ----------------------------------------------------

func _on_pressed_sendmsgbtn():
	if txtLine.text == "" : return
	rpc("action_player_on_send_msg", "Player_" + str(multiplayer.get_unique_id()),txtLine.text)
	
	txtLine.text = ""
