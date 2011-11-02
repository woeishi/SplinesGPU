//@author: woei
//@help: creates a bezier ribbon along 3d coordinates, calcualted on the GPU
//@tags: curve, spline, bezier, piecewise
// PARAMETERS-------------------------------------------------------------------
//transforms
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tWV: WORLDVIEW;
float4x4 tWVP: WORLDVIEWPROJECTION;
#include <effects\PhongDirectional.fxh>

//texture
texture Tex <string uiname="Texture";>;
sampler Samp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (Tex);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
	AddressU = clamp;
	AddressU = clamp;
};

float4x4 tTex: TEXTUREMATRIX <string uiname="Texture Transform";>;
float4x4 tColor <string uiname="Color Transform";>;
float alpha = 1.;

int Size;
texture pTex <string uiname="Position Texture";>;
sampler pSamp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (pTex);          //apply a texture to the sampler
    MipFilter = POINT;         //sampler states
    MinFilter = POINT;
    MagFilter = POINT;
	AddressU = clamp;
	ADDRESSV = wrap;
};

bool rel <string uiname="relative Position";>;
bool next <string uiname="relative to n/n+1";>;
texture cTex <string uiname="Control Texture";>;
sampler cSamp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (cTex);          //apply a texture to the sampler
    MipFilter = POINT;         //sampler states
    MinFilter = POINT;
    MagFilter = POINT;
	AddressU = clamp;
	ADDRESSV = clamp;
};

struct vs2ps
{
    float4 PosWVP: POSITION;
    float4 TexCd : TEXCOORD0;
	float4 PosCd : TEXCOORD1;
    float3 LightDirV: TEXCOORD2;
    float3 ViewDirV: TEXCOORD3;
    float3 Tang : TEXCOORD4;
    float3 Bi : TEXCOORD5;
	float4 Depth : TEXCOORD6;
};
//---- Bezier-Spline -----------------------------------------------------------
struct pota { float4 Pos; float4 Tang; };
pota BezierSplinePW(float4 p1, float4 t1, float4 p2, float4 t2, float range) {
	pota Out = (pota)0;
	
	float mu = frac(range);
		
    float4 c1 = t1+(rel*p1);
    float4 c2 = t2+(rel*lerp(p1,-p2,next));
  
    float mum1 = 1 - mu;
    float mum13 = mum1 * mum1 * mum1;
    float mu3 = mu * mu * mu;

	Out.Pos = mum13*p1 + 3*mu*mum1*mum1*c1 + 3*mu*mu*mum1*c2 + mu3*p2;
	//Out.Pos = lerp(p1,p2,mu);
	Out.Tang = float4(1,0,1,1);//3*(c1-p1)*mum1*mum1+3*(c2-c1)*2*mu*mum1+3*(p2-c2)*mu*mu;
	return Out;
}
// VERTEXSHADER-----------------------------------------------------------------
vs2ps VS_Spline(float4 PosO: POSITION, float4 TexCd : TEXCOORD0, float4 PosCd : TEXCOORD1)
{
    vs2ps Out = (vs2ps)0;
    Out.LightDirV = normalize(-mul(lDir, tV));
	
	
	float cSize = (Size-1)*0.9999;
	float4 cCd = PosCd;
	cCd.x = floor(cCd.x*cSize)/(cSize);
	
    float4 p1 = tex2Dlod(pSamp, float4(cCd.x,cCd.yzw));	
	float4 p2 = tex2Dlod(pSamp, float4(cCd.x+(1./cSize),cCd.yzw));
	
	float4 t1 = tex2Dlod(cSamp, float4(cCd.x,cCd.yzw));
	float4 t2 = tex2Dlod(cSamp, float4(cCd.x+(0.5/cSize),cCd.yzw));
    
	pota curve = BezierSplinePW(p1,t1,p2,t2,PosCd.x*cSize);
	
    float4 spline = curve.Pos;

    float3 tang = normalize(curve.Tang);
    float3 bitang= normalize(cross(tang,float3(0,sin(t1.w),cos(t1.w))));	
    PosO.xyz=spline.xyz+(PosO.y*spline.w*bitang*2);
	
    Out.PosWVP  = mul(PosO, tWVP);
    Out.TexCd = mul(cCd, tTex);

    //normal in view space
    Out.ViewDirV = -normalize(mul(PosO, tWV));
    Out.Tang = tang;
    Out.Bi = bitang;
	Out.Depth = PosCd.x;//mul(PosO, tWVP);
    return Out;
}
// PIXELSHADER------------------------------------------------------------------
float4 PS(vs2ps In): COLOR
{
	float4 col = tex2D(Samp, In.TexCd);
    float3 n = normalize(cross(In.Tang,In.Bi));    
    col.rgb *= PhongDirectional(n, In.ViewDirV, In.LightDirV);;
    col.a*=alpha;
    return mul(col, tColor);
}

float4 PS_Depth(vs2ps In): COLOR
{
    float4 col = In.Depth.z;
    col.a =1;
    return col;
}
// TECHNIQUES-------------------------------------------------------------------
technique BezierSplinePW_PhongDirectional
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Spline();
        PixelShader = compile ps_2_0 PS();
    }
}
technique BezierSpline_Depth
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Spline();
        PixelShader = compile ps_2_0 PS_Depth();
    }
}