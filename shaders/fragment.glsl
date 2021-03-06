#define AA 1

uniform vec2 iTime;
uniform vec3 cam_pos;
uniform vec3 cam_dir;
uniform int object_amount;
uniform struct Object
{
	int Type;
	int i; //Object ID
	vec3 p; //Vector 3: position
	vec3 b; //Vector 3: size (if sphere, only x is used)
	vec3 color;
	float alpha;
} objects[30];
uniform float fog_density;
uniform float view_distance;

//Define RESULT
struct RESULT {
	vec4 re;
	int i;
};

struct L_RESULT {
	float t;
	vec4 m; //Material
	int id;
};

struct GI_TRACE {
	vec3 pos;
	vec3 dir;
	int id;
	vec4 m; //Material
};

vec4 opU( vec4 d1, vec4 d2 )
{
	return (d1.x<d2.x) ? d1 : d2;
}

float opS( float d1, float d2 )
{
    return max(-d1,d2);
}

float opI( float d1, float d2 )
{
    return max(d1,d2);
}

float opMorph(float d1, float d2, float a)
{
    a = clamp(a,0.0,1.0);
    return a * d1 + (1.0 - a) * d2;
}

// distance to sphere function (p is world position of the ray, s is sphere radius)
// from http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdSphere(vec3 p, float s)
{
	return length(p) - s;
}

float sdPlane(vec3 p)
{
    return p.y;
}

float udBox( vec3 p, vec3 b )
{
    return length(max(abs(p)-b,0.0));
}

