float4 main(float3 v : POSITION) : SV_POSITION
{
    return float4(v.x + v.y + v.z, 0, 0, 0);
}