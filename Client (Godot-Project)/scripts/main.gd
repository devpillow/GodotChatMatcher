extends Node
class_name SceneMNG

#ฉากสำหรับเปลี่ยนจอ (manu <-> game )

@onready var current_scene_container = $CurrentScene

var menu_scene = preload("res://scenes/main_manu.tscn")
var game_client_scene = preload("res://scenes/game_client.tscn")

func _ready():
	# เริ่มต้นเกม ให้โหลดฉากเมนูจับคู่ขึ้นมาก่อน
	change_sub_scene(menu_scene)

# ฟังก์ชันสำหรับเคลียร์ฉากเก่า และโหลดฉากใหม่เข้ามาใส่
func change_sub_scene(new_scene: PackedScene):
	# ลบฉากเก่าที่ค้างอยู่ออกให้หมด
	for child in current_scene_container.get_children():
		child.queue_free()
		
	# สร้างฉากใหม่ขึ้นมา และนำไปใส่ใน Container
	var instance = new_scene.instantiate()
	current_scene_container.add_child(instance)
