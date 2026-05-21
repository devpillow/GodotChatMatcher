# GodotChatMatcher
ระบบจับคู่ผู้เล่น 2 คน เข้ามาอยู่ใน server เดียวกัน

เนื้อหาหลัก
- ระบบ Client-Server
- Dedicated godot server
- ระบบจับคู่ Node.js


## How it works -
client เชื่อมต่อกับ server (node.js) ที่เปิดผ่าน WebSocket 
```
node server.js
```

-> client กดปุ่ม "จับคู่" client จะส่งข้อมูล "join_queue" ให้กับ server ทำให้ server เก็บ client เข้า queue
-> เมื่อ queue ครบ 2 client -> server สร้าง dedicated server และ ส่งข้อมูลให้กับ client ว่าจับคู่ได้แล้ว พร้อมกับ IP,PORT สำหรับเชื่อมต่อ dedicated server

### ระบบแชท / ส่งข้อความหากัน
- dedicated server คือไฟล์ godot อีกตัวนึง ทำหน้าที่สร้างห้องกฏเกมทิ้งไว้ให้ client ใช้ เชื่อมต่อโดย ENetMultiplayerPeer หรือ WebsocketMultiplayerPeer
```
var game_peer = ENetMultiplayerPeer.new()
func connect_to_game_server(ip: String , port: int, room_id: String):
	var err = game_peer.create_client(ip, port)
	if err != OK: return
	multiplayer.multiplayer_peer = game_peer
```
- ในตัว dedicated server และ client มีการประกาศ RPC(Remote Procedure Call) Function เพื่อรองรับกับระบบ Client-Server
-> client ส่งข้อความ จะต้องเรียกใช้ function action_player_on_send_msg(message) -> function action_player_on_send_msg(message) ฝั่ง server ก็จะทำงานด้วย ซึ่งเนื้อหา function ของฝั่ง client/server ไม่จำเป็นต้องเหมือนกัน ทำให้จังหวะนี้ server ได้จังหวะประมวลข้อความ ก่อนที่ข้อความนี้จะส่งคืนกับ client ทั้งสองคน

```
@rpc("any_peer") #เรียกใช้โดย client
func register_player_on_server(username: String):
	pass

@rpc("authority") #เรียกใช้โดย server
func announce_to_all_players(message: String):
  pass
```


## วิธีการติดตั้ง Dedicated godot server
-> เลือกฉากที่จะให้เป็น server -> export godot project เป็นไฟล์ .pck 
*ข้อควรระวัง : เส้นทาง tree ของ godot server กับ client จะต้องเหมือนกัน เช่น
```
Client 
> main/currentScene/gameClient

Godot server
> main/currentScene/gameClient

#ชื่อเส้นทางจะต้องเหมือนกัน แต่ชื่อไฟล์หรือ script ไม่จำเป็นต้องเหมือนกัน
```
-> รันคำสั่งสำหรับสร้าง Dedicated godot server
```
const godotExecutable = "C:/Path/To/Godot_v4.exe"; //ตัวอย่าง path
const pckPath = path.join(__dirname, "game_server.pck"); // ไฟล์สำหรับสร้าง dedicated server
const gameServerIp = "25.4.124.172"; //hamachi IP

const args = [
            '--main-pack', pckPath,
            '--headless',
            `--server-port=${gameServerPort}` //อันนี้เพิ่มขึ้นมา เพื่อจะได้เปลี่ยนเป็น port ใหม่
        ];

 let serverProcess;
  try {serverProcess = spawn(godotExecutable, args);
//...
}
```
หรือคำสั่ง
```
C:/Path/To/Godot_v4.exe --main-pack projectname.pck --headless
```
แต่แบบนี้จะไม่มี port จะต้องกำหนด port เพิ่มเป็น argurment เข้าไป
```
C:/Path/To/Godot_v4.exe --main-pack projectname.pck --headless --server-port=8081
```
ไฟล์ server.pck
```
func _ready():
	# 1. อ่านค่า Arguments จาก Command Line
	# รูปแบบคำสั่งที่ Node.js จะเรียกคือ: godot --headless --server-port=8082
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--server-port="):
			port = arg.get_slice("=", 1).to_int() # ดึงตัวเลขออกมา
			
	print("🚀 [GameServer] Preparing to start on port: ", port)
```
