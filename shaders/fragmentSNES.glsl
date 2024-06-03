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


struct Capsule {
    vec3 a;
    vec3 b;
    float radius;
    vec3 color;
};


mat4 rotationMatrix(vec3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;

    return mat4(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
                0.0,                                0.0,                                0.0,                                1.0);
}

vec3 rotate(vec3 v, vec3 axis, float angle) {
	mat4 m = rotationMatrix(axis, angle);
	return (m * vec4(v, 1.0)).xyz;
}

vec2 rotate2D(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, s, -s, c);
	return m * v;
}


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


float degsToRadians(float angle) {
    return angle * PI / 180.0;
}


float opSmoothUnion( float d1, float d2, float k )
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}


float opSmoothSubtraction( float d1, float d2, float k )
{
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h);
}


float opSubtraction( float d1, float d2 )
{
    return max(-d1,d2);
}


// cubic polynomial
float sminCubic( float a, float b, float k )
{
    k *= 6.0;
    float h = max( k-abs(a-b), 0.0 )/k;
    return min(a,b) - h*h*h*k*(1.0/6.0);
}

// Ref: https://www.shadertoy.com/view/7dfGD2
float bezierSDF(in vec3 p, in vec3 v1, in vec3 v2, in vec3 v3) {
    vec3 c1 = p - v1;
    vec3 c2 = 2.0 * v2 - v3 - v1;
    vec3 c3 = v1 - v2;

    float t3 = dot(c2, c2);
    float t2 = dot(c3, c2) * 3.0 / t3;
    float t1 = (dot(c1, c2) + 2.0 * dot(c3, c3)) / t3;
    float t0 = dot(c1, c3) / t3;

    float t22 = t2 * t2;
    vec2 pq = vec2(t1 - t22 / 3.0, t22 * t2 / 13.5 - t2 * t1 / 3.0 + t0);
    float ppp = pq.x * pq.x * pq.x, qq = pq.y * pq.y;

    float p2 = abs(pq.x);
    float r1 = 1.5 / pq.x * pq.y;

    if (qq * 0.25 + ppp / 27.0 > 0.0) {
        float r2 = r1 * sqrt(3.0 / p2), root;
        if (pq.x < 0.0) root = sign(pq.y) * cosh(acosh(r2 * -sign(pq.y)) / 3.0);
        else root = sinh(asinh(r2) / 3.0);
        root = clamp(-2.0 * sqrt(p2 / 3.0) * root - t2 / 3.0, 0.0, 1.0);
        return length(p - mix(mix(v1, v2, root), mix(v2, v3, root), root));
    }

    else {
        float ac = acos(r1 * sqrt(-3.0 / pq.x)) / 3.0;
        vec2 roots = clamp(2.0 * sqrt(-pq.x / 3.0) * cos(vec2(ac, ac - 4.18879020479)) - t2 / 3.0, 0.0, 1.0);
        vec3 p1 = p - mix(mix(v1, v2, roots.x), mix(v2, v3, roots.x), roots.x);
        vec3 p2 = p - mix(mix(v1, v2, roots.y), mix(v2, v3, roots.y), roots.y);
        return sqrt(min(dot(p1, p1), dot(p2, p2)));
    }
}

float equTriangleSDF( in vec2 p, in float r )
{
    const float k = sqrt(3.0);
    p.x = abs(p.x) - r;
    p.y = p.y + r/k;
    if( p.x+k*p.y>0.0 ) p = vec2(p.x-k*p.y,-k*p.x-p.y)/2.0;
    p.x -= clamp( p.x, -2.0*r, 0.0 );
    return -length(p)*sign(p.y);
}


float sphereSDF( vec3 p, float s )
{
  return length(p)-s;
}


float capsuleSDF( vec3 p, vec3 a, vec3 b, float r )
{
  vec3 pa = p - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}


float boxSDF(vec3 p, vec3 b) {
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}


float cappedCylinderSDF(vec3 p, float h, float r)
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(r,h);
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}


vec2 getMatcap(vec3 ray, vec3 normal) {
    vec3 reflected = reflect(ray, normal);
    float m = 2.8284271247461903 * sqrt(reflected.z+1.0);
    return reflected.xy / m + 0.5;
}


