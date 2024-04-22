StructuredBuffer<int> srcBuffer : register(t0);
RWStructuredBuffer<int> dstBuffer : register(u0);

[numthreads(1024, 1, 1)]
void CSMain(uint3 groupID: SV_GroupID, uint3 tid : SV_DispatchThreadID, uint3 localTid : SV_GroupThreadID, uint groupIndex : SV_GroupIndex)
{
    const int index = tid.x;
    dstBuffer[index] = srcBuffer[index] + 10;
}