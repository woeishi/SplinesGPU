//@author: woei
//@help: creates a hermite spline ribbon along 3d coordinates, calcualted on the GPU
//@tags: curve, spline, hermite, nurbs
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

//---- TCB-Spline --------------------------------------------------------------
struct pota { float4 Pos; float4 Tang; };
pota TCBSpline(float4 x, float4 y, float4 z, float4 w, float3 tcb, float range) {
	pota Out = (pota)0;
	float mu = frac(range);
	float mu2 = mu*mu;
	float mu3 = mu2* mu;
		
	float4 m0 = (y-x)*.5*(1-tcb.x)*(1-tcb.y)*(1+tcb.z);
	       m0+= (z-y)*.5*(1-tcb.x)*(1+tcb.y)*(1-tcb.z);
	float4 m1 = (z-y)*.5*(1-tcb.x)*(1+tcb.y)*(1+tcb.z);
	       m1+= (w-z)*.5*(1-tcb.x)*(1-tcb.y)*(1-tcb.z);
	
	float4 a0 = 2.*mu3 - 3.*mu2 + 1.;
	float4 a1 =    mu3 - 2.*mu2 + mu;
	float4 a2 =    mu3 -    mu2;
	float4 a3 = -2.*mu3 + 3*mu2;
	Out.Pos = a0*y+a1*m0+a2*m1+a3*z;
		
	a0 = 6.*mu2-6.*mu;
	a1 = 3.*mu2-4.*mu+1.;
	a2 = 3*mu2-2*mu;
	a3 = 6.*mu-6.*mu2;
	Out.Tang = a0*y+a1*m0+a2*m1+a3*z;
	return Out;
}
// VERTEXSHADER-----------------------------------------------------------------
float4 TCBSplineGPU(float4 PosO: POSITION, float3 NormO: NORMAL, float4 PosCd : TEXCOORD1, out float3 Tang, out float3 BiTang)
{
	float4 cCd = PosCd;
	float cSize = (Size-1)*0.9999;
	cCd.x = floor(cCd.x*(cSize))/cSize;
	
    float4 a = tex2Dlod(pSamp, float4(cCd.x+(-1./cSize),cCd.yzw));
	float4 b = tex2Dlod(pSamp, cCd);
	float4 c = tex2Dlod(pSamp, float4(cCd.x+(1./cSize),cCd.yzw));
	float4 d = tex2Dlod(pSamp, float4(cCd.x+(2./cSize),cCd.yzw));
	float4 tcb = tex2Dlod(cSamp, cCd);
    
	pota curve = TCBSpline(a,b,c,d,tcb.xyz,PosCd.x*cSize);
    float4 spline = curve.Pos;

	float3 rVec = 0;
	sincos(tcb.w,rVec.y,rVec.z);
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