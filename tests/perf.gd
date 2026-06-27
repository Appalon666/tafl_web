extends SceneTree
const TaflBoard = preload("res://scripts/core/TaflBoard.gd")
const TaflVariants = preload("res://scripts/core/TaflVariants.gd")
const RulesEngine = preload("res://scripts/core/RulesEngine.gd")
const TaflAI = preload("res://scripts/ai/TaflAI.gd")

func _init() -> void:
	var v = TaflVariants.get_variant("copenhagen")
	var b = TaflBoard.new(11)
	var r = RulesEngine.new(b, v)
	var s = TaflVariants.build_state("copenhagen")
	for cfg in [[2, 1200], [3, 1200], [4, 3000]]:
		var ai = TaflAI.new(cfg[0], cfg[1])
		var t0 = Time.get_ticks_msec()
		var mv = ai.choose_move(r, s)
		var dt = Time.get_ticks_msec() - t0
		print("depth_cap=%d budget=%dms -> reached d%d, %d nodes, %d ms, move %s->%s" % [
			cfg[0], cfg[1], ai.last_depth, ai.last_nodes, dt, mv.from, mv.to])
	quit(0)
