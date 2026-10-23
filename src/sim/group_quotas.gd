class_name GroupQuotas
extends RefCounted
## Gruppenquoten: Validierung und deterministische Zuteilung neuer Arbeiter.


static func validate(quotas: PackedInt32Array) -> PackedStringArray:
	var errors := PackedStringArray()
	if quotas.is_empty() or quotas.size() > SimConfig.MAX_GROUPS:
		errors.append("Es sind 1 bis %d Gruppen erlaubt" % SimConfig.MAX_GROUPS)
		return errors
	var sum := 0
	for quota in quotas:
		if quota < 0 or quota > 100:
			errors.append("Jede Quote muss zwischen 0 und 100 liegen")
		sum += quota
	if sum != 100:
		errors.append("Die Summe der Quoten muss 100 ergeben (ist %d)" % sum)
	return errors


## Wählt die Gruppe mit dem größten relativen Defizit gegenüber der Zielquote.
##
## Relatives Defizit einer Gruppe g bei Gesamtzahl T: 1 − count_g / (quota_g/100 · T).
## Da T für alle Gruppen gleich ist, ist das Defizit genau dann am größten, wenn
## count_g / quota_g minimal ist. Verglichen wird per Kreuzmultiplikation (nur Ganzzahlen).
## Gleichstand: größere Quote gewinnt, danach der kleinere Gruppenindex.
## Gruppen mit Quote 0 werden nie gewählt. Gibt -1 zurück, wenn keine Gruppe Quote > 0 hat.
static func pick_group(counts: PackedInt32Array, quotas: PackedInt32Array) -> int:
	var best := -1
	for g in quotas.size():
		var quota := quotas[g]
		if quota <= 0:
			continue
		if best < 0:
			best = g
			continue
		var lhs := counts[g] * quotas[best]
		var rhs := counts[best] * quota
		if lhs < rhs or (lhs == rhs and quota > quotas[best]):
			best = g
	return best
