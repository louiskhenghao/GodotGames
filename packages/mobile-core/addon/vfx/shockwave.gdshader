shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
varying vec4 particle;
void vertex(){particle=INSTANCE_CUSTOM;}
void fragment(){
 vec2 p=UV*2.0-1.0;float r=length(p);float angle=atan(p.y,p.x);
 float ring=pow(max(0.0,1.0-abs(r-(0.65+particle.x*0.18))*14.0),2.0);
 float rays=pow(max(0.0,sin(angle*19.0+r*9.0+particle.y*5.0)),15.0)*pow(max(0.0,1.0-r),0.7);
 float spiral=pow(max(0.0,sin(angle*3.0-r*13.0+particle.x*10.0)),9.0)*smoothstep(0.1,0.4,r)*(1.0-smoothstep(0.75,1.0,r));
 float shape=mix(ring+rays*0.65,spiral+ring*0.35,step(0.5,particle.z));
 ALBEDO=COLOR.rgb*1.65;ALPHA=shape*(1.0-particle.x)*COLOR.a;
}
