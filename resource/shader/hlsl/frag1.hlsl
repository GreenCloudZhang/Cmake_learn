struct PSInput
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD;
};

Texture2D g_txDiffuse : register(t0);
SamplerState g_sampler : register(s0);

float4 PSMain(PSInput input):SV_Target
{
    return g_txDiffuse.Sample(g_sampler, input.uv);
}