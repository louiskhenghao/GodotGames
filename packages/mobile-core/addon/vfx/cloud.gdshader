shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
varying vec4 particle;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
 particle=INSTANCE_CUSTOM;
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(INV_VIEW_MATRIX[0].xyz*length(MODEL_MATRIX[0].xyz),0),vec4(INV_VIEW_MATRIX[1].xyz*length(MODEL_MATRIX[1].xyz),0),vec4(INV_VIEW_MATRIX[2].xyz*length(MODEL_MATRIX[2].xyz),0),MODEL_MATRIX[3]);
}
void fragment(){
 vec2 p=UV*2.0-1.0;
 float n=noise(p*3.7+particle.y*20.0)+noise(p*8.0+particle.y*10.0)*0.35;
 float density=smoothstep(0.0,0.5,1.0-length(p)+n*0.23-0.28);
 float shade=0.58+n*0.36+(1.0-UV.y)*0.16;
 ALBEDO=COLOR.rgb*shade;
 ALPHA=density*pow(1.0-particle.x,1.4)*COLOR.a*0.58;
 if(particle.z>0.5){
  ALBEDO=mix(COLOR.rgb,vec3(1.0,0.93,0.55),pow(max(0.0,1.0-length(p)),2.0));
  ALPHA=density*pow(1.0-particle.x,0.7)*0.88;
 }
}
