#version 460 core

#include <flutter/runtime_effect.glsl>

// Uniform declaration order fixes the Dart-side indices:
//   setFloat(0) = uResolution.x   setFloat(1) = uResolution.y
//   setFloat(2) = uOpacity        setFloat(3) = uEdgeSoftness
//   setImageSampler(0) = uDensity
uniform vec2 uResolution;
uniform float uOpacity;
uniform float uEdgeSoftness;
uniform sampler2D uDensity;

out vec4 fragColor;

// 6-stop palette matching the previous _defaultGradient.
vec3 palette(float t) {
  vec3 c0 = vec3(0.231, 0.510, 0.965); // #3B82F6 blue
  vec3 c1 = vec3(0.024, 0.714, 0.831); // #06B6D4 cyan
  vec3 c2 = vec3(0.133, 0.773, 0.369); // #22C55E green
  vec3 c3 = vec3(0.918, 0.702, 0.031); // #EAB308 yellow
  vec3 c4 = vec3(0.976, 0.451, 0.086); // #F97316 orange
  vec3 c5 = vec3(0.937, 0.267, 0.267); // #EF4444 red
  float x = clamp(t, 0.0, 1.0) * 5.0;
  vec3 c = c0;
  c = mix(c, c1, clamp(x - 0.0, 0.0, 1.0));
  c = mix(c, c2, clamp(x - 1.0, 0.0, 1.0));
  c = mix(c, c3, clamp(x - 2.0, 0.0, 1.0));
  c = mix(c, c4, clamp(x - 3.0, 0.0, 1.0));
  c = mix(c, c5, clamp(x - 4.0, 0.0, 1.0));
  return c;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  float density = texture(uDensity, uv).r;
  // Soft edge: alpha ramps from 0 to full as density crosses uEdgeSoftness.
  float a = uOpacity * smoothstep(0.0, uEdgeSoftness, density);
  vec3 rgb = palette(density);
  // Flutter fragment shaders output premultiplied alpha.
  fragColor = vec4(rgb * a, a);
}
