uniform vec2 offset;
uniform sampler2D imageToDraw;

vec4 effect(vec4 colour, sampler2D image, vec2 textureCoords, vec2 windowCoords) {
	return colour * Texel(imageToDraw, (windowCoords + offset) / love_ScreenSize.xy);
}
