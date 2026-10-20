# Backpack crafting: output item id -> {ingredient item id: quantity}. Left-clicking an
# ingredient stack in the backpack crafts one output, if every ingredient is held and
# the backpack has room. Handled by Raid.request_craft().
# Currently empty: scrap was removed. Add {"output_id": {"ingredient_id": qty}} to bring crafting back.
const DATA := {}
