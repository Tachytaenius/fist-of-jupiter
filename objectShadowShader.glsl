uniform sampler2D MainTex;

void effect() {
	vec4 fragmentColour = Texel(MainTex, VaryingTexCoord.xy);
	love_Canvases[0] = VaryingColor * fragmentColour;
	love_Canvases[1] = vec4(vec3(0.0), VaryingColor.a * fragmentColour.a);
}
