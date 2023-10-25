const float pi = 3.1415926538;
const float tau = pi * 2.0;

uniform float time;
uniform float playBackgroundParticleAnimationFrequency;
uniform float playBackgroundParticleTimeOffsetPerDistance;
uniform float playBackgroundParticleAnimationAmplitude;

vec4 position(mat4 loveTransform, vec4 homogenVertexPosition) {
	float yOffset = sin(
		time * playBackgroundParticleAnimationFrequency * tau
		+ (homogenVertexPosition.x + homogenVertexPosition.y) * playBackgroundParticleTimeOffsetPerDistance
	) * playBackgroundParticleAnimationAmplitude;
	vec4 wobbledVertexPosition = homogenVertexPosition;
	wobbledVertexPosition.y += yOffset;
	return loveTransform * wobbledVertexPosition;
}
