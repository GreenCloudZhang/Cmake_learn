struct VSInput
{
    float3 position : POSITIONT;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
    float3 tangent : TANGENT;
};

struct PSInput
{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD;
};

cbuffer cb0 : register(b0)
{
    float4x4 g_mWorldViewPoj;
}

PSInput VSMain(VSInput input)
{
    PSInput result;
    
    result.position = mul(float4(input.position, 1.0f), g_mWorldViewPoj);
    result.uv = input.uv;
    
    return result;
}