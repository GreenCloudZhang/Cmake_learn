#ifndef UBER_CLOTH_LIT_HLSL
#define UBER_CLOTH_LIT_HLSL

#ifdef ACENNR
#define UnityTexture2D Texture2D
#define UnitySamplerState SamplerState
#endif
#define x_tex2D(tex, uv) SAMPLE_TEXTURE2D(tex, sampler##tex, uv)


float3 CustomReflectionVector(
float3 normal,
float3 cameraVector
)
{
    return 2 * dot(normalize(normal), cameraVector) * normalize(normal) - cameraVector;
}

float3 BlendAngleCorrectedNormals(float3 baseNormal, float3 additionNormal)
{
    //Detail Oriented
    float b1 = baseNormal.b + 1;
    float3 n1 = float3(baseNormal.rg, b1);
    float3 n2 = float3(-additionNormal.r, -additionNormal.g, additionNormal.b);
    return n1 * dot(n1, n2) - b1 * n2;
    
    //lower-end platforms//
    //return normalize(float3(baseNormal.xy + additionNormal.xy, baseNormal.z))
}


float3 CalcNormalDetailTexturing(
float3 normal,
float3 detailNormal,
float detailIntensity)
{
    float3 addN = normalize(float3(detailIntensity, detailIntensity, 1) * detailNormal);
    return BlendAngleCorrectedNormals(normal, addN);
}

float3 FuzzyShading(
float3 viewVector,
float3 baseColor,
float3 normal, //DoubleSideWS
float coreDarkness,
float power,
float edgeBrightness
)
{
    float VdotN = clamp(dot(viewVector, normal), 0, 1);
    float colorScale = pow((1 - VdotN), power) * edgeBrightness + (1 - VdotN * coreDarkness);
    return baseColor * colorScale;
}

float RandomNoise(float2 scaleRandomSeed, float2 speed, float2 texcoord, float tileScale, float time)
{
    float2 seed = frac((floor(speed * time) / tileScale + scaleRandomSeed) + (floor(texcoord * tileScale) / tileScale));
    return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
}

float2 BumpOffset(float2 coordinate, float height, float heightRatioInput, float3 viewTS)
{
    float referencePlane = 0.5f;
    return viewTS.xy * (heightRatioInput * height - referencePlane * heightRatioInput) + coordinate;
}

void CalcFinalNormal_float(
    bool useNormalMap,
    float normalIntensity,
    bool useDetailNormalMap,
    float detailNormalIntensity,
    float4 normalSampleValue,
    float4 detailNormalSampleValue,
    bool isFrontFace,

    out float3 finalNormal,
    out float3 finalNormalDoubleSided
)
{
    //Normal
    finalNormal = float3(0.0, 0.0, 1.0); //tangentSpace
    if (useNormalMap)
    {
        finalNormal = normalSampleValue.rgb;
        finalNormal.rg *= normalIntensity;
        finalNormal = normalize(finalNormal);
    }
        
    if (useDetailNormalMap)
    {
        finalNormal = CalcNormalDetailTexturing(finalNormal, detailNormalSampleValue.rgb, detailNormalIntensity);
    }
    
    finalNormal = normalize(finalNormal); //tangent space
    finalNormalDoubleSided = finalNormal * float3(1, 1, isFrontFace ? 1 : -1);
}

//iridescence//
void CalcIridescenceInfo_float(
float3 normalWS,
float3 viewWS,
float iridescenceDensity,
float iridescenceOffset,
float iridescenceMode,
float rimFalloff,
float specularFalloff,

out float varyU,
out float varyAlpha
)
{
    float3 lightDir = normalize(float3(-0.5, 88.5, 0.5));
    float rimPow = pow(1 - clamp(dot(normalWS, viewWS), 0, 1), abs(rimFalloff));
    float m05 = (max(dot(normalWS, lightDir) * 0.5 + 0.5, 0) + pow(max(dot(viewWS, CustomReflectionVector(normalWS, lightDir)), 0), abs(specularFalloff))) * 0.5;
    varyU = lerp(frac(rimPow * iridescenceDensity + iridescenceOffset), lerp(frac(m05 * iridescenceDensity + iridescenceOffset), 1, rimPow), floor(iridescenceMode));
    varyAlpha = m05;
}

float3 Zucconi6(float2 inV)//left->right : rainbow colors reverse
{
    float3 c1 = float3(3.545851, 2.932253, 2.415939);
    float3 x1 = float3(0.695491, 0.492283, 0.276999);
    float3 y1 = float3(0.023126, 0.152251, 0.52608);
    float3 c2 = float3(3.903071, 3.21183, 3.965871);
    float3 x2 = float3(0.117486, 0.86755, 0.660779);
    float3 y2 = float3(0.848971, 0.884453, 0.739495);
    float r = saturate(frac(inV).r);
    float3 add1 = saturate(float3(1, 1, 1) - (c1 * (r - x1)) * (c1 * (r - x1)) - y1);
    float3 add2 = saturate(float3(1, 1, 1) - (c2 * (r - x2)) * (c2 * (r - x2)) - y2);
    return pow(add1 + add2, 2.2);
}

float3 BlendScreen(float3 base, float3 blend)
{
    return 1 - (1 - base) * (1 - blend);
}
//iridescence//


//////Bling//
////float4 CalcBlingInfo(
////float tile,
////float2 uvInput,
////float scaleSeedIn,
////float scaleRandom,
////float translateSeedIn,
////float translateRandom,
////float rotateSeedIn,
////float rotateRandom,
////float steps,
////float length,
////UnityTexture2D _blingTex,
////UnitySamplerState sampler_blingTex,
////UnityTexture2D _rampTex,
////UnitySamplerState sampler_rampTex
////)
////{
////    float4 layerColor = float4(0, 0, 0, 0);
////    float s = clamp(steps, 5.0, 10.0);
////    float offset = length / s;
////    float2 curUV;
////    float4 norm = float4(0, 0, 0, 0);

////    for (int j = 0; j < (int) s; j++)
////    {
////        float2 tileOffset = float2(frac(sin(dot((offset * j), float2(12.9898, 78.233))) * 43758.5453), frac(sin(dot((offset * (j + 1)), float2(12.9898, 78.233))) * 43758.5453));
////        float2 uvFloor = floor(tile * (uvInput + tileOffset));
////        float2 uvFrac = frac(tile * (uvInput + tileOffset)) - 0.5;
////        float scaleSeedOut = frac(sin(dot((uvFloor + scaleSeedIn + offset * j), float2(12.9898, 78.233))) * 43758.5453);
////        float scale = lerp(1.0, max(scaleSeedOut, 0.0001), scaleRandom);
////        float translateSeedOut = frac(sin(dot((uvFloor + translateSeedIn + offset * j), float2(12.9898, 78.233))) * 43758.5453);
////        float translate = lerp(0.0, (1.0 / scale - 1.0) / 2.0, translateSeedOut);
////        float rotateSeedOut = frac(sin(dot(uvFloor + rotateSeedIn + offset * j, float2(12.9898, 78.233))) * 43758.5453);
////        float rotateAngle = lerp(0.0, rotateSeedOut, rotateRandom);
////        float2 rotate = float2(cos(rotateAngle) * uvFrac.x + sin(rotateAngle) * uvFrac.y, cos(rotateAngle) * uvFrac.y - sin(rotateAngle) * uvFrac.x);
////        curUV = clamp(lerp(rotate / scale + 0.5, rotate / scale + 0.5 + translate, translateRandom), 0.0, 1.0);
////        //float4 shape = Texture2DSample(blingTex, TexSampler, curUV);
////        float4 shape = x_tex2D(_blingTex, curUV);
////        //norm = Texture2DSample(rampTex, TexSampler, float2(frac(sin(dot((uvFloor), float2(12.9898, 78.233))) * 43758.5453), 0.5));
////        norm = x_tex2D(_rampTex, float2(frac(sin(dot((uvFloor), float2(12.9898, 78.233))) * 43758.5453), 0.5));
////        float4 curColor = shape * norm;
////        layerColor = lerp(layerColor, curColor, shape.x);
////    }
////    return layerColor;
////}
////-------Bling-------//
//void CalcBlingEmissive_float(
//bool useBlingEmissive,
//bool useBlingNormal,
//float blingEmissiveDensity,
//float blingNormalDensity,
//float blingLayer,
//float4 blingRandomSTR,
//float blingRandomSeed,
//float blingNormalIntensity,
//UnityTexture2D _BlingShapeMap,
//UnityTexture2D _BlingNRampMap,
//float2 texcoord,

//out float4 blingEmissive,
//out float4 blingNormal
//)
//{
//    blingEmissive = float4(0, 0, 0, 0);
//    blingNormal = float4(0, 0, 1, 0);
//    float step = clamp(blingLayer, 5.0, 10.0);
//    float offset = blingRandomSeed / step;
//    if (useBlingEmissive)
//    {
//        //blingEmissive = CalcBlingInfo(blingEmissiveDensity, texcoord, 88.7, blingRandomSTR.r, 2.691, blingRandomSTR.g, 6.525, blingRandomSTR.b, blingLayer, blingRandomSeed, _BlingShapeTex, sampler_BlingShapeTex, _BlingNRampTex, sampler_BlingNRampTex);
//        blingEmissive = float4(0, 0, 0, 0);
//        float2 curUV;
//        float4 norm = float4(0, 0, 0, 0);
//        for (int j = 0; j < (int) (step); j++)
//        {
//            float2 tileOffset = float2(frac(sin(dot((offset * j), float2(12.9898, 78.233))) * 43758.5453), frac(sin(dot((offset * (j + 1)), float2(12.9898, 78.233))) * 43758.5453));
//            float2 uvFloor = floor(blingEmissiveDensity * (texcoord + tileOffset));
//            float2 uvFrac = frac(blingEmissiveDensity * (texcoord + tileOffset)) - 0.5;
//            float scaleSeedOut = frac(sin(dot((uvFloor + 88.7 + offset * j), float2(12.9898, 78.233))) * 43758.5453);
//            float scale = lerp(1.0, max(scaleSeedOut, 0.0001), blingRandomSTR.r);
//            float translateSeedOut = frac(sin(dot((uvFloor + 2.691 + offset * j), float2(12.9898, 78.233))) * 43758.5453);
//            float translate = lerp(0.0, (1.0 / scale - 1.0) / 2.0, translateSeedOut);
//            float rotateSeedOut = frac(sin(dot(uvFloor + 6.525 + offset * j, float2(12.9898, 78.233))) * 43758.5453);
//            float rotateAngle = lerp(0.0, rotateSeedOut, blingRandomSTR.b);
//            float2 rotate = float2(cos(rotateAngle) * uvFrac.x + sin(rotateAngle) * uvFrac.y, cos(rotateAngle) * uvFrac.y - sin(rotateAngle) * uvFrac.x);
//            curUV = clamp(lerp(rotate / scale + 0.5, rotate / scale + 0.5 + translate, blingRandomSTR.g), 0.0, 1.0);
//            //float4 shape = Texture2DSample(blingTex, TexSampler, curUV);
//            float4 shape = x_tex2D(_BlingShapeMap, curUV);
//            //norm = Texture2DSample(rampTex, TexSampler, float2(frac(sin(dot((uvFloor), float2(12.9898, 78.233))) * 43758.5453), 0.5));
//            norm = x_tex2D(_BlingNRampMap, float2(frac(sin(dot((uvFloor), float2(12.9898, 78.233))) * 43758.5453), 0.5));
//            float4 curColor = shape * norm;
//            blingEmissive = lerp(blingEmissive, curColor, shape.x);
//        }
//        blingEmissive.rgb = normalize(float3((blingEmissive.rg * 2 - 1) * blingEmissive.a, 1));
//    }
//    if (useBlingNormal)
//    {
//        //blingNormal = CalcBlingInfo(blingNormalDensity, texcoord, 88.7, blingRandomSTR.r, 2.691, blingRandomSTR.g, 6.525, blingRandomSTR.b, blingLayer, blingRandomSeed, _BlingShapeTex, sampler_BlingShapeTex, _BlingNRampTex, sampler_BlingNRampTex);
//        blingNormal = float4(0, 0, 0, 0);
//        float2 curUV;
//        float4 norm = float4(0, 0, 0, 0);
//        for (int j = 0; j < (int) (step); j++)
//        {
//            float2 tileOffset = float2(frac(sin(dot((offset * j), float2(12.9898, 78.233))) * 43758.5453), frac(sin(dot((offset * (j + 1)), float2(12.9898, 78.233))) * 43758.5453));
//            float2 uvFloor = floor(blingNormalDensity * (texcoord + tileOffset));
//            float2 uvFrac = frac(blingNormalDensity * (texcoord + tileOffset)) - 0.5;
//            float scaleSeedOut = frac(sin(dot((uvFloor + 88.7 + offset * j), float2(12.9898, 78.233))) * 43758.5453);
//            float scale = lerp(1.0, max(scaleSeedOut, 0.0001), blingRandomSTR.r);
//            float translateSeedOut = frac(sin(dot((uvFloor + 2.691 + offset * j), float2(12.9898, 78.233))) * 43758.5453);
//            float translate = lerp(0.0, (1.0 / scale - 1.0) / 2.0, translateSeedOut);
//            float rotateSeedOut = frac(sin(dot(uvFloor + 6.525 + offset * j, float2(12.9898, 78.233))) * 43758.5453);
//            float rotateAngle = lerp(0.0, rotateSeedOut, blingRandomSTR.b);
//            float2 rotate = float2(cos(rotateAngle) * uvFrac.x + sin(rotateAngle) * uvFrac.y, cos(rotateAngle) * uvFrac.y - sin(rotateAngle) * uvFrac.x);
//            curUV = clamp(lerp(rotate / scale + 0.5, rotate / scale + 0.5 + translate, blingRandomSTR.g), 0.0, 1.0);
//            //float4 shape = Texture2DSample(blingTex, TexSampler, curUV);
//            float4 shape = x_tex2D(_BlingShapeMap, curUV);
//            //norm = Texture2DSample(rampTex, TexSampler, float2(frac(sin(dot((uvFloor), float2(12.9898, 78.233))) * 43758.5453), 0.5));
//            norm = x_tex2D(_BlingNRampMap, float2(frac(sin(dot((uvFloor), float2(12.9898, 78.233))) * 43758.5453), 0.5));
//            float4 curColor = shape * norm;
//            blingNormal = lerp(blingNormal, curColor, shape.x);
//        }
//        blingNormal.rgb = normalize(float3((blingNormal.rg * 2 - 1) * blingNormalIntensity * blingNormal.a, 1.0));
//    }
//}