float sdBox(vec3 p, vec3 b)
{
	vec3 d = abs(p) - b;
	return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float fmod(float a, float b)
{
    if(a<0.0)
    {
        return b - mod(abs(a), b);
    }
    return mod(a, b);
}

RESULT map(vec3 pos)
{
	//vec3 cp = vec3(0.0,0.0,0.0);

    //vec2 res = opU(vec2(sdPlane(pos - vec3(0.0,0.0,0.0) + cp),1.0),
    //               vec2(sdSphere(pos - vec3(0.0,0.5,0.0) + cp,0.5),46.9));

    //float b = opBlend(udBox(pos - vec3(1.0,0.5,0.0) + cp,vec3(0.5,0.5,0.5)),
    //                  sdSphere(pos - vec3(1.0,0.5,0.0) + cp,0.5),(sin(iTime.x)+1.0)/2.0);
    //res = opU(res, vec2(b,78.5));

    //b = opI(udBox(pos - vec3(-1.0,0.5 * (sin(iTime.x)+1.0)/2.0,0.0) + cp,vec3(0.5,0.5,0.5)),
    //        sdSphere(pos - vec3(-1.0,0.5,0.0) + cp,0.5));
    //res = opU(res, vec2(b,129.8));

    //b = opS(sdSphere(pos - vec3(-1.0,0.5,-1.0) + cp,0.5),
    //        udBox(pos - vec3(-1.0,0.5 * (sin(iTime.x))/1.0,-1.0) + cp,vec3(0.5,0.5,0.5)));
    //res = opU(res, vec2(b,22.4));

	vec4 res = vec4(sdModel(pos), 0.6, 0.6, 0.6);
	int id = 0;

  RESULT r;
	r.re = res;
	r.i = id;
  return r;
}

RESULT castRay(vec3 pos, vec3 dir)
{
    float tmin = 0.005;
    float tmax = view_distance;

    float tp1 = (0.0 - pos.y)/dir.y; if (tp1 > 0.0) tmax = min(tmax, tp1);
    float tp2 = (120 - pos.y)/dir.y; if (tp2 > 0.0) { if (pos.y > 120) tmin = max(tmin, tp2);
                                                     else tmax = min(tmax, tp2); }

    float t = tmin;
    vec3 m = vec3(-1.0);
		int id = 0;
    for (int i=0; i<64; i++)
    {
        float precis = 0.0005*t;
        RESULT r = map(pos + dir*t);
				vec4 res = r.re;
				id = r.i;
        if (res.x<precis || t>tmax) break;
        t += res.x;
        m = res.yzw;
    }

    if (t>tmax) m=vec3(-15.0);
    //return vec4(t, m);
		RESULT re;
		re.re = vec4(t, m);
		re.i = id;
		return re;
}

float softshadow( in vec3 ro, in vec3 rd, in float mint, in float tmax )
{
	float res = 1.0;
    float t = mint;
    for( int i=0; i<16; i++ )
    {
		float h = map( ro + rd*t ).re.x;
        res = min( res, 8.0*h/t );
        t += clamp( h, 0.02, 0.10 );
        if( h<0.001 || t>tmax ) break;
    }
    return clamp( res, 0.0, 1.0 );
}

vec3 calcNormal( in vec3 pos )
{
    vec2 e = vec2(1.0,-1.0)*0.5773*0.0005;
    return normalize( e.xyy*map( pos + e.xyy ).re.x +
					  e.yyx*map( pos + e.yyx ).re.x +
					  e.yxy*map( pos + e.yxy ).re.x +
					  e.xxx*map( pos + e.xxx ).re.x );
    /*
	vec3 eps = vec3( 0.0005, 0.0, 0.0 );
	vec3 nor = vec3(
	    map(pos+eps.xyy).x - map(pos-eps.xyy).x,
	    map(pos+eps.yxy).x - map(pos-eps.yxy).x,
	    map(pos+eps.yyx).x - map(pos-eps.yyx).x );
	return normalize(nor);
	*/
}

float calcAO( in vec3 pos, in vec3 nor )
{
	float occ = 0.0;
  float sca = 1.0;
  for( int i=0; i<50; i++ )
  {
      float hr = 0.01 + 0.12*float(i)/50.0;
      vec3 aopos =  nor * hr + pos;
      float dd = map( aopos ).re.x;
      occ += -(dd-hr)*sca;
      sca *= 0.95;
  }
  return clamp( 1.0 - 3.0*occ, 0.0, 1.0 );
}

vec3 calcFog(vec3 pos, vec3 rd)
{
	float d = length(pos)*0.6*fog_density;
	d = clamp(pow(d,2),0.0,1.0);
	vec3 col = vec3(0.7, 0.9, 1.0)*d + 0.1*d;
	col = clamp(col,0.0,1.0-fog_density/10);
	//vec3 col = sky_color*d;
	return col;
}

vec3 render( in vec3 ro, in vec3 rd )
{
	vec3 col = vec3(0.7, 0.9, 1.0) + rd.y*0.8;
	vec3 c = vec3(0.0);
  //vec4 res = castRay(ro,rd);
	RESULT r = castRay(ro, rd);
	vec4 res = r.re;
	int id = r.i;
  float t = res.x;
	vec3 m = res.yzw;

	if (m != vec3(-15.0))
	{
		vec3 pos = ro + t*rd;
		vec3 nor = calcNormal( pos );
		vec3 ref = reflect( rd, nor );

		// material
		col = m;
		if (m.x == -2.0)
		{
			if (m.y == -2.0)
			{
				if (m.z == -2.0)
				{
					float f = mod( floor(5.0*pos.z) + floor(5.0*pos.x), 2.0);
					col = 0.3 + 0.1*f*vec3(1.0);
				}
			}
		}

		// lighting
		float occ = calcAO( pos, nor );

		c = col * occ;

		vec3 fog_pos = pos - cam_pos;
		c = c + calcFog(fog_pos, rd);
	} else {
		return (vec3(0.7, 0.9, 1.0) + rd.y*0.8);
	}

	return vec3( clamp(c,0.0,1.0) );
}

mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
	vec3 cw = normalize(ta-ro);
	vec3 cp = vec3(sin(cr), cos(cr),0.0);
	vec3 cu = normalize( cross(cw,cp) );
	vec3 cv = normalize( cross(cu,cw) );
    return mat3( cu, cv, cw );
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec2 fragCoord = vec2(screen_coords.x, love_ScreenSize.y - screen_coords.y);
	float time = 15.0 + iTime.x;

  vec3 tot = vec3(0.0,0.0,0.0);
#if AA>1
  for( int m=0; m<AA; m++ )
  for( int n=0; n<AA; n++ )
  {
    // pixel coordinates
    vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
    vec2 p = (-love_ScreenSize.xy + 2.0*(fragCoord+o))/love_ScreenSize.y;
#else
    vec2 p = (-love_ScreenSize.xy + 2.0*fragCoord)/love_ScreenSize.y;
#endif

		// camera
    vec3 ro = cam_pos;
		vec3 ta = cam_pos + cam_dir;
		// camera-to-world matrix
		mat3 ca = setCamera(ro, ta, 0.0);
    // ray direction
    vec3 rd = ca * normalize(vec3(p.xy,2.0));

    // render
    vec3 col = render( ro, rd );

		// gamma
    col = pow( col, vec3(0.4545) );

    tot += col;
#if AA>1
    }
    tot /= float(AA*AA);
#endif

    return vec4( tot, 1.0 );
}
