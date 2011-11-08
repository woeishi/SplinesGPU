//@author: woei
//@help: creates a ribbon along 3d coordinates, calcualted on the GPU
//@tags: line, spline, linear
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

//---- Linear-Spline -----------------------------------------------------------
struct pota { float4 Pos; float4 Tang; };
pota LinearSpline(float4 p1, float4 p2, float range) {
	pota Out = (pota)0;
	Out.Pos = lerp(p1,p2,frac(range));	
	Out.Tang = p1-p2;
	return Out;
}
// VERTEXSHADER-----------------------------------------------------------------
float pitch;
float4 LinearSplineGPU(float4 PosO: POSITION, float3 NormO: NORMAL, float4 PosCd: TEXCOORD1, out float3 Tang, out float3 BiTang)
{
	float cSize = (Size-1)*0.9999;
	float4 cCd = PosCd;	
	cCd.x = floor(cCd.x*(cSize))/cSize;
	
    float4 p1 = tex2Dlod(pSamp, cCd);
	float4 p2 = tex2Dlod(pSamp, float4(cCd.x+(1./cSize),cCd.yzw));	
    
	pota curve = LinearSpline(p1,p2,PosCd.x*cSize);
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