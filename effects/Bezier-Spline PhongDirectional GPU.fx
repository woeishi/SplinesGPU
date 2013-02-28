//@author: woei
//@help: creates a bezierspline ribbon along 3d coordinats, calcualted on the GPU
//@tags: curve, spline, bezier, cubic bezier
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

texture ColorTex <string uiname="Color Texture";>;
sampler ColorSamp = sampler_state
{
    Texture   = (ColorTex);
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU = clamp;
    ADDRESSV = wrap;
};

float4x4 tTex: TEXTUREMATRIX <string uiname="Texture Transform";>;
float4x4 tColor <string uiname="Color Transform";>;
float alpha = 1.;

#include "Bezier-Spline GPU.fxh"
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
// VERTEXSHADER-----------------------------------------------------------------
vs2ps VS_Spline(float4 PosO: POSITION, float3 NormO: NORMAL, float4 TexCd : TEXCOORD0, float4 PosCd : TEXCOORD1)
{
    vs2ps Out = (vs2ps)0;
    Out.LightDirV = normalize(-mul(lDir, tV));
    
    float3 tang = 0;
    float3 bitang = 0;
    float cSize = 0;
    float4 cCd = 0;
    PosO = BezierSplineGPU(PosO, NormO, PosCd, tang, bitang);

    Out.PosWVP  = mul(PosO, tWVP);
	Out.TexCd = mul (TexCd,tTex);

    //normal in view space
    Out.ViewDirV = -normalize(mul(PosO, tWV));
    Out.Tang = tang;
    Out.Bi = bitang;
	Out.Depth = mul(PosO, tWVP);
	Out.PosCd = PosCd;
    return Out;
}
// PIXELSHADER------------------------------------------------------------------
float4 PS(vs2ps In): COLOR
{
	float4 col = tex2D(Samp, In.TexCd);
    float3 n = normalize(cross(In.Tang,In.Bi));
	float4 textureColor = tex2D(ColorSamp, float4(In.TexCd.x, In.PosCd.yzw));
    col.rgb *= PhongDirectional(n, In.ViewDirV, In.LightDirV) * textureColor.rgb;
    col.a *= alpha * textureColor.a;
    return mul(col, tColor);
}

float4 PS_Depth(vs2ps In): COLOR
{
    float4 col = In.Depth.z;
    col.a =1;
    return col;
}

// TECHNIQUES-------------------------------------------------------------------
technique BezierSpline_PhongDirectional
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Spline();
        PixelShader = compile ps_3_0 PS();
    }
}

technique BezierSpline_Depth
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Spline();
        PixelShader = compile ps_3_0 PS_Depth();
    }
}