//@author: woei
//@help: creates a cubic b-spline ribbon along 3d coordinats, calcualted on the GPU
//@tags: curve, spline, b-spline, cubic
// PARAMETERS-------------------------------------------------------------------
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
//---- B-Spline Cubic ----------------------------------------------------------
struct pota { float4 Pos; float4 Tang; };
pota BSplineCubic(float4 p1, float4 p2, float4 p3, float4 p4, float range) {
	pota Out = (pota)0;

    float mu = frac(range);
   	float4 a0 = p4 - p3*3 + p2*3 - p1;
   	float4 a1 = p3*3 - p2*6 + p1*3.;
	float4 a2 = p3*3 - p1*3;
   	float4 a3 = p3 + p2*4 + p1;
	
	Out.Pos = (a3+mu*(a2+mu*(a1+mu*a0)))/6.;
	Out.Tang = (mu*(2*a0*mu+a1)+mu*(a0*mu+a1)+a2)/6.;
	return Out;
}
// VERTEXSHADER-----------------------------------------------------------------
float pitch;
float4 BSplineCubicGPU(float4 PosO: POSITION, float3 NormO: NORMAL, float4 PosCd: TEXCOORD1, out float3 Tang, out float3 BiTang)
{
	float cSize = (Size-1)*0.9999;
	float4 cCd = PosCd;	
	cCd.x = floor(cCd.x*(cSize))/cSize;

	float4 p1 = tex2Dlod(pSamp, float4(cCd.x-(1./cSize),cCd.yzw));
    float4 p2 = tex2Dlod(pSamp, cCd);
	float4 p3 = tex2Dlod(pSamp, float4(cCd.x+(1./cSize),cCd.yzw));
	float4 p4 = tex2Dlod(pSamp, float4(cCd.x+(2./cSize),cCd.yzw));
    
	pota curve = BSplineCubic(p1,p2,p3,p4,PosCd.x*cSize);
    float4 spline = curve.Pos;

	float3 rVec = 0;
	sincos(pitch,rVec.y,rVec.z);
	float3x3 tR = float3x3(float3(1,0,0), float3(0,rVec.z,-rVec.y), rVec);

	float3 tang = normalize(curve.Tang);
	float3 bitang= normalize(cross(tang,rVec));
	float3x3 tBN = float3x3((float3)0,bitang,cross(tang,bitang));
	PosO.xyz=spline.xyz+(mul(PosO.xyz,tBN)*spline.w);
	
	bitang = normalize(cross(tang,mul(NormO,tR)));
	
    Tang = tang;
    BiTang = bitang;
    return PosO;
}