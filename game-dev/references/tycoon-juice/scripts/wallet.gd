extends Node
## Autoload named `Wallet`. One place for the player's cash, so the HUD counter,
## the unlock pads and the floating "+$" text all hear about the same events.
##
## `earned` carries the world position where the money was made, so the game
## can spawn a "+$12" there and fly a coin from there to the counter.

signal changed(cash: int)
signal earned(amount: int, world_position: Vector3)
signal spent(amount: int)
signal rejected(amount: int)

var cash: int = 0


func add(amount: int, world_position: Vector3 = Vector3.INF) -> void:
	if amount <= 0:
		return
	cash += amount
	earned.emit(amount, world_position)
	changed.emit(cash)


## False (and a `rejected` signal for the red flash) when not enough cash.
func try_spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if cash < amount:
		rejected.emit(amount)
		return false
	cash -= amount
	spent.emit(amount)
	changed.emit(cash)
	return true


func can_afford(amount: int) -> bool:
	return cash >= amount


func set_cash(value: int) -> void:
	cash = maxi(value, 0)
	changed.emit(cash)
