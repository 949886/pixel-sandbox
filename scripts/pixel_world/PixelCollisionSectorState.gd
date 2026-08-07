class_name PixelCollisionSectorState
extends RefCounted

## Runtime-only state for one independently replaceable terrain collision sector.
var coord: Vector2i = Vector2i.ZERO
var active_body: RID
var staging_body: RID
var active_shape_rids: Array[RID] = []
var staging_shape_rids: Array[RID] = []
var active_rects: PackedInt32Array = PackedInt32Array()
var staging_rects: PackedInt32Array = PackedInt32Array()
var staging_cursor: int = 0
var active_revision: int = -1
var building_revision: int = -1
var queued_revision: int = -1
var initial_committed: bool = false
var build_in_progress: bool = false
var commit_pending: bool = false
var dirty: bool = false
var snapshot_prepared: bool = false
