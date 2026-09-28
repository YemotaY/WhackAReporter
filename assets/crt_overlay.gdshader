shader_type canvas_item;
// Retro CRT overlay: scanlines, vignette, subtle RGB shift flicker.

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.18;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec2 uv = UV;
	// Scanlines
	float line = sin(uv.y * 640.0 * 3.14159) * 0.5 + 0.5;
	float scan = 1.0 - scanline_strength * line;
	// Vignette
	vec2 d = uv - 0.5;
	float vig = 1.0 - vignette_strength * dot(d, d) * 2.2;
	// Subtle flicker
	float flick = 1.0 - 0.02 * sin(TIME * 60.0);
	float dark = 1.0 - scan * vig * flick;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(dark, 0.0, 0.6));
}
