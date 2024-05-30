varying vec2 vUv;
uniform float time;
uniform vec4 resolution;

uniform float u_rotationX;
uniform float u_rotationY;
uniform vec3 cameraAdjPos;

uniform int dropdownSelect;


void main() {
    vUv = uv;
    gl_Position = vec4(position, 1.0);
}
