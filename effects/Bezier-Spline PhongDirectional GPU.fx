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
    MipFilter = POINT;
    MinFilter = POINT;
    MagFilter = POINT;
    AddressU = clamp;
    ADDRESSV = wrap;
};

texture SecondColorTex <string uiname="Second Color Texture";>;
sampler SecondColorSamp = sampler_state
{
    Texture   = (SecondColorTex);
    MipFilter = POINT;
    MinFilter = POINT;
    MagFilter = POINT;
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
    float4 Color : COLOR0;
    float4 SecondColor : COLOR1;
    float U : TEXCOORD7;
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
    PosO = BezierSplineGPU(PosO, NormO, PosCd, tang, bitang, cSize, cCd);
	
    Out.U = PosCd.x * cSize / (Size - 1);
    Out.Color = tex2Dlod(ColorSamp, cCd);
    Out.SecondColor = tex2Dlod(SecondColorSamp, cCd);

    Out.PosWVP  = mul(PosO, tWVP);
    Out.TexCd = mul(TexCd, tTex);

    //normal in view space
    Out.ViewDirV = -normalize(mul(PosO, tWV));
    Out.Tang = tang;
    Out.Bi = bitang;
	Out.Depth = mul(PosO, tWVP);
    return Out;
}
// PIXELSHADER------------------------------------------------------------------
float4 PS(vs2ps In): COLOR
{
	float4 col = tex2D(Samp, In.TexCd);
    float3 n = normalize(cross(In.Tang,In.Bi));    
    col.rgb *= PhongDirectional(n, In.ViewDirV, In.LightDirV);
    col.a*=alpha;
    return mul(col, tColor);
}

float4 PS_Depth(vs2ps In): COLOR
{
    float4 col = In.Depth.z;
    col.a =1;
    return col;
}

float4 PS_Color_From_Texture(vs2ps In): COLOR
{
    float4 col = tex2D(Samp, In.TexCd);
    float4 textureColor = In.Color;
    float3 n = normalize(cross(In.Tang,In.Bi));    
    col.rgb *= PhongDirectional(n, In.ViewDirV, In.LightDirV) * textureColor.rgb;
    col.a *= textureColor.a * alpha;
    return mul(col, tColor);
}

float4 PS_Gradient_From_Two_Color_Textures(vs2ps In): COLOR
{   
    float4 col = tex2D(Samp, In.TexCd);
    float4 textureColor = lerp(In.Color, In.SecondColor, In.U);
    float3 n = normalize(cross(In.Tang,In.Bi));    
    col.rgb *= PhongDirectional(n, In.ViewDirV, In.LightDirV) * textureColor.rgb;
    col.a *= textureColor.a * alpha;
    return mul(col, tColor);
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

technique Color_From_Texture
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Spline();
        PixelShader = compile ps_3_0 PS_Color_From_Texture();
    }
}

technique Gradient_From_Two_Color_Textures
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Spline();
        PixelShader = compile ps_3_0 PS_Gradient_From_Two_Color_Textures();
    }
}