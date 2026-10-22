@tool
class_name PaintStyle
extends Resource
## Data for one paint (GDD section 9.3): Span (cyan, solid), Grip (magenta, wall paint) and Spring
## (amber, bounce pad). Saved as .tres files in resources/ and shared by the ball, blob and HUD.

## Index in the HUD order: 0 Span, 1 Grip, 2 Spring (matches RunState.Paint).
@export var kind_index: int = 0
@export var display_name: String = "Span"
@export var color: Color = Color("1FB8EA")
@export var highlight: Color = Color("51CCED")
## Seconds a blob of this paint lasts before it dissolves (GDD 9.5: 10 for Span, Grip and Spring).
@export var lifetime: float = 10.0
## Radius of a blob in meters: the paint you see and the collision you stand on are the same size (Marco asked for
## bigger splashes with bigger collisions, 2026-10-11: they were 0.8, which made a bridge too narrow to build or walk).
@export var radius: float = 1.2
## How thick a blob is (the height of its flat top above the surface it lies on).
@export var thickness: float = 0.4
## Distance a docked blob sits from its neighbor: 1.5 radii, so two blobs overlap by a quarter of their width and a
## ribbon of them is always one solid road (Spring pads use 2.6 so they never overlap).
@export var dock_distance: float = 1.8
## Shared glossy shader material of the blob dome.
@export var blob_material: Material
## Material of the flying ball.
@export var ball_material: Material
## What sits inside the blob: the coil of a Spring pad. Empty for the paints that are solid all through.
@export var accent_material: Material
