# Weapon attachments: super rare drops (Tuning.ATTACHMENT_DROP_CHANCE per kill). They are items (ids in
# data/loot.gd), banked in the stash when you extract, and fitted to a weapon at the ammo depot (one per weapon).
# They are not lost when the raid is, but every shot fired with the weapon wears the attachment down; at 0 it is
# BROKEN and does nothing until it is repaired at the ammo depot with REPAIR_SCRAP scrap (looted from enemies).
#   durability: shots it lasts    effects (all optional):
#   damage: damage multiplier   spread: spread multiplier   cooldown: wait-between-shots multiplier
#   reload: reload-time multiplier
const REPAIR_SCRAP := 5
const DATA := {
	"att_heavy_barrel": {"name": "Heavy Barrel", "desc": "+20% damage", "durability": 120, "damage": 1.2},
	"att_compensator": {"name": "Compensator", "desc": "half the spread, 10% faster firing", "durability": 120, "spread": 0.5, "cooldown": 0.9},
	"att_speed_loader": {"name": "Speed Loader", "desc": "25% faster reloads", "durability": 120, "reload": 0.75},
}
