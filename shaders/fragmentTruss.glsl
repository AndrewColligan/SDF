precision highp float;

varying vec2 vUv;
uniform float time;
uniform float progress;
uniform vec4 resolution;

uniform float u_rotationX;
uniform float u_rotationY;
uniform vec3 cameraAdjPos;

uniform sampler2D matcap;

struct Capsule {
    vec3 a;
    vec3 b;
    float radius;
    vec3 color;
};


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


float capsuleSDF(vec3 p, Capsule capsule)
{
  vec3 pa = p - capsule.a, ba = capsule.b - capsule.a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - capsule.radius;
}


vec2 getMatcap(vec3 ray, vec3 normal) {
    vec3 reflected = reflect(ray, normal);
    float m = 2.8284271247461903 * sqrt(reflected.z+1.0);
    return reflected.xy / m + 0.5;
}


float unionSDF(float d1, float d2, float blend) {
    return smin(d1, d2, blend);
}


float sceneSDF(vec3 p, out vec3 color) {
    float radius = 0.05;
    float blend = 0.005;

    Capsule capsule1 = Capsule(vec3(-1.0, 0.0, 0.0), vec3(0.0, 0.0, 0.0), radius, vec3(1.0, 0.0, 0.0)); // Red
    Capsule capsule2 = Capsule(vec3(0.0, 0.0, 0.0), vec3(-0.5, 1.0, 0.0), radius, vec3(1.0, 0.0, 0.0)); // Red
    Capsule capsule3 = Capsule(vec3(-0.5, 1.0, 0.0), vec3(-1.0, 0.0, 0.0), radius, vec3(0.0, 0.0, 1.0)); // Blue
    Capsule capsule4 = Capsule(vec3(-0.5, 1.0, 0.0), vec3(0.5, 1.0, 0.0), radius, vec3(0.0, 0.0, 1.0)); // Blue
    Capsule capsule5 = Capsule(vec3(0.5, 1.0, 0.0), vec3(0.0, 0.0, 0.0), radius, vec3(1.0, 0.0, 0.0)); // Red
    Capsule capsule6 = Capsule(vec3(0.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0), radius, vec3(1.0, 0.0, 0.0)); // Red
    Capsule capsule7 = Capsule(vec3(1.0, 0.0, 0.0), vec3(0.5, 1.0, 0.0), radius, vec3(0.0, 0.0, 1.0)); // Blue

    p = rotationX(u_rotationX) * p;
    p = rotationY(u_rotationY) * p;

    // Union of capsules
    float d1 = capsuleSDF(p, capsule1);
    float d2 = capsuleSDF(p, capsule2);
    float d3 = capsuleSDF(p, capsule3);
    float d4 = capsuleSDF(p, capsule4);
    float d5 = capsuleSDF(p, capsule5);
    float d6 = capsuleSDF(p, capsule6);
    float d7 = capsuleSDF(p, capsule7);

    float dUnion = unionSDF(d1, d2, blend);
    dUnion = unionSDF(dUnion, d3, blend);
    dUnion = unionSDF(dUnion, d4, blend);
    dUnion = unionSDF(dUnion, d5, blend);
    dUnion = unionSDF(dUnion, d6, blend);
    dUnion = unionSDF(dUnion, d7, blend);

    if (dUnion == d1) {
        color = capsule1.color;
    }
    else if (dUnion == d2) {
        color = capsule2.color;
    }
    else if (dUnion == d3) {
        color = capsule3.color;
    }
    else if (dUnion == d4) {
        color = capsule4.color;
    }
    else if (dUnion == d5) {
        color = capsule5.color;
    }
    else if (dUnion == d6) {
        color = capsule6.color;
    }
    else if (dUnion == d7) {
        color = capsule7.color;
    }
    else {
        color = vec3(0.824, 0.824, 0.824);
    }

    return dUnion;
}

vec3 getNormal(vec3 p) {
    float d = 0.001;
    vec3 dummyColor; // Dummy color variable, not used in normal calculation
    return normalize(vec3(
        sceneSDF(p + vec3(d, 0.0, 0.0), dummyColor) - sceneSDF(p - vec3(d, 0.0, 0.0), dummyColor),
        sceneSDF(p + vec3(0.0, d, 0.0), dummyColor) - sceneSDF(p - vec3(0.0, d, 0.0), dummyColor),
        sceneSDF(p + vec3(0.0, 0.0, d), dummyColor) - sceneSDF(p - vec3(0.0, 0.0, d), dummyColor)
    ));
}

float rayMarch(vec3 ro, vec3 rd, out vec3 hitColor) {
    float t = 0.0;
    for (int i = 0; i < 100; i++) {
        vec3 p = ro + rd * t;
        float d = sceneSDF(p, hitColor);
        if (d < 0.001) return t;
        t += d;
        if (t > 100.0) break;
    }
    return -1.0;
}

void main() {
    vec2 newUV = (vUv - vec2(0.5)) * resolution.zw + vec2(0.5);
    vec3 ro = vec3(0.0, 0.0, 5.0);
    ro = ro + cameraAdjPos;
    vec3 rd = normalize(vec3((vUv - vec2(0.5)) * resolution.zw, -1));

    vec3 hitColor;
    float t = rayMarch(ro, rd, hitColor);
    if (t > 0.0) {
        vec3 p = ro + rd * t;
        vec3 normal = getNormal(p);
        vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
        float diff = max(dot(normal, lightDir), 0.0);

        vec2 matcapUV = getMatcap(rd, normal);
        vec3 colorMat = texture2D(matcap, matcapUV).rgb;

        gl_FragColor = vec4(hitColor * diff * colorMat, 0.8);
    } else {
        gl_FragColor = vec4(1.0);
    }
}
