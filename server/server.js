const WebSocket = require('ws');
const crypto = require('crypto'); // ใช้สำหรับสุ่ม ID
const path = require('path')
const { spawn } = require('child_process'); // เปลี่ยนจาก exec เป็น spawn

const wss = new WebSocket.Server({ port: 8080 });

let queue = []; // ตัวแปรเก็บคนที่กำลังรอจับคู่

let nextAvailablePort = 8081;

// กำหนด Path ของ Godot Executable (แก้ให้ตรงกับเครื่องของคุณ)
// ถ้าเป็น Windows อาจจะเป็น "C:/Path/To/Godot_v4.exe"
// ถ้าตั้ง Environment Variable ไว้แล้ว พิมพ์แค่ "godot" ได้เลย
const godotExecutable = "/Applications/Godot v4.4.1.app/Contents/MacOS/Godot";
// กำหนด Path ไฟล์ server 
const pckPath = path.join(__dirname, "game_server.pck");


console.log("🚀 Matchmaking Server is running on ws://localhost:8080");

wss.on('connection', (ws) => {
    // 1. สร้าง ID ประจำตัวให้คนที่เชื่อมต่อเข้ามา และสถานะห้อง
    ws.id = crypto.randomUUID();
    ws.roomId = null;
    console.log(`[+] Client connected: ${ws.id}`);

    // 2. เมื่อได้รับข้อความจาก Godot
    ws.on('message', (message) => {
        const text = message.toString().trim();

        // 2. ถ้าเป็นข้อความว่างเปล่า ให้หยุดการทำงาน (return) ออกไปเลย ไม่ต้องแจ้ง Error
        if (!text) return;

        try {
            const data = JSON.parse(text); // แปลง JSON String เป็น Object

            if (data.action === 'join_queue') {
                console.log(`⏳ User ${ws.id} joined the queue.`);
                queue.push(ws); // นำใส่คิว
                matchPlayers(); // เรียกฟังก์ชันพยายามจับคู่
            }

        } catch (err) {
            console.log(`[Info] Ignored non-JSON packet from Client.`);
        }
    });

    // 3. เมื่อผู้เล่นปิดเกม หรือเน็ตหลุด
    ws.on('close', () => {
        console.log(`[-] Client disconnected: ${ws.id}`);

        // ถ้ากำลังรอคิวอยู่ ให้ลบออกจากคิว
        queue = queue.filter(client => client !== ws);

        // ถ้าอยู่ในห้องแชท ให้เตือนอีกคนว่าคู่สนทนาหนีไปแล้ว และยุบห้องทิ้ง
        if (ws.roomId && rooms[ws.roomId]) {
            rooms[ws.roomId].forEach(client => {
                if (client !== ws && client.readyState === WebSocket.OPEN) {
                    client.send(JSON.stringify({ action: 'partner_disconnected' }));
                    client.roomId = null; // รีเซ็ตสถานะคนที่เหลือ
                }
            });
            delete rooms[ws.roomId]; // ลบห้องทิ้ง
            console.log(`[Room] Room ${ws.roomId} destroyed.`);
        }
    });
});
function matchPlayers() {
    while (queue.length >= 2) {
        const player1 = queue.shift();
        const player2 = queue.shift();

        const roomId = crypto.randomUUID(); 
        // const gameServerIp = "127.0.0.1";
        const gameServerIp = "25.4.124.172"; //hamachi IP
        const gameServerPort = nextAvailablePort;
        nextAvailablePort++; 

        console.log(`⚙️ [System] Spawning Godot Server on port ${gameServerPort}...`);

        const args = [
            '--main-pack', pckPath,
            '--headless',
            `--server-port=${gameServerPort}`
        ];

        let serverProcess;
        
        try {
            // สั่งรันผ่านไฟล์ที่ไม่มีช่องว่างแล้ว
            serverProcess = spawn(godotExecutable, args);

            // ดักจับ Log จากภายใน Godot
            serverProcess.stdout.on('data', (data) => {
                console.log(`[Godot Port ${gameServerPort}] ${data.toString().trim()}`);
            });

            // ดักจับ Error จาก Godot
            serverProcess.stderr.on('data', (data) => {
                console.error(`[Godot Port ${gameServerPort} ERROR] ${data.toString().trim()}`);
            });

            serverProcess.on('close', (code) => {
                console.log(`🛑 [System] Godot Server on Port ${gameServerPort} exited with code ${code}`);
            });

        } catch (spawnError) {
            console.error("❌ CRITICAL: Failed to spawn Godot process!", spawnError.message);
            return; // หยุดทำงานไม่ให้ระบบค้าง
        }

        // บรรทัดนี้ต้องทำงานแล้วครับ!
        console.log(`⏳ [System] Waiting 1.5s for Godot to initialize port ${gameServerPort}...`);

        setTimeout(() => {
            try {
                if (player1.readyState === WebSocket.OPEN && player2.readyState === WebSocket.OPEN) {
                    
                    const ticket = JSON.stringify({ 
                        action: 'match_found', 
                        roomId: roomId,
                        serverIp: gameServerIp,
                        serverPort: gameServerPort
                    });

                    player1.send(ticket);
                    player2.send(ticket);
                    
                    console.log(`🎟️ [Handover] Successfully sent ticket for Port ${gameServerPort}`);
                } else {
                    console.log("⚠️ Matchmaking aborted: One of the players disconnected.");
                }
            } catch (e) {
                console.error("❌ Failed to send ticket:", e.message);
            }
        }, 1500); 
    }
}