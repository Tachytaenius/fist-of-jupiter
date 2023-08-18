uniform vec2 canvasSize;
uniform float fadeDistance;

vec4 effect(vec4 colour, sampler2D image, vec2 textureCoords, vec2 windowCoords) {
	float fade1 = min(1.0, textureCoords.y * canvasSize.y / fadeDistance);
	float fade2 = min(1.0, (1 - textureCoords.y) * canvasSize.y / fadeDistance);
	vec4 fragmentColour = Texel(image, textureCoords);
	return vec4(
		fragmentColour.rgb,
		fragmentColour.a * min(fade1, fade2)
	);
}
