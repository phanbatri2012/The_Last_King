class_name FormationSlotCalculator
extends RefCounted


static func ring_slot(slot_index: int, formation: Dictionary) -> Vector2:
	var safe_index := maxi(slot_index, 0)
	var slots_per_ring := maxi(int(formation.get("slots_per_ring", 1)), 1)
	var ring_index := safe_index / slots_per_ring
	var index_in_ring := safe_index % slots_per_ring
	var base_radius := maxf(float(formation.get("base_radius", 1.0)), 1.0)
	var ring_spacing := maxf(float(formation.get("ring_spacing", 0.0)), 0.0)
	var radius := base_radius + float(ring_index) * ring_spacing
	var angle_offset := deg_to_rad(float(formation.get("angle_offset_degrees", -90.0)))
	var angle := angle_offset + TAU * float(index_in_ring) / float(slots_per_ring)
	return Vector2.from_angle(angle) * radius
