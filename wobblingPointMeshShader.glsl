const float pi = 3.1415926538;
const float tau = pi * 2.0;

uniform float time;
uniform float playBackgroundParticleAnimationFrequency;
uniform float playBackgroundParticleTimeOffsetPerDistance;
uniform float playBackgroundParticleAnimationAmplitude;

vec4 position(mat4 loveTransform, vec4 homogenVertexPosition) {
	float sineInput = time * playBackgroundParticleAnimationFrequency * tau
		+ (homogenVertexPosition.x + homogenVertexPosition.y) * playBackgroundParticleTimeOffsetPerDistance;
	sineInput = mod(sineInput, tau); // Fix graphical bug on some systems
	float yOffset = sin(sineInput) * playBackgroundParticleAnimationAmplitude;
	vec4 wobbledVertexPosition = homogenVertexPosition;
	wobbledVertexPosition.y += yOffset;
	return loveTransform * wobbledVertexPosition;
}
