shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
varying vec4 particle;
void vertex(){
 particle=INSTANCE_CUSTOM;
 float angle=particle.y*6.283185;mat2 rotation=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)));
 VERTEX.xy=rotation*VERTEX.xy;
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(INV_VIEW_MATRIX[0].xyz*length(MODEL_MATRIX[0].xyz),0),vec4(INV_VIEW_MATRIX[1].xyz*length(MODEL_MATRIX[1].xyz),0),vec4(INV_VIEW_MATRIX[2].xyz*length(MODEL_MATRIX[2].xyz),0),MODEL_MATRIX[3]);
}
void fragment(){
 vec2 p=UV*2.0-1.0;float r=length(p);
 float core=pow(max(0.0,1.0-r),3.0);
 float rays=pow(max(0.0,1.0-abs(p.x)),22.0)*pow(max(0.0,1.0-abs(p.y)),1.8)+pow(max(0.0,1.0-abs(p.y)),24.0)*pow(max(0.0,1.0-abs(p.x)),1.8);
 float flame=max(0.0,1.0-r+sin(p.x*17.0+p.y*13.0+particle.y*40.0)*0.09);
 float shape=core*0.7+rays*0.8;
 if(particle.z>1.5){shape=pow(max(0.0,1.0-abs(p.x)),35.0)*pow(max(0.0,1.0-abs(p.y)),0.6)+core*0.1;}
 else if(particle.z>0.5){shape=pow(flame,1.7);}
 ALBEDO=mix(COLOR.rgb,vec3(1.0,0.97,0.8),core*0.65)*1.5;
 ALPHA=shape*pow(1.0-particle.x,1.5)*COLOR.a;
}
