// Based on https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models

#[compute]
#version 450

const float MATH_PI = 3.14159265;

// Hash Primes To Generate Random(*pseudo*) Waves
float hash_x_prime = 10007.0;
float hash_y_prime = 30270.0;

// Layouts
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;	
layout(rgba32f, binding = 0) uniform image2D DISPLACEMENT_OUTPUT_TEXTURE;
layout(std430, binding = 1) buffer INPUTS {
    float inputs[];
};

void main() 
{
	// Inputs
	int resolution = int(inputs[0]);
	float scale = inputs[1];
	float time = inputs[2];
	vec2 position_offset = vec2(inputs[3],inputs[4]);
	int wave_count = int(inputs[5]);
	vec2 wave_wind_direction = vec2(inputs[6],inputs[7]);
	vec2 wave_direction = vec2(inputs[8],inputs[9]);
	float wave_spread = inputs[10];
	float wave_distribution = inputs[11];
	float wave_wavelength_min = inputs[12];
	float wave_wavelength_max = inputs[13];
	float wave_steepness_min = inputs[14];
	float wave_steepness_max = inputs[15];
	float wave_amplitude_min = inputs[16];
	float wave_amplitude_max = inputs[17];

	ivec2 xy = ivec2(gl_GlobalInvocationID.xy);
	vec2 uv = (vec2(gl_GlobalInvocationID.xy) / vec2(resolution,resolution)) * scale;
	uv += position_offset;

	vec2 wave_position_offset = uv;
	vec3 displacement = vec3(0,0,0);
	vec3 normal = vec3(0,0,0);

	// Do Gerstner Waves
	for(int i = 0; i < wave_count; ++i)
	{
		// Get Wave Index Fraction
		float wave_index_fraction = float(i) / float(wave_count);

		// Generate Sequence Of Random(*pseudo*) Numbers From Hash (Called In Sequence)
		hash_x_prime = (hash_x_prime) + 12345;
		hash_y_prime = (hash_y_prime) + 12345 * 3.2f;

		// Get Wave Direction From Random | Lerp With Wind Direction (Normalized)
		vec2 wave_direction = vec2(cos(hash_x_prime / 801571.0), sin(hash_y_prime / 10223.0));
		wave_direction = normalize(mix(wave_wind_direction, (wave_direction * 2.f) - 1.f, wave_spread)); // mix is lerp

		// Wave Alpha | Compute Wave Parameters
		const float wave_alpha = pow(wave_index_fraction, wave_distribution);
		const float wavelength = mix(wave_wavelength_max, wave_wavelength_min, wave_alpha); // mix is lerp
		const float steepness = mix(wave_steepness_max, wave_steepness_min, wave_alpha); // mix is lerp
		const float amplitude = mix(wave_amplitude_max, wave_amplitude_min, wave_alpha); // mix is lerp

		// Gerstner Wave
		// https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models
		float K = 2.0 * MATH_PI / wavelength;
		float wKA = amplitude * K;
		float Q = steepness / wKA;
		float wave_speed = sqrt(K * 981.f);
		float wave_position = dot(wave_position_offset, wave_direction * K) - (wave_speed * time);
		float wave_sin = sin(wave_position);
		float wave_cos = cos(wave_position);

		// Displacement
		displacement.xy += -Q * wave_sin * wave_direction * amplitude;
		displacement.z += wave_cos * amplitude;


		// This is how you would calculate normals to output to a normal map but we do not need them as there auto generated from heightmap but I put this here for full implementation
		// normal (hardcode limit (50) to ensure normal's Z component doesn't exceed a maximum value)
		// normal.xy +=wave_sin * wKA * wave_direction;
		// normal.z += wave_cos * steepness * saturate((amplitude * 50.f) / wavelength);
	}

    // This is how you would calculate normals to output to a normal map but we do not need them as there auto generated from heightmap but I put this here for full implementation
	// Normalize Our Normal (We also must flip it on z)
	// normal = normalize(float3(normal.x, normal.y, 1.f - normal.z));

	// Output
	imageStore(DISPLACEMENT_OUTPUT_TEXTURE, xy, vec4(displacement.x,displacement.y,displacement.z,1));
}