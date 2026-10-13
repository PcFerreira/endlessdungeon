extends "res://tools/measure_kill_rewards.gd"

func _validate(report: Dictionary) -> void:
	assert(Items.valid_policy(Items.policy))
	assert(report.totals.coins == report.totals.kills)
	assert(report.totals.health_orbs + report.totals.mana_orbs == report.totals.kills)
	for scenario in report.reports:
		var counts: Dictionary = scenario.counts
		var coin_only: float = float(counts.coin_only_inventory_kills) / counts.kills
		assert(coin_only > .68 and coin_only < .80, "Coins should be the usual inventory reward in every class/family")
		assert(float(counts.shards) / counts.kills > .04 and float(counts.shards) / counts.kills < .12)
		assert(float(counts.ordinary_items) / counts.kills > .15 and float(counts.ordinary_items) / counts.kills < .25)
	for value in [-.1, 1.1, "unbounded", null]:
		var bad: Dictionary = Items.policy.duplicate(true)
		bad.enemy_shard_chance = value
		assert(not Items.valid_policy(bad))
	var odd_shard := false
	var missed_even := false
	for ordinal in range(1, 501):
		var drop := Items.should_drop_shard(42, ordinal)
		assert(drop == Items.should_drop_shard(42, ordinal))
		odd_shard = odd_shard or (drop and ordinal % 2 == 1)
		missed_even = missed_even or (not drop and ordinal % 2 == 0)
	assert(odd_shard and missed_even, "Shards must not retain a fixed alternating cadence")
