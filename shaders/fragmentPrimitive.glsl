precision highp float;

varying vec2 vUv;
uniform float time;
uniform vec4 resolution;

uniform float u_rotationX;
uniform float u_rotationY;
uniform vec3 cameraAdjPos;

uniform int dropdownSelect;


// Function to rotate a point around the X axis
mat3 rotationX(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat3(
        1.0, 0.0, 0.0,
        0.0, c, -s,
        0.0, s, c
    );
}

// Function to rotate a point around the Y axis
mat3 rotationY(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat3(
        c, 0.0, s,
        0.0, 1.0, 0.0,
        -s, 0.0, c
    );
}

// cubic polynomial
float smin( float a, float b, float k )
{
    k *= 6.0;
    float h = max( k-abs(a-b), 0.0 )/k;
    return min(a,b) - h*h*h*k*(1.0/6.0);
}


float sphereSDF(vec3 p, float r) {
    return length(p) - r;
}


float boxSDF( vec3 p, vec3 b ){
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}


float gyroidSDF(vec3 p, float size, float thickness, float scale) {
	float surfaceSide = dot(scale * sin(p), scale * cos(p.yzx));
	float d = abs(surfaceSide) - thickness;
	vec3 a = abs(p);
	return max(d, max(a.x, max(a.y, a.z)) - size);
}


float schwarzPSDF(vec3 p, float size, float thickness, float scale) {
	float surfaceSide = scale * cos(p.x) + scale * cos(p.y) + scale * cos(p.z);
	float d = abs(surfaceSide) - thickness;
	vec3 a = abs(p);
	return max(d, max(a.x, max(a.y, a.z)) - size);
}


float torusSDF(vec3 p, vec2 t)
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}


float sdf(vec3 p) {
    if (dropdownSelect == 0 ^^ dropdownSelect == 4) {
        p += vec3(0.0, 0.0, 25.0);
    }

    p = rotationX(u_rotationX) * p;
    p = rotationY(u_rotationY) * p;

    float dist = 0.0;

    if (dropdownSelect == 0) {
        dist = gyroidSDF(p, 4.0, 0.075, 0.75);
    }
    else if (dropdownSelect == 1) {
        dist = sphereSDF(p, 2.0);
    }
    else if (dropdownSelect == 2) {
        dist = boxSDF(p, vec3(1.5));
    }
    else if (dropdownSelect == 3) {
        dist = torusSDF(p, vec2(2.0, 0.5));
    }
    else if (dropdownSelect == 4) {
        dist = schwarzPSDF(p, 4.0, 0.075, 0.75);
    }
    else {
        dist = sphereSDF(p, 2.0);
    }

    return dist;
}

vec3 getNormal(vec3 p) {
    float d = 0.001;
    return normalize(vec3(
        sdf(p + vec3(d, 0.0, 0.0)) - sdf(p - vec3(d, 0.0, 0.0)),
        sdf(p + vec3(0.0, d, 0.0)) - sdf(p - vec3(0.0, d, 0.0)),
        sdf(p + vec3(0.0, 0.0, d)) - sdf(p - vec3(0.0, 0.0, d))
    ));
}

float rayMarch(vec3 rayOrigin, vec3 ray) {
    float t = 0.0;
    for (int i = 0; i < 100; i++) {
        vec3 p = rayOrigin + ray * t;
        float d = sdf(p);
        if (d < 0.001) return t;
        t += d;
        if (t > 100.0) break;
    }
    return -1.0;
}

void main() {

    vec2 newUV = (vUv - vec2(0.5)) * resolution.zw + vec2(0.5);
    vec3 cameraPos = vec3(0.0, 0.0, resolution.x / 70.0);
    cameraPos = cameraPos + cameraAdjPos;
    vec3 ray = normalize(vec3((vUv - vec2(0.5)) * resolution.zw, -1));

    vec3 color = vec3(1.0);

    float t = rayMarch(cameraPos, ray);
    if (t > 0.0) {
        vec3 p = cameraPos + ray * t;
        vec3 normal = getNormal(p);

        vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
        float diff = max(dot(normal, lightDir), 0.0);
        color = vec3(diff);

        gl_FragColor = vec4(color, 1.0);
    } else {
        gl_FragColor = vec4(1.0);
    }
}
