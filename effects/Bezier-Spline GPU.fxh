//@author: woei
//@help: creates a bezierspline ribbon along 3d coordinats, calcualted on the GPU
//@tags: curve, spline, bezier, cubic bezier
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

//---- Bezier-Spline -----------------------------------------------------------
bool rel <string uiname="Relative Tangent";> = true;
struct pota { float4 Pos; float4 Tang; };
pota BezierSpline(float4 p1, float4 t1, float4 p2, float4 t2, float range) {
	pota Out = (pota)0;
	
	float mu = frac(range);
		
    float4 c1 = t1+(p1*rel);
    float4 c2 = lerp(t2,-t2,rel)+(p2*rel);
  
    float mum1 = 1 - mu;
    float mum13 = mum1 * mum1 * mum1;
    float mu3 = mu * mu * mu;

	Out.Pos = mum13*p1 + 3*mu*mum1*mum1*c1 + 3*mu*mu*mum1*c2 + mu3*p2;
	Out.Tang = 3*(c1-p1)*mum1*mum1+3*(c2-c1)*2*mu*mum1+3*(p2-c2)*mu*mu;
	return Out;
}
// VERTEXSHADER-----------------------------------------------------------------
float4 BezierSplineGPU(float4 PosO: POSITION, float3 NormO: NORMAL, float4 PosCd : TEXCOORD1, out float3 Tang, out float3 BiTang, out float cSize, out float4 cCd)
{
	
	cSize = (Size-1)*0.9999;
	cCd = PosCd;	
	cCd.x = floor(cCd.x*(cSize))/cSize;
	
    float4 p1 = tex2Dlod(pSamp, cCd);
	float4 t1 = tex2Dlod(cSamp, cCd);
	float4 p2 = tex2Dlod(pSamp, float4(cCd.x+(1./cSize),cCd.yzw));
	float4 t2 = tex2Dlod(cSamp, float4(cCd.x+(1./cSize),cCd.yzw));
    
	pota curve = BezierSpline(p1,float4(t1.xyz,0),p2,float4(t2.xyz,0),PosCd.x*cSize);
    float4 spline = curve.Pos;

	float3 rVec = 0;
	sincos(t1.w,rVec.y,rVec.z);
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