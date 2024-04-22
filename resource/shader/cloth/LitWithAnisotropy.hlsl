#ifndef LIT_WITH_ANISOTROPY_HLSL
#define LIT_WITH_ANISOTROPY_HLSL

#ifdef ACENNR
#if defined(_MAIN_LIGHT_SHADOWS_CASCADE) && !defined(_RECEIVE_SHADOWS_OFF)
#define MAIN_LIGHT_CALCULATE_SHADOWS
#endif
#elif !defined(_RECEIVE_SHADOWS_OFF)
#define MAIN_LIGHT_CALCULATE_SHADOWS
#endif

#if(defined(ACENNR) && defined(_ADDITIONAL_LIGHTS)) || !defined(ACENNR)
#define ACESG_ADDITIONAL_LIGHTS
#endif

#ifndef SHADERGRAPH_PREVIEW
half ComputeCascadeIndex_UnlitSG(float3 positionWS)
{
    float3 fromCenter0 = positionWS - _CascadeShadowSplitSpheres0.xyz;
    float3 fromCenter1 = positionWS - _CascadeShadowSplitSpheres1.xyz;
    float3 fromCenter2 = positionWS - _CascadeShadowSplitSpheres2.xyz;
    float3 fromCenter3 = positionWS - _CascadeShadowSplitSpheres3.xyz;
    float4 distances2 = float4(dot(fromCenter0, fromCenter0), dot(fromCenter1, fromCenter1), dot(fromCenter2, fromCenter2), dot(fromCenter3, fromCenter3));

    half4 weights = half4(distances2 < _CascadeShadowSplitSphereRadii);
    weights.yzw = saturate(weights.yzw - weights.xyz);
#ifdef ACENNR
    return half(4.0) - dot(weights, half4(4, 3, 2, 1));
#else
    half id = dot(weights, half4(4, 3, 2, 1));
    return id == 0 ? 0 : half(4.0) - id;
#endif
}

Light GetMainLight_UnlitSG(float3 positionWS)
{
#ifdef MAIN_LIGHT_CALCULATE_SHADOWS
    Light mainLight = GetMainLight();
    half cascadeIndex = ComputeCascadeIndex_UnlitSG(positionWS);
    float4 shadowCoord = mul(_MainLightWorldToShadow[(int) cascadeIndex], float4(positionWS, 1.0));

    ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
    half4 shadowParams = _MainLightShadowParams;
    mainLight.shadowAttenuation = SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, false);
    real shadowStrength = shadowParams.x;

    if (shadowParams.y != 0)
    {
        mainLight.shadowAttenuation = SampleShadowmapFiltered(TEXTURE2D_SHADOW_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData);
    }
    else
    {
        // 1-tap hardware comparison
        mainLight.shadowAttenuation = real(SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, shadowCoord.xyz));
    }
    mainLight.shadowAttenuation = LerpWhiteTo(mainLight.shadowAttenuation, shadowStrength);
#else
    Light mainLight = GetMainLight();
#endif
    return mainLight;
}


float3 GlobalIllumination_UnlitSG(BRDFData brdfData, float3 bakedGI, float occlusion,
    half3 normalWS, half3 viewDirectionWS, float3 positionWS)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half NoV = saturate(dot(normalWS, viewDirectionWS));
    half fresnelTerm = Pow4(1.0 - NoV);
    half3 indirectDiffuse = bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfData.perceptualRoughness, occlusion);
    half3 color = EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
    return color;
}

float3 GlobalIllumination_UnlitSG(float3 diffuse, float3 specular, float roughness2, float grazingTerm, float perceptualRoughness,
    float3 bakedGI, float occlusion,
    half3 normalWS, half3 viewDirectionWS, float3 positionWS)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half NoV = saturate(dot(normalWS, viewDirectionWS));
    half fresnelTerm = Pow4(1.0 - NoV);
    half3 indirectDiffuse = bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, perceptualRoughness, occlusion);

    half3 color = indirectDiffuse * diffuse;
    float surfaceReduction = 1.0 / (roughness2 + 1.0);
    color += indirectSpecular * surfaceReduction * lerp(specular, grazingTerm, fresnelTerm);
    return color;
}
#else // SHADERGRAPH_PREVIEW
struct Light
{
    half3   direction;
    half3   color;
    half    distanceAttenuation;
    half    shadowAttenuation;
};

Light GetMainLight_UnlitSG(float3 positionWS)
{
    Light mainLight;
    mainLight.direction = float3(1.0, 0.0, 0.0);
    mainLight.color = float3(1.0, 1.0, 1.0);
    mainLight.distanceAttenuation = 1.0;
    mainLight.shadowAttenuation = 1.0;
    return mainLight;
}
#endif


#ifndef SHADERGRAPH_PREVIEW
float3 FresnelTerm(float3 specularColor, float vdoth)
{
    float3 fresnel = specularColor + (1. - specularColor) * pow((1. - vdoth), 5.);
    return fresnel;
}

// Inline D_GGXAniso() * V_SmithJointGGXAniso() together for better code generation.
real DV_SmithJointGGXAnisoNoPI(real TdotH, real BdotH, real NdotH, real NdotV,
                           real TdotL, real BdotL, real NdotL,
                           real roughnessT, real roughnessB, real partLambdaV)
{
    real a2 = roughnessT * roughnessB;
    real3 v = real3(roughnessB * TdotH, roughnessT * BdotH, a2 * NdotH);
    real s = dot(v, v);

    real lambdaV = NdotL * partLambdaV;
    real lambdaL = NdotV * length(real3(roughnessT * TdotL, roughnessB * BdotL, NdotL));

    real2 D = real2(a2 * a2 * a2, s * s); // Fraction without the multiplier (1/Pi)
    real2 G = real2(1, lambdaV + lambdaL); // Fraction without the multiplier (1/2)

    // This function is only used for direct lighting.
    // If roughness is 0, the probability of hitting a punctual or directional light is also 0.
    // Therefore, we return 0. The most efficient way to do it is with a max().
    return (0.5) * (D.x * G.x) / max(D.y * G.y, REAL_MIN);
}


float3 EnvironmentReflection(float3 N, float3 T, float3 V, float roughness)
{
    float3 R = reflect(-V, N);
    float NoV = saturate(dot(N, V));
    float fresnel = Pow4(1 - NoV);
    float3 indirectSpecular = GlossyEnvironmentReflection(R, roughness, 1);
    return indirectSpecular;
}

float3 LWSafeNormalize(float3 inVec)
{
    float dp3 = max(0.001, dot(inVec, inVec));
    return inVec / sqrt(dp3); // no rsqrt
}

float3 LWABRDF(Light light, float3 normal, float3 tangent, float3 bitangent, float3 view, float3 baseColor, float3 specularColor, float perceptualRoughness, float roughness2, float roughness2MinusOne, float normalizationTerm, float anisotropy)
{
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
    float NdotL = saturate(dot(normal, light.direction));
    float NdotV = ClampNdotV(dot(normal, view));
    
    float LdotV, NdotH, LdotH, invLenLV;
    GetBSDFAngle(view, light.direction, NdotL, NdotV, LdotV, NdotH, LdotH, invLenLV);
    
    float3 H = LWSafeNormalize((light.direction + view));
  
    NdotH = saturate(dot(normal, H));
    LdotH = saturate(dot(light.direction, H));

    float diffTerm;
    float3 specTerm;

    // Use abs NdotL to evaluate diffuse term also for transmission
    // TODO: See with Evgenii about the clampedNdotV here. This is what we use before the refactor
    // but now maybe we want to revisit it for transmission
    diffTerm = DisneyDiffuseNoPI(NdotV, abs(NdotL), LdotV, perceptualRoughness);

    // Fabric are dieletric but we simulate forward scattering effect with colored specular (fuzz tint term)
    float3 F = FresnelTerm(specularColor, LdotH); //F_Schlick(specularColor, LdotH);
    
    if (anisotropy != 0 )//anisotropic material
    {   
    // For anisotropy we must not saturate these values
        float TdotH = dot(tangent, H);
        float TdotL = dot(tangent, light.direction);
        float BdotH = dot(bitangent, H);
        float BdotL = dot(bitangent, light.direction);

        float TdotV = dot(tangent, view);
        float BdotV = dot(bitangent, view);

        float roughnessB;
        float roughnessT;

    // TdotH = max(TdotH, 0.01);

        ConvertAnisotropyToClampRoughness(perceptualRoughness, anisotropy, roughnessT, roughnessB);

    // TODO: Do comparison between this correct version and the one from isotropic and see if there is any visual difference
    // We use abs(NdotL) to handle the none case of double sided
        float partLambdaV = GetSmithJointGGXAnisoPartLambdaV(TdotV, BdotV, NdotV, roughnessT, roughnessB);

    
        float DV = DV_SmithJointGGXAnisoNoPI(TdotH, BdotH, NdotH, NdotV, TdotL, BdotL, abs(NdotL),
                                    roughnessT, roughnessB, partLambdaV);

        specTerm = F * DV;

        return (diffTerm * baseColor + specTerm) * light.color * (NdotL * light.distanceAttenuation * light.shadowAttenuation);
    }
    else
    {
        float NoH = NdotH;
        half LoH = LdotH;

    // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
    // BRDFspec = (D * V * F) / 4.0
    // D = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2
    // V * F = 1.0 / ( LoH^2 * (roughness + 0.5) )
    // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
    // https://community.arm.com/events/1155

    // Final BRDFspec = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2 * (LoH^2 * (roughness + 0.5) * 4.0)
    // We further optimize a few light invariant terms
    // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
        float d = NoH * NoH * roughness2MinusOne + 1.00001f;

        half LoH2 = LoH * LoH;
        half sTerm = roughness2 / ((d * d) * max(0.1h, LoH2) * normalizationTerm);
        specTerm = float3(sTerm, sTerm, sTerm);
        return (baseColor + specTerm * specularColor) * light.color * (NdotL * light.distanceAttenuation * light.shadowAttenuation);
    }
}


float3 LWAGlobalIllumination(float3 diffuse, float3 specular, float roughness2, float grazingTerm, float perceptualRoughness,
    float anisotropy, float3 anisotropicT, float3 anisotropicB,
    float3 bakedGI, float occlusion,
    half3 normalWS, half3 viewDirectionWS, float3 positionWS)
{
    float3 reflectVector = reflect(-viewDirectionWS, normalWS);
    if (anisotropy != 0)
    {   
        float3 anisotropyDirection = anisotropy >= 0.0 ? anisotropicB : anisotropicT;
        float3 anisotropicTangent = cross(anisotropyDirection, viewDirectionWS);
        float3 anisotropicNormal = cross(anisotropicTangent, anisotropyDirection);
        float bendFactor = abs(anisotropy) * saturate(5.0 * perceptualRoughness);
        float3 bentNormal = normalize(lerp(normalWS, anisotropicNormal, bendFactor));

        reflectVector = reflect(-viewDirectionWS, bentNormal);
    }
    half NoV = saturate(dot(normalWS, viewDirectionWS));
    half fresnelTerm = Pow4(1.0 - NoV);
    half3 indirectDiffuse = bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, perceptualRoughness, occlusion);

    half3 color = indirectDiffuse * diffuse;
    float surfaceReduction = 1.0 / (roughness2 + 1.0);
    color += indirectSpecular * surfaceReduction * lerp(specular, grazingTerm, fresnelTerm);
    return color;
}

void CalcTangentToWorld_float(
float3 inDirTS,
float3 tangentWS,
float3 bitangentWS,
float3 normalWS,

out float3 outDir
)
{
    outDir = TransformTangentToWorld(inDirTS, half3x3(tangentWS.xyz, bitangentWS, normalWS.xyz));
}


void LitWithAnisotropy_float(
    float3 baseColor,
    float metallic,
    float smoothness,
    float3 emission,
    float ambientOcclusion,
    //float3 anisotropyDirection,//Use tangent
    float anisotropy,//-1,1

    float3 normal,
    float3 tangent,
    float3 bakedGI,
    float3 position,
    float3 view,

    out float3 outColor
)
{
    outColor = float3(0, 0, 0);

    half oneMinusReflectivity = OneMinusReflectivityMetallic(metallic);
    half reflectivity = 1.0 - oneMinusReflectivity;
    half3 diffuseColor = baseColor * oneMinusReflectivity;
    half3 specularColor = lerp(kDielectricSpec.rgb, baseColor, metallic);

    float perceptualRoughness = max(PerceptualSmoothnessToPerceptualRoughness(smoothness), HALF_MIN);
    float roughness = max(PerceptualRoughnessToRoughness(perceptualRoughness), HALF_MIN_SQRT);
    float roughness2 = max(roughness * roughness, HALF_MIN);
    float roughness2MinusOne = roughness2 - 1.0h;
    float normalizationTerm = roughness * 4.0h + 2.0h;
    float grazingTerm = saturate(smoothness + reflectivity);

    float3 anisotropicT = float3(1, 0, 0);
    float3 anisotropicB = normalize(cross(normal, anisotropicT));
    if(anisotropy != 0)
    {
        anisotropicT = normalize(tangent);
        anisotropicB = normalize(cross(normal, anisotropicT));
        anisotropicT = normalize(cross(anisotropicB, normal));
    }

    float remapAnistrophy = anisotropy;// * 2 - 1;
    Light mainLight = GetMainLight_UnlitSG(position);
    outColor += LWAGlobalIllumination(diffuseColor, specularColor, roughness2, grazingTerm, perceptualRoughness,
        remapAnistrophy, anisotropicT, anisotropicB,
        bakedGI, ambientOcclusion,
        normal, view, position);
    outColor += LWABRDF(mainLight, normal, anisotropicT, anisotropicB, view, diffuseColor, specularColor.rgb, perceptualRoughness, roughness2, roughness2MinusOne, normalizationTerm, remapAnistrophy);
    
#ifdef ACESG_ADDITIONAL_LIGHTS
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
        {
            Light light = GetAdditionalLight(lightIndex, position, 1);
            outColor += LWABRDF(light, normal, anisotropicT, anisotropicB, view, baseColor.rgb, specularColor.rgb, perceptualRoughness, roughness2, roughness2MinusOne, normalizationTerm, remapAnistrophy);
        }
#endif 
    outColor += emission;

}

#else
	
void LitWithAnistropy_float(
    float3 baseColor,
    float metallic,
    float smoothness,
    float3 emission,
    float ambientOcclusion,
    //float3 anisotropyDirection,//Use tangent
    float anisotropy,

    float3 bakedGI,
    float3 normal,
    float3 tangent,
    float3 position,
    float3 view,

    out float3 outColor
)
{
    outColor = baseColor.rgb;
}
#endif // SHADERGRAPH_PREVIEW

#endif