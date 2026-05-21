# GodotChatMatcher
ระบบจับคู่ผู้เล่น (Matchmaking) แบบ 2 คน เพื่อจัดสรรห้องและดึงผู้เล่นเข้าสู่ Dedicated Server ตัวเดียวกันโดยอัตโนมัติ

#### เทคโนโลยีที่ใช้
- Node.js (Matchmaking & Process Management)
- Godot Engine v4.x (Gameplay & Dedicated Server)
- Protocol: WebSockets (คิวจับคู่) / ENet หรือ WebSockets (เซิร์ฟเวอร์เกม)


## How it works -
client เชื่อมต่อกับ server (node.js) ที่เปิดผ่าน WebSocket 
```
node server.js
```

- Client เข้าคิว: ผู้เล่นเชื่อมต่อกับ Matchmaking Server (Node.js) ผ่าน WebSocket จากนั้นเมื่อกดปุ่ม "จับคู่" Client จะส่งอีเวนต์ join_queue ไปลงทะเบียนไว้ใน Array คิว

- จับคู่ & เสกห้อง: เมื่อคิวสะสมครบ 2 คน ตัว Node.js จะใช้คำสั่ง spawn สั่งเปิดตัวเกม Godot ในโหมดไร้หน้าจอ (Headless Dedicated Server) พร้อมสุ่มพอร์ตใหม่ให้ห้องนั้น (เช่น 8081, 8082)

- ส่งตั๋วเดินทาง: Node.js ส่งตั๋วข้อมูล (Ticket) ที่แนบเลข IP และ Port ของห้องที่เพิ่งสร้างเสร็จกลับไปให้ Client ทั้งสองเครื่อง จากนั้น Client จะตัดสายจาก Node.js เพื่อย้ายบ้านไปเชื่อมต่อกับเซิร์ฟเวอร์เกมตัวจริง
  
### ระบบแชท / ส่งข้อความหากัน
- ตัว Dedicated Server ย่อยจะเปิดพอร์ตมารองรับผู้เล่นด้วย ENetMultiplayerPeer หรือ WebsocketMultiplayerPeer โดยทำงานอยู่บนสถาปัตยกรรมแบบ Authority Server (เซิร์ฟเวอร์เป็นใหญ่)
```
var game_peer = ENetMultiplayerPeer.new()
func connect_to_game_server(ip: String , port: int, room_id: String):
	var err = game_peer.create_client(ip, port)
	if err != OK: return
	multiplayer.multiplayer_peer = game_peer
```
### การรับ-ส่งข้อมูลด้วย @rpc
ในตัว Dedicated Server และ Client มีการประกาศฟังก์ชัน RPC (Remote Procedure Call) เพื่อใช้สื่อสารข้ามเครื่อง โดยโค้ดข้างในฟังก์ชันไม่จำเป็นต้องเหมือนกัน เพื่อให้เซิร์ฟเวอร์ดักตรวจสอบ/ประมวลผลข้อมูลก่อนกระจายกลับไปให้ทุกคนในห้อง

```
@rpc("any_peer") #เรียกใช้โดย client -> สั่งให้โค้ดรันบนเครื่อง Server
func register_player_on_server(username: String):
	pass

@rpc("authority") #เรียกใช้โดย server -> สั่งให้โค้ดรันบนหน้าจอของ Client ทุกคน
func announce_to_all_players(message: String):
  pass
```


## วิธีการติดตั้ง Dedicated godot server
1. ฝั่ง Godot (การเตรียมไฟล์ .pck)
- เลือกฉาก (Scene) ที่ทำหน้าที่เป็นเซิร์ฟเวอร์คำนวณ คอนโทรลตรรกะเกม
- สั่ง Export โปรเจกต์ออกเป็นไฟล์เฉพาะแพ็กเกจข้อมูลอย่าง .pck (เช่น game_server.pck)
#### ⚠️ กฎเหล็กเรื่องตำแหน่ง Node (Node Path):
เส้นทาง Tree ของโหนดที่แปะสคริปต์ RPC ทั้งฝั่ง Server และ Client ต้องตรงกัน 100% ตั้งแต่ราก (เช่น /root/Main/CurrentScene/GameClient) มิฉะนั้น Godot จะปฏิเสธแพ็กเกจข้อมูลเพราะหาโหนดปลายทางไม่เจอ (ตัวประเภทโหนดหรือโค้ดข้างในต่างกันได้ แต่ชื่อโหนดทางผ่านต้องตรงกันเป๊ะ)

เขียนสคริปต์ในไฟล์ server.pck มารองรับการอ่านพอร์ตไดนามิกจาก Node.js:
```func _ready():
	# อ่านค่า Arguments ที่ส่งมาจาก Command Line (เช่น --server-port=8082)
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--server-port="):
			port = arg.get_slice("=", 1).to_int() 
			
	print("🚀 [GameServer] Preparing to start on port: ", port)
    # จากนั้นนำตัวแปร port ไปเข้าฟังก์ชัน create_server()
```

2. ฝั่ง Node.js (การสั่งเปิดกระบวนการเบื้องหลัง)
- นำไฟล์ .pck ไปวางไว้ในโฟลเดอร์เดียวกับ server.js และใช้โมดูล child_process สั่งเปิดโปรแกรมโดยแยกอาร์กิวเมนต์ (Arguments) ออกจากกันเพื่อความปลอดภัยและเสถียรภาพบน OS (เช่น Windows/Mac)
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
