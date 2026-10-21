class_name ProductCatalog
extends RefCounted
const DEFINITIONS = [

	preload("res://data/products/can.tres"),
	preload("res://data/products/bread.tres"),
	preload("res://data/products/milk.tres"),
	preload("res://data/products/glass_drink.tres"),
	preload("res://data/products/detergent.tres"),
	preload("res://data/products/watermelon.tres"),
	preload("res://data/products/frying_pan.tres"),
	preload("res://data/products/microwave.tres"),
	preload("res://data/products/tv.tres"),
	preload("res://data/products/chips.tres"),
	preload("res://data/products/instant_noodles.tres"),
	preload("res://data/products/cereal.tres"),
	preload("res://data/products/juice.tres"),
	preload("res://data/products/cooking_oil.tres"),
	preload("res://data/products/shampoo.tres"),
	preload("res://data/products/toilet_paper.tres"),
	preload("res://data/products/rice_bag.tres"),
	preload("res://data/products/vacuum_cleaner.tres"),
	preload("res://data/products/appliance.tres")
]

static func find(id: StringName) -> ProductDefinition:
	for entry: ProductDefinition in DEFINITIONS:
		if entry.id == id: return entry
	return null

static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: ProductDefinition in DEFINITIONS:
		if not entry.legacy: result.append(entry.id)
	return result