float unionSDF(float d1, float d2, float blend) {
    return sminCubic(d1, d2, blend);
}


float sceneSDF(vec3 p, out vec3 color) {
    float radius = 0.05;
    float blend = 0.005;
    float controller_depth = 0.8;

    p = rotationX(u_rotationX) * p;
    p = rotationY(u_rotationY) * p;

    float d_controller = boxSDF(p, vec3(5.0, 3.5, controller_depth));
    vec3 p_pad_left = rotate(p, vec3(1.0, 0.0, 0.0), degsToRadians(90.0));
    p_pad_left = p_pad_left - vec3(-5.0, 0.0, 0.5);
    float d_pad_left = cappedCylinderSDF(p_pad_left, controller_depth, 4.0);
    d_controller = min(d_controller, d_pad_left);

    vec3 p_pad_right = rotate(p, vec3(1.0, 0.0, 0.0), degsToRadians(90.0));
    p_pad_right = p_pad_right - vec3(5.0, 0.0, 0.5);
    float d_pad_right = cappedCylinderSDF(p_pad_right, controller_depth, 4.0);
    d_controller = min(d_controller, d_pad_right);

    p_pad_left = p_pad_left - vec3(0.0, 1.75, 0.0);
    float d_pad_left_cut = cappedCylinderSDF(p_pad_left, 1.0, 2.0);
    d_controller = opSmoothSubtraction(d_pad_left_cut, d_controller, 0.01);

    // Round shape
    d_controller = d_controller - 0.1;

    // L Z buttons
    // L button
    vec3 p_l_button = p - vec3(-5.5, 1.6, 0.0);
    p_l_button = rotate(p_l_button, vec3(1.0, 0.0, 0.0), degsToRadians(90.0));

    float d_l_button = cappedCylinderSDF(p_l_button, 0.4, 2.0);

    p_l_button = p - vec3(-4.45, 2.6, 0.0);
    d_l_button = sminCubic(d_l_button, boxSDF(p_l_button, vec3(1.0, 1.0, 0.4)), 0.0001);
    d_l_button = d_l_button - 0.1;
    d_controller = min(d_controller, d_l_button);

    // Z button
    vec3 p_z_button = p - vec3(5.5, 1.6, 0.0);
    p_z_button = rotate(p_z_button, vec3(1.0, 0.0, 0.0), degsToRadians(90.0));

    float d_z_button = cappedCylinderSDF(p_z_button, 0.4, 2.0);

    p_z_button = p - vec3(4.45, 2.6, 0.0);
    d_z_button = sminCubic(d_z_button, boxSDF(p_z_button, vec3(1.0, 1.0, 0.4)), 0.0001);
    d_z_button = d_z_button - 0.1;
    d_controller = min(d_controller, d_z_button);

    p_pad_right = p_pad_right - vec3(0.0, 1.5, 0.0);
    float d_pad_right_cut = cappedCylinderSDF(p_pad_right, 1.0, 3.5);
    d_controller = opSubtraction(d_pad_right_cut, d_controller);

    // Insert right pad
    p_pad_right = p_pad_right + vec3(0.0, 0.8, 0.0);
    float d_pad_right_insert = cappedCylinderSDF(p_pad_right, 0.2, 3.45);
    d_controller = min(d_pad_right_insert, d_controller);

    float start_button = capsuleSDF(p, vec3(-2.0, -2.0, 0.9), vec3(-1.2, -1.4, 0.9), 0.2);
    d_controller = min(d_controller, start_button);

    float select_button = capsuleSDF(p, vec3(0.0, -2.0, 0.9), vec3(0.8, -1.4, 0.9), 0.2);
    d_controller = min(d_controller, select_button);

    // D Pad
    /*
    vec3 p_d_pad_cut = p - vec3(-5.0, -0.5, 0.5);
    float d_pad_cut = boxSDF(p_d_pad_cut, vec3(0.38, 1.43, 1.0));
    d_pad_cut = min(d_pad_cut, boxSDF(p_d_pad_cut, vec3(1.43, 0.38, 1.0)));
    d_pad_cut = d_pad_cut - 0.2;
    d_controller = opSubtraction(d_pad_cut, d_controller);
    */

    vec3 p_d_pad = p - vec3(-5.0, -0.5, 1.0);
    float d_pad = boxSDF(p_d_pad, vec3(0.35, 1.4, 0.2));
    d_pad = min(d_pad, boxSDF(p_d_pad, vec3(1.4, 0.35, 0.2)));
    d_pad = d_pad - 0.2;

    float indentBlend = 0.1;
    float indentDepth = 0.3;
    float inlayDepth = 0.4;
    float inlayRadius = 0.85;

    // Middle circle indent
    vec3 p_indent = p - vec3(-5.0, -0.5, 1.65);
    float d_indent = sphereSDF(p_indent, indentDepth);
    d_pad = opSmoothSubtraction(d_indent, d_pad, indentBlend);

    // Right arrow indent
    p_indent = p - vec3(-4.0, -0.5, 1.65);
    p_indent.xy = rotate2D(p_indent.xy, degsToRadians(90.0));
    float d_tri = equTriangleSDF(p_indent.xy, 0.25);
    vec2 w = vec2(d_tri, abs(p_indent.z) - indentDepth);
    d_tri = min(max(w.x,w.y),0.0) + length(max(w,0.0));
    d_pad = opSmoothSubtraction(d_tri, d_pad, indentBlend);

    // Left arrow indent
    p_indent = p - vec3(-6.0, -0.5, 1.65);
    p_indent.xy = rotate2D(p_indent.xy, degsToRadians(270.0));
    d_tri = equTriangleSDF(p_indent.xy, 0.25);
    w = vec2(d_tri, abs(p_indent.z) - indentDepth);
    d_tri = min(max(w.x,w.y),0.0) + length(max(w,0.0));
    d_pad = opSmoothSubtraction(d_tri, d_pad, indentBlend);

    // Down arrow indent
    p_indent = p - vec3(-5.0, -1.5, 1.65);
    p_indent.xy = rotate2D(p_indent.xy, degsToRadians(180.0));
    d_tri = equTriangleSDF(p_indent.xy, 0.25);
    w = vec2(d_tri, abs(p_indent.z) - indentDepth);
    d_tri = min(max(w.x,w.y),0.0) + length(max(w,0.0));
    d_pad = opSmoothSubtraction(d_tri, d_pad, indentBlend);

    // Up arrow indent
    p_indent = p - vec3(-5.0, 0.5, 1.65);
    d_tri = equTriangleSDF(p_indent.xy, 0.25);
    w = vec2(d_tri, abs(p_indent.z) - indentDepth);
    d_tri = min(max(w.x,w.y),0.0) + length(max(w,0.0));
    d_pad = opSmoothSubtraction(d_tri, d_pad, indentBlend);

    d_controller = min(d_controller, d_pad);

    // Right buttons
    // A B mid inlay
    vec3 p_inlay = p - (vec3(5.0, -2.0, 0.501) + vec3(7.0, -0.5, 0.501)) / 2.0;
    p_inlay = rotate(p_inlay, vec3(0.0, 0.0, 1.0), degsToRadians(-53.0));
    float d_inlay = boxSDF(p_inlay, vec3(inlayRadius, 1.15, inlayDepth));

    // B button
    vec3 p_button_b = p - vec3(5.0, -2.0, 0.501);
    p_button_b = rotate(p_button_b, vec3(1.0, 0.0, 0.0), degsToRadians(90.0));
    float d_button_b = cappedCylinderSDF(p_button_b, 0.5, 0.5);
    d_button_b = d_button_b - 0.2;
    d_controller = min(d_controller, d_button_b);

    d_inlay = min(d_inlay, cappedCylinderSDF(p_button_b, inlayDepth, inlayRadius));

    // A button
    vec3 p_button_a = p - vec3(7.0, -0.5, 0.501);
    p_button_a = rotate(p_button_a, vec3(1.0, 0.0, 0.0), degsToRadians(90.0));
    float d_button_a = cappedCylinderSDF(p_button_a, 0.5, 0.5);
    d_button_a = d_button_a - 0.2;
    d_controller = min(d_controller, d_button_a);

    d_inlay = min(d_inlay, cappedCylinderSDF(p_button_a, inlayDepth, inlayRadius));
    d_controller = min(d_controller, d_inlay);

    // X Y mid inlay
    p_inlay = p - (vec3(5.0, 1.0, 0.501) + vec3(3.0, -0.5, 0.501)) / 2.0;
    p_inlay = rotate(p_inlay, vec3(0.0, 0.0, 1.0), degsToRadians(-53.0));
    d_inlay = boxSDF(p_inlay, vec3(inlayRadius, 1.15, inlayDepth));

    // X button
    vec3 p_button_x = p - vec3(5.0, 1.0, 0.501);
    p_button_x = rotate(p_button_x, vec3(1.0, 0.0, 0.0), degsToRadians(90.0));
    float d_button_x = cappedCylinderSDF(p_button_x, 0.5, 0.5);
    d_button_x = d_button_x - 0.2;
    d_controller = min(d_controller, d_button_x);

    d_inlay = min(d_inlay, cappedCylinderSDF(p_button_x, inlayDepth, inlayRadius));
    d_controller = min(d_controller, d_inlay);

    // Y button
    vec3 p_button_y = p - vec3(3.0, -0.5, 0.5);
    p_button_y = rotate(p_button_y, vec3(1.0, 0.0, 0.0), degsToRadians(90.0));
    float d_button_y = cappedCylinderSDF(p_button_y, 0.5, 0.5);
    d_button_y = d_button_y - 0.2;
    d_controller = min(d_controller, d_button_y);

    d_inlay = min(d_inlay, cappedCylinderSDF(p_button_y, inlayDepth, inlayRadius));
    d_controller = min(d_controller, d_inlay);

    // Cable
    vec3 a = vec3(1.0, 1.0, 0.0);
    vec3 b = vec3(3.0, 5.0, 0.0);
    vec3 c = vec3(-2.0, 7.0, 0.0);
    vec3 p_cable = p - vec3(-1.0, 2.5, 0.0);
    float d_cable = bezierSDF(p_cable, a, b, c) - 0.2;
    d_controller = min(d_controller, d_cable);

    if (d_controller == start_button) {
        color = vec3(57.0/256.0, 57.0/256.0, 57.0/256.0);
    }
    else if (d_controller == select_button) {
        color = vec3(57.0/256.0, 57.0/256.0, 57.0/256.0);
    }
    else if (d_controller == d_pad_right_insert) {
        color = vec3(105.0/256.0, 105.0/256.0, 105.0/256.0);
    }
    else if (d_controller == d_pad) {
        color = vec3(57.0/256.0, 57.0/256.0, 57.0/256.0);
    }
    else if (d_controller == d_button_b) {
        color = vec3(224.0/256.0, 100.0/256.0, 255.0/256.0);
    }
    else if (d_controller == d_button_a) {
        color = vec3(224.0/256.0, 100.0/256.0, 255.0/256.0);
    }
    else if (d_controller == d_button_x) {
        color = vec3(215.0/256.0, 187.0/256.0, 222.0/256.0);
    }
    else if (d_controller == d_button_y) {
        color = vec3(215.0/256.0, 187.0/256.0, 222.0/256.0);
    }
    else if (d_controller == d_cable) {
        color = vec3(57.0/256.0, 57.0/256.0, 57.0/256.0);
    }
    else if (d_controller == d_l_button) {
        color = vec3(105.0/256.0, 105.0/256.0, 105.0/256.0);
    }
    else if (d_controller == d_z_button) {
        color = vec3(105.0/256.0, 105.0/256.0, 105.0/256.0);
    }
    else {
        color = vec3(1.0, 1.0, 1.0);
    }

    return d_controller;
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
    vec3 ro = vec3(0.0, 0.0, 30.0);
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

        //gl_FragColor = vec4(hitColor * diff * colorMat, 1.0);
        gl_FragColor = vec4(hitColor * diff, 1.0);
    } else {
        gl_FragColor = vec4(1.0);
    }
}
