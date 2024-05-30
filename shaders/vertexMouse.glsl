varying vec2 vUv;
uniform float time;
uniform vec4 resolution;
uniform vec2 mouse;


void main() {
    vUv = uv;
    gl_Position = vec4(position, 1.0);
}
