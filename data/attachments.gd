# Weapon attachments: super rare drops (Tuning.ATTACHMENT_DROP_CHANCE per kill). They are items (ids in
# data/loot.gd), banked in the stash when you extract, and fitted to a weapon at the ammo depot (one per weapon).
# They are not lost when the raid is, but every shot fired with the weapon wears the attachment down; at 0 it is
# BROKEN and does nothing until it is repaired at the ammo depot with REPAIR_SCRAP scrap (looted from enemies).
#   durability: shots it lasts    effects (all optional):
#   damage: damage multiplier   spread: spread multiplier   cooldown: wait-between-shots multiplier
#   reload: reload-time multiplier   zoom: multiplies the weapon's zoom field of view (0.5 = twice as far; a weapon with
#   a working scope shows the scope view once zoomed in far enough)
#   model: the Kenney Blaster Kit piece shown when it lies on the ground
const REPAIR_SCRAP := 5
const DATA := {
	"att_heavy_barrel": {"name": "Heavy Barrel", "desc": "+20% damage", "durability": 120, "damage": 1.2, "model": "res://assets/weapons/kenney_blaster_kit/silencer-larger.glb"},
	"att_compensator": {"name": "Compensator", "desc": "half the spread, 10% faster firing", "durability": 120, "spread": 0.5, "cooldown": 0.9, "model": "res://assets/weapons/kenney_blaster_kit/silencer-small.glb"},
	"att_speed_loader": {"name": "Speed Loader", "desc": "25% faster reloads", "durability": 120, "reload": 0.75, "model": "res://assets/weapons/kenney_blaster_kit/clip-large.glb"},
	"att_scope": {"name": "Scope", "desc": "zoom in twice as far, through a scope", "durability": 120, "zoom": 0.5, "model": "res://assets/weapons/kenney_blaster_kit/scope-large-a.glb"},
}
