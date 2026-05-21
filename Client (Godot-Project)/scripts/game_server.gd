extends Node

var peer = ENetMultiplayerPeer.new()
var port = 8081 # พอร์ตเริ่มต้น (เผื่อไว้เทสต์เอง)
var max_players = 2
var players_connected = 0

func _ready():
	# 1. อ่านค่า Arguments จาก Command Line
	# รูปแบบคำสั่งที่ Node.js จะเรียกคือ: godot --headless --server-port=8082
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--server-port="):
			port = arg.get_slice("=", 1).to_int() # ดึงตัวเลขออกมา
			
	print("🚀 [GameServer] Preparing to start on port: ", port)
	
	# 2. เริ่มเปิดเซิร์ฟเวอร์ด้วยพอร์ตที่ได้มา
	var err = peer.create_server(port, max_players)
	if err != OK:
		print("❌ [GameServer] Cannot start server.")
		get_tree().quit() # ถ้าเปิดไม่ได้ ให้ปิดโปรแกรมตัวเองทิ้งเลย
		return
		
	multiplayer.multiplayer_peer = peer

	
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)

func _on_player_connected(id):
	players_connected += 1
	print("🎮 [GameServer] Player %d joined. Total: %d" % [id, players_connected])
	rpc("announce_to_all_players", "Player_"+str(id)+" has joined the chat.")

func _on_player_disconnected(id):
	players_connected -= 1
	print("👋 [GameServer] Player %d left. Total: %d" % [id, players_connected])
	rpc("announce_to_all_players", "Player_"+str(id)+" has left the chat.")
	
	# 3. สำคัญมาก! ถ้ายอดผู้เล่นเหลือ 0 (ออกครบทั้งคู่) ให้ปิดเซิร์ฟเวอร์ทิ้งทันที
	if players_connected == 0:
		print("🛑 [GameServer] Room is empty. Shutting down...")
		get_tree().quit()

# ----------------------------------------------------
# โดเมน RPC (Remote Procedure Call)
# ----------------------------------------------------

# ฟังก์ชันนี้จะถูก Client เรียก (ส่งจากเครื่องผู้เล่นมาทำงานบนเครื่อง Server)
# @rpc("any_peer") = อนุญาตให้ Client เครื่องไหนส่งมาก็ได้
@rpc("any_peer")
func register_player_on_server(username: String):
	# ใครเป็นคนส่ง RPC นี้มา? ดึง ID ของเขาออกมา
	var sender_id = multiplayer.get_remote_sender_id()
	print("👤 [GameServer] Player %d registered with name: %s" % [sender_id, username])
	
	# เซิร์ฟเวอร์ประมวลผลเสร็จแล้ว ส่งคำสั่งกลับไปหา "ทุกคน" ให้แสดงข้อความต้อนรับ
	# โดยการเรียกใช้ RPC ฟังก์ชันของฝั่ง Client
	#rpc("announce_to_all_players", username + " has joined the chat!")


# ฟังก์ชันหลอก (Stub) เพื่อไม่ให้ Godot ฟ้อง Error 
# เพราะในระบบ Multiplayer ของ Godot ทุกเครื่องต้องมีชื่อฟังก์ชันตรงกันเป๊ะๆ ถึงจะเรียกหากันได้
@rpc("authority")
func announce_to_all_players(message: String):
	pass # ฝั่ง Server ไม่ต้องทำอะไรในฟังก์ชันนี้ เพราะเราตั้งใจให้ไปรันที่หน้าจอ Client
	
	
# ฟังก์ชันนี้จะถูก Client เรียก (ส่งจากเครื่องผู้เล่นมาทำงานบนเครื่อง Server)
@rpc("any_peer")
func action_player_on_send_msg(username: String,message:String):
	# ใครเป็นคนส่ง RPC นี้มา? ดึง ID ของเขาออกมา
	var sender_id = multiplayer.get_remote_sender_id()
	print("👤 [GameServer] Player name %s has sent msg %s" % [username,message])
	
	# เซิร์ฟเวอร์ประมวลผลเสร็จแล้ว ส่งคำสั่งกลับไปหา "ทุกคน" ให้แสดงข้อความต้อนรับ
	# โดยการเรียกใช้ RPC ฟังก์ชันของฝั่ง Client
	var processed_msg:String = censor_text(message)
	rpc("announce_to_all_players", username + " :"+processed_msg)
	
	
# ----------------------------------------------------
# Utility Function
# ----------------------------------------------------

var bad_words: Array[String] = ["shit", "idiot"]

## ฟังก์ชันเซ็นเซอร์ข้อความ
func censor_text(original_text: String) -> String:
	var censored_text = original_text
	
	for word in bad_words:
		# หากข้อความนั้นมีคำหยาบซ่อนอยู่
		if censored_text.contains(word) or censored_text.to_lower().contains(word.to_lower()):
			# สร้างตัว * ให้ยาวเท่ากับจำนวนตัวอักษรของคำหยาบ (ฟีเจอร์ของ Godot 4)
			var replacement = "*".repeat(word.length())
			
			# แทนที่คำหยาบด้วยเครื่องหมาย *
			# ใช้ replace แบบปกติสำหรับภาษาไทย และ case-insensitive สำหรับภาษาอังกฤษ
			censored_text = censored_text.replace(word, replacement)
			
			# วิธีที่ชัวร์ที่สุดสำหรับการแทนที่แบบไม่สนตัวพิมพ์เล็ก/ใหญ่ (Case-insensitive)
			censored_text = replace_ignore_case(censored_text, word, replacement)
			
	return censored_text

## ฟังก์ชันช่วยเสริม: สำหรับแทนที่คำภาษาอังกฤษแบบไม่สนใจตัวพิมพ์เล็ก/พิมพ์ใหญ่
func replace_ignore_case(text: String, word: String, replacement: String) -> String:
	var regex = RegEx.new()
	# ใส่ (?i) เพื่อบอกให้ Regex ละเว้นการตรวจ Case (เช่น BaDwOrD จะโดนจับหมด)
	regex.compile("(?i)" + word) 
	return regex.sub(text, replacement, true)
