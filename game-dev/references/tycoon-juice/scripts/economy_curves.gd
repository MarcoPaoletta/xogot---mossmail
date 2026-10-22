class_name EconomyCurves
extends RefCounted
## The numbers behind the loop. Pure functions, no state, easy to retune from
## analytics: costs grow geometrically, income grows roughly linearly with
## level, and the gap between the two is what the player feels as pacing.


## Cost of buying level `level` (0 based) of an upgrade.
static func level_cost(base: float, growth: float, level: int) -> int:
	return int(round(base * pow(growth, float(level))))


## Total cost of buying `count` levels starting at `level` (geometric sum).
static func bulk_cost(base: float, growth: float, level: int, count: int) -> int:
	if count <= 0:
		return 0
	if is_equal_approx(growth, 1.0):
		return int(round(base * float(count)))
	var first: float = base * pow(growth, float(level))
	return int(round(first * (pow(growth, float(count)) - 1.0) / (growth - 1.0)))


## How many levels `budget` buys from `level` on (for a "Buy MAX" button).
static func max_affordable(base: float, growth: float, level: int, budget: float) -> int:
	if budget <= 0.0:
		return 0
	if is_equal_approx(growth, 1.0):
		return int(floor(budget / base))
	var first: float = base * pow(growth, float(level))
	var ratio: float = budget * (growth - 1.0) / first + 1.0
	if ratio <= 1.0:
		return 0
	return int(floor(log(ratio) / log(growth)))


static func seconds_to_afford(cost: float, income_per_second: float) -> float:
	if income_per_second <= 0.0:
		return INF
	return cost / income_per_second


## Offline earnings: capped hours, reduced efficiency, rewarded as a number the
## player collects with a satisfying claim button (never silently added).
static func offline_earnings(income_per_second: float, seconds_away: float, cap_hours: float = 8.0, efficiency: float = 0.5) -> int:
	var capped: float = minf(seconds_away, cap_hours * 3600.0)
	return int(income_per_second * capped * efficiency)


## 950 -> "950", 1200 -> "1.2K", 3400000 -> "3.4M". Short, fixed meaning.
static func format_compact(value: float) -> String:
	var n: float = absf(value)
	var sign_text: String = "-" if value < 0.0 else ""
	if n < 1000.0:
		return sign_text + str(int(n))
	var suffixes: PackedStringArray = PackedStringArray(["K", "M", "B", "T", "Qa", "Qi", "Sx"])
	var scaled: float = n
	var tier: int = 0
	while scaled >= 999.995 and tier < suffixes.size():
		scaled /= 1000.0
		tier += 1
	var text: String = "%.2f" % scaled
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return sign_text + text + suffixes[tier - 1]
