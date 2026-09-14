// Node/edge plexus background.
// Points live one-per-grid-cell; edges are lines drawn between nearby points
// (technique after eclmist's "Plexus" shader). Nodes are drawn as soft glows.
// Qt ShaderEffect fragment shader (GLSL ES 1.00 / desktop GLSL 120 compatible).
//
// NOTE: Qt ShaderEffect blends premultiplied alpha, so the final colour must be
// rgb * alpha.

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#endif

varying vec2 qt_TexCoord0;

uniform float qt_Opacity;
uniform float u_time;
uniform float u_aspect;
uniform float u_scale;
uniform float u_speed;
uniform float u_alpha;
uniform float u_lineWidth;
uniform vec4 u_nodeColor;
uniform vec4 u_edgeColor;

float hash21(vec2 p) {
    p = fract(p * vec2(223.64, 823.12));
    p += dot(p, p + 23.14);
    return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
    float x = hash21(p);
    return vec2(x, hash21(p + x));
}

// Position of the point belonging to cell `id`, jittered around `off`.
vec2 pointAt(vec2 id, vec2 off) {
    return off + sin(hash22(id + off) * 6.2831853 * u_speed + u_time * u_speed) * 0.42;
}

float distLine(vec2 p, vec2 a, vec2 b) {
    vec2 ap = p - a;
    vec2 ab = b - a;
    float h = clamp(dot(ap, ab) / max(dot(ab, ab), 1e-5), 0.0, 1.0);
    return length(ap - ab * h);
}

// Segment glow, faded out when the two endpoints are far apart.
float lineIntensity(vec2 p, vec2 a, vec2 b) {
    float d = distLine(p, a, b);
    float len = length(b - a);
    float seg = smoothstep(u_lineWidth, u_lineWidth * 0.5, d);
    return seg * smoothstep(1.25, 0.55, len);
}

void main() {
    vec2 uv = (qt_TexCoord0 - 0.5) * vec2(u_aspect, 1.0) * u_scale;
    // slow drift so the field never feels static
    uv += vec2(u_time * u_speed * 0.05, u_time * u_speed * 0.03);

    vec2 gv = fract(uv) - 0.5;
    vec2 id = floor(uv) - 0.5;

    vec2 p[9];
    int i = 0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            p[i] = pointAt(id, vec2(float(x), float(y)));
            i++;
        }
    }

    float lines = 0.0;
    float glow = 0.0;
    for (int j = 0; j < 9; j++) {
        lines += lineIntensity(gv, p[4], p[j]);
        float d = length(gv - p[j]);
        glow += 0.006 / (0.006 + d * d);
    }
    // extra diagonals for a denser mesh
    lines += lineIntensity(gv, p[1], p[3]);
    lines += lineIntensity(gv, p[1], p[5]);
    lines += lineIntensity(gv, p[7], p[3]);
    lines += lineIntensity(gv, p[7], p[5]);

    // large-scale density so the field isn't uniform
    float dens = 0.6 + 0.4 * sin(uv.x * 0.13 + u_time * 0.05) * sin(uv.y * 0.11 - u_time * 0.04);

    float flick = 0.75 + 0.25 * sin(u_time * u_speed * 1.7 + id.x * 3.0 + id.y * 7.0);

    float edgeA = lines * 0.20 * flick * dens;
    float nodeA = glow * 0.55 * dens;

    vec3 col = mix(u_edgeColor.rgb, u_nodeColor.rgb, clamp(nodeA * 2.5, 0.0, 1.0));
    float a = clamp((edgeA + nodeA) * u_alpha, 0.0, 1.0);

    gl_FragColor = vec4(col * a, a) * qt_Opacity;
}
