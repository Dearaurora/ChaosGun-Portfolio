extends SceneTree

## Regression gate for eliminated characters. A game-over death intentionally
## has no respawn timer, so BaseCharacter must not run the normal respawn path.


func _initialize() -> void:
	var character := BaseCharacter.new()
	character.name = "EliminatedCharacterProbe"
	root.add_child(character)
	character.is_dead = true
	character.is_game_over = true
	character.lives = 0
	character.visible = false
	character.freeze = true

	character.call("_base_process", 1.0)

	var passed := (
		character.is_dead
		and character.is_game_over
		and character.lives == 0
		and not character.visible
		and character.freeze
	)
	if not passed:
		push_error(
			"Eliminated character re-entered respawn state: dead=%s game_over=%s lives=%d visible=%s freeze=%s"
			% [character.is_dead, character.is_game_over, character.lives, character.visible, character.freeze]
		)
		quit(1)
		return

	print("GAME_OVER_NO_RESPAWN_PASS|dead=true|game_over=true|lives=0")
	quit(0)
