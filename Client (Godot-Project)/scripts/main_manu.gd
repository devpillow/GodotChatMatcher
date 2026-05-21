extends Control

var socket = WebSocketPeer.new()
#var url = "ws://localhost:8080"
var url = "ws://25.4.124.172:8080" #hamachi IP
var is_connected_to_server = false

@onready var logLbl:RichTextLabel = $logLabel
@onready var joinQueueBtn:Button = $joinqueueButton
func _ready():
	print("Connecting to Matchmaking Server...")
	socket.connect_to_url(url)

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected_to_server:
			is_connected_to_server = true
			print("✅ Connected! Ready to match.")
			logLbl.text += "\n ✅ Connected! Ready to match."
			
		# อ่านแพ็กเกจทั้งหมดที่ Server ส่งมา
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			var message = packet.get_string_from_utf8()
			handle_server_message(message)
			
	elif state == WebSocketPeer.STATE_CLOSED:
		is_connected_to_server = false
		set_process(false)
		print("❌ Disconnected from Match maker Server.")
		logLbl.text += "\n ❌ Disconnected from Match maker Server."
	
	if queuejoined : looptext(_delta)
# --------------------------------------------------
# ฟังก์ชันสำหรับให้ UI (ปุ่มต่างๆ) เรียกใช้งาน
# --------------------------------------------------

# เรียกเมื่อกดปุ่ม "ค้นหาห้อง"
var queuejoined :bool = false
func join_queue():
	if is_connected_to_server and not queuejoined:
		queuejoined = true
		joinQueueBtn.disabled = true
		print("⏳ Joining queue...")
		logLbl.text += "\n ⏳ Joining queue..."
		send_json({"action": "join_queue"})

var interval:float = 5
func looptext(_delta:float): 
	interval = interval - _delta
	if interval <0 :
		logLbl.text += "\n ⏳ Waiting..."
		interval =5

# เรียกเมื่อกดปุ่ม "ส่งข้อความแชท" (ส่ง string เข้ามา)
#func send_chat(text: String):
	#if is_connected_to_server:
		#send_json({
			#"action": "chat_message",
			#"text": text
		#})

# ฟังก์ชันตัวช่วยแปลง Dictionary เป็น JSON
func send_json(data: Dictionary):
	var json_str = JSON.stringify(data)
	socket.send_text(json_str)

# ทดสอบโดยใช้ปุ่มคีย์บอร์ดชั่วคราว
func _input(event:InputEvent):
	if event is InputEventKey :
		# กด Spacebar เพื่อเข้าคิว
		if event.is_action_pressed("ui_accept"): 
			join_queue()
		# กดเลข 1 เพื่อทดสอบส่งแชท
		
		#elif event.is_action_pressed("KEY_1"):
			#send_chat("Hello from Player!")


# --------------------------------------------------
# ตัวจัดการข้อความจาก Server
# --------------------------------------------------

func handle_server_message(message: String):
	var json = JSON.new()
	var error = json.parse(message)
	
	if error == OK:
		var data = json.get_data()
		var action = data.get("action", "")
		
		match action:
			"match_found":
				var room_id = data.get("roomId", "")
				var game_ip = data.get("serverIp", "")
				var game_port = data.get("serverPort", 0)
				
				print("🎉 Match Found! Got ticket for Room: ", room_id)
				print("🔄 Disconnecting from Matchmaker...")
				logLbl.text += "\n 🎉 Match found."
				logLbl.text += "\n 🔄 Disconnecting from Matchmaker...."
				
				# 1. ตัดการเชื่อมต่อจาก Matchmaking Server ทันที
				socket.close()
				is_connected_to_server = false
				
				# 2. สั่งให้เริ่มเชื่อมต่อเซิร์ฟเวอร์เกมเพลย์ (สามารถส่งค่า IP/Port ข้ามไปรันต่อได้)
				# แนะนำให้ย้ายฟังก์ชัน connect_to_game_server ไปไว้ในฉาก GameClient ที่เพิ่งเปิดใหม่แทนครับ
				connect_to_game_server(game_ip, game_port, room_id)
				
	else:
		print("Failed to parse JSON")

# ฟังก์ชันใหม่สำหรับการย้ายเซิร์ฟเวอร์
func connect_to_game_server(ip: String, port: int, room_id: String):
	print("🚀 Moving to Game Server at %s:%d" % [ip, port])
	print("🔑 Using Room ID as session token: ", room_id)
	
	# TODO ในสเต็ปที่ 3: 
	# ตรงนี้เราจะโหลด Scene ใหม่ (ฉากเกม)
	# และเริ่มใช้ ENetMultiplayerPeer หรือ WebSocketMultiplayerPeer วิ่งไปที่ ip:port นี้
	
	var main_node:SceneMNG = get_parent().get_parent()
	NetworkMng.room_id = room_id
	NetworkMng.game_ip = ip
	NetworkMng.game_port = port
	main_node.change_sub_scene(main_node.game_client_scene)
