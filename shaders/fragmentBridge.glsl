precision highp float;

varying vec2 vUv;
uniform float time;
uniform float progress;
uniform vec4 resolution;

uniform float u_rotationX;
uniform float u_rotationY;
uniform vec3 cameraAdjPos;

uniform sampler2D matcap;

float PI = 3.141592653589793238;


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

vec3 opCheapBend(vec3 p)
{
    float k = cos(time / 2.0) / 6.0; // or some other amount
    float c = cos(k*p.x);
    float s = sin(k*p.x);
    mat2  m = mat2(c,-s,s,c);
    vec3  q = vec3(m * p.xy, p.z);
    return q;
}


vec2 getMatcap(vec3 ray, vec3 normal) {
    vec3 reflected = reflect(ray, normal);
    float m = 2.8284271247461903 * sqrt(reflected.z+1.0);
    return reflected.xy / m + 0.5;
}


float capsuleSDF(vec3 p, vec3 a, vec3 b, float r)
{
  vec3 pa = p - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}


float boxSDF(vec3 p, vec3 b){
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

vec3 translate(vec3 p, vec3 offset) {
    return p - offset;
}


float sdf(vec3 p) {
    float radius = 0.05;
    float blend = 0.005;
    //float blend = 0.1;
    float bridgeWidth = 0.5;

    //p = opCheapBend(p);

    p = rotationX(u_rotationX) * p;
    p = rotationY(u_rotationY) * p;

    float capsule = capsuleSDF(p, vec3(-1.0, 0.0, 0.0), vec3(0.0, 0.0, 0.0), radius);
    float dist = smin(capsule, capsuleSDF(p, vec3(0.0, 0.0, 0.0), vec3(-0.5, 1.0, 0.0), radius), blend);
    dist = smin(dist, capsuleSDF(p, vec3(-0.5, 1.0, 0.0), vec3(-1.0, 0.0, 0.0), radius), blend);
    dist = smin(dist, capsuleSDF(p, vec3(-0.5, 1.0, 0.0), vec3(0.5, 1.0, 0.0), radius), blend);
    dist = smin(dist, capsuleSDF(p, vec3(0.5, 1.0, 0.0), vec3(0.0, 0.0, 0.0), radius), blend);
    dist = smin(dist, capsuleSDF(p, vec3(0.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0), radius), blend);
    dist = smin(dist, capsuleSDF(p, vec3(1.0, 0.0, 0.0), vec3(0.5, 1.0, 0.0), radius), blend);

    vec3 p1 = p - vec3(0.0, 0.0, 1.0);
    dist = smin(dist, capsuleSDF(p1, vec3(-1.0, 0.0, 0.0), vec3(0.0, 0.0, 0.0), radius), blend);
    dist = smin(dist, capsuleSDF(p1, vec3(0.0, 0.0, 0.0), vec3(-0.5, 1.0, 0.0), radius), blend);
    dist = smin(dist, capsuleSDF(p1, vec3(-0.5, 1.0, 0.0), vec3(-1.0, 0.0, 0.0), radius), blend);
    dist = smin(dist, capsuleSDF(p1, vec3(-0.5, 1.0, 0.0), vec3(0.5, 1.0, 0.0), radius), blend);
    dist = smin(dist, capsuleSDF(p1, vec3(0.5, 1.0, 0.0), vec3(0.0, 0.0, 0.0), radius), blend);
    dist = smin(dist, capsuleSDF(p1, vec3(0.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0), radius), blend);
    dist = smin(dist, capsuleSDF(p1, vec3(1.0, 0.0, 0.0), vec3(0.5, 1.0, 0.0), radius), blend);

    float box = boxSDF(p - vec3(0.0, 0.0, (bridgeWidth / 2.0) + 0.22), vec3(1.0, radius / 2.0, bridgeWidth));
    dist = smin(dist, box, blend);

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
    vec3 cameraPos = vec3(0.0, 0.0, 5.0);
    cameraPos = cameraPos + cameraAdjPos;
    vec3 ray = normalize(vec3((vUv - vec2(0.5)) * resolution.zw, -1));
    vec3 color = vec3(1.0);

    float t = rayMarch(cameraPos, ray);
    if (t > 0.0) {
        vec3 p = cameraPos + ray * t;
        vec3 normal = getNormal(p);
        vec2 matcapUV = getMatcap(ray, normal);
        color = texture2D(matcap, matcapUV).rgb;

        gl_FragColor = vec4(color, 1.0);
    } else {
        gl_FragColor = vec4(1.0);
    }
}