void UberClothLit_float(
    bool useBaseMap,
    float4 baseColor,
    bool useMetallicRoughnessMap,
    float metallic,
    float roughness,
    bool enableFuzzyShading,
    float fuzzCoreDarkness,
    float fuzzEdgeBrightness,
    float fuzzPower,
    
    bool enableEmissive,
    float emissivePower,
    float4 emissiveColor,
    bool useEmissiveColorMap,
    bool enableEmissiveFresnel,
    float emissiveFresnelExponent,

    //bool   useNormalMap,
    //float  normalIntensity,
    //bool   useDetailNormalMap,
    //float  detailNormalIntensity,
    //float  detailNormalScale,

    bool enableIridescence,
    float4 iridescenceColor,
    float iridescenceIntensity,
    //float  iridescenceDensity,
    //float  iridescenceOffset,
    //float  iridescenceMode,
    //float  rimFalloff,
    //float  specularFalloff,
    float specularMaskIntensity,
    //bool   useIridescenceMask,
    bool useRampTexture,
    float varyIriU,
    float varyIriAlpha, //m05

    bool enableAO,
    float aoInfluence,

    bool useGlitter,
    float glitterScale,
    float glitterDepth,
    float glitterDepthScale,
    float4 glitterColor,
    float glitterColorFactor,
    float glitterPower,
    float glitterDepthColorFactor,
    float glitterIntensity,
    float4 glitterSpeed,
    
    float4 baseColorSampleValue,
    float4 rmaSampleValue,
    //float4 normalSampleValue,
    //float4 detailNormalSampleValue,
    float4 emissiveSampleValue,
    float4 iridescenceRampSampleValue,

    float3 normalWS, //TRANSFORM finalNormal 
    float3 normalTwoSidedWS,
    float3 viewWS,
    float3 viewTS,
    float2 texcoord0,
    float time,

    out float3 finalAlbedo,
    out float finalMetallic,
    out float finalRoughness,
    out float3 finalEmissive,
    out float finalAO
)
{
    //Albedo
    finalAlbedo = baseColor.rgb;
    if (useBaseMap)
        finalAlbedo *= baseColorSampleValue.rgb;
    
    //Metallic
    finalMetallic = metallic;
    if (useMetallicRoughnessMap)
        finalMetallic *= rmaSampleValue.g;
    
    //Roughness
    finalRoughness = roughness;
    if (useMetallicRoughnessMap)
        finalRoughness *= rmaSampleValue.r;
    
    ////Normal
    //float3 normalTemp = float3(0.5, 0.5, 1);//tangentSpace
    //if(useNormalMap)
    //    normalTemp = normalSampleValue.rgb;
    //normalTemp.rg *= normalIntensity;
    //finalNormal = normalTemp;
    //if(useDetailNormalMap)
    //{
    //    finalNormal = calcNormalDetailTexturing(detailNormalIntensity, 0, 0, 0, normalTemp, detailNormalSampleValue.rgb, detailNormalIntensity);
    //}
    //finalNormal = normalize(finalNormal);//tangent space
    

    //Fuzz
    float3 finalFuzz = finalAlbedo;
    if (enableFuzzyShading)
    {
        finalFuzz = FuzzyShading(viewWS, finalAlbedo, normalTwoSidedWS, fuzzCoreDarkness, fuzzPower, fuzzEdgeBrightness);
    }
    
    //AO
    finalAO = 1;
    if (enableAO)
    {
        finalAO = clamp(rmaSampleValue.b + lerp(1, 0, aoInfluence), 0, 1);
    }
        
    
    //Iridescence
    finalAlbedo = finalFuzz;
    if (enableIridescence)
    {
        float3 rampColor = iridescenceRampSampleValue.rgb;
        if (!useRampTexture)
        {
            rampColor = Zucconi6((float2) (varyIriU));
        }
        float3 blendColor = BlendScreen(iridescenceColor.rgb, rampColor);
        finalAlbedo = lerp(finalFuzz, lerp(blendColor, lerp(finalFuzz.rgb, blendColor, varyIriAlpha), specularMaskIntensity), iridescenceIntensity);
    }
    
    
    //Emissive
    finalEmissive = float3(0, 0, 0);
    float fresnel = 0.04 + (1.0 - 0.04) * pow((1.0 - saturate(dot(viewWS, normalWS))), 5.0);
    if (enableEmissive)
    {
        finalEmissive = emissiveColor.rgb;
        if (useEmissiveColorMap)
            finalEmissive = finalEmissive * emissiveSampleValue.rgb * emissivePower;
        if (enableEmissiveFresnel)
        {
            finalEmissive *= fresnel;
        }
    }
    
    //Glitter
    if (useGlitter)
    {
        float3 glitterRandomSeed = float3(6.136551, 0.906666, 0.341334);
        float r1 = RandomNoise((float2) (glitterRandomSeed.rg), glitterSpeed.ba, texcoord0, glitterDepthScale, time);
        float2 tex = BumpOffset(texcoord0, (0 - r1) * glitterDepth, 0.05, viewTS);
        float3 rCombine = float3(RandomNoise((float2) (glitterRandomSeed.r), glitterSpeed.rg, tex, glitterScale, time), RandomNoise((float2) (glitterRandomSeed.g), glitterSpeed.rg, tex, glitterScale, time), RandomNoise((float2) (glitterRandomSeed.b), glitterSpeed.rg, tex, glitterScale, time));
        float intensityFactor = pow(abs(dot(viewWS, normalize(normalize(rCombine - 0.5) + normalWS))), glitterPower);
        float3 finalGlitter = lerp(rCombine, glitterColor.rgb, glitterColorFactor) * pow(1 - r1, glitterDepthColorFactor) * intensityFactor * glitterIntensity;
        finalEmissive += finalGlitter;
    }
}

void CalcAnisotropy_float(
    bool useAnisotropy,
    float anisotropy,
    bool useFlowMap,
    float4 flowSampleValue,
    float3 normalWS,

    out float finalAnisotropy,
    out float3 finalTangent
)
{
    //Anisotropy
    finalAnisotropy = 0;
    if (useAnisotropy)
        finalAnisotropy = anisotropy;
    
    //Anisotropy Tangent
    finalTangent = float3(0, 0, 0);
    if (useAnisotropy)
    {
        finalTangent = normalize(cross(float3(0, 1, 0), normalWS));
        if (useFlowMap)
        {
            //UE Tangent -> Unity Tangent
            finalTangent = normalize(flowSampleValue.rgb);
        }
    }
}

#endif