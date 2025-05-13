Shader "URP/transparent"
{
    Properties
    {
        _shadowRange("shadow Range", Range(0, 0.5)) = 0.1
        _shadowSmooth("shadow Smooth", Range(0, 0.1)) = 0.01
        _HAPow("HAPow",Range(0,5)) = 3
        _FresnelIntensity("FresnelIntensity",Range(0,2)) = 1
        _emission("emission",Range(0,3)) = 1
        _TransparentAmount("Transparent",Range(0,1)) = 0.7
        [space(30)]
        _baseColor("baseColor",Color) = (1,1,1,1)
        [NoScaleOffset]_MainTex ("Texture", 2D) = "white" {}
        [space(30)]
        [NoScaleOffset]_SDFTex("SDFTex",2D) = "white" {}
        [NoScaleOffset]_eyesMask("eyesMask",2D) = "white" {}
        [NoScaleOffset]_lightMap_Hair("lightMap Hair",2D) = "white" {}
        [space(30)]
        [NoScaleOffset]_lightMap_Cloth("lightMap Cloth",2D) = "white" {}
        [NoScaleOffset]_lightMap_Cloth_a("lightMap Cloth_a",2D) = "white" {}
        [NoScaleOffset]_HighLightMap_Cloth("HighLightMap_Cloth",2D) = "white" {}
        [space(30)]
        [NoScaleOffset]_lightMap_Coat("lightMap Coat",2D) = "white" {}
        [NoScaleOffset]_lightMap_Coat_a("lightMap Coat_a",2D) = "white" {}
        [NoScaleOffset]_HighLightMap_Coat("HighLightMap_Coat",2D) = "white" {}

        [NoScaleOffset]_RampMap("RampMap",2D) = "white" {}


        [space(30)]
        [Toggle(SHADOW_FACE_ON)] _isface("isface",Float) = 0.0
        [Toggle(SHADOW_HAIR_ON)] _ishair("ishair",Float) = 0.0
        [Toggle(SHADOW_CLOTH_ON)] _iscloth("iscloth",Float) = 0.0
        [Toggle(SHADOW_COAT_ON)] _iscoat("iscoat",Float) = 0.0
        [Toggle(BLINK_ON)] _isblink("_isblink",Float) = 0.0



    }
    SubShader
    {
        Pass
        {
            //该Pass为主体
            Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent"}
            Name "base"

            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma vertex vert
            #pragma fragment frag
            //下2行为设置阴影的宏
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            //设置不同部位的标识宏
            #pragma shader_feature_local_fragment SHADOW_FACE_ON
            #pragma shader_feature_local_fragment SHADOW_HAIR_ON
            #pragma shader_feature_local_fragment SHADOW_CLOTH_ON
            #pragma shader_feature_local_fragment SHADOW_COAT_ON
            #pragma shader_feature_local_fragment BLINK_ON

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worNormal : TEXCOORD0;
                float2 uv :TEXCOORD1;
                float3 worPos : TEXCOORD2;
            };

            float _shadowRange;
            float _shadowSmooth;
            float _HAPow;
            float _FresnelIntensity;
            float _emission;
            float _TransparentAmount;

            float4 _baseColor;

            TEXTURE2D(_MainTex);
            TEXTURE2D(_SDFTex);
            TEXTURE2D(_eyesMask);
            TEXTURE2D(_lightMap_Hair);
            TEXTURE2D(_lightMap_Cloth);
            TEXTURE2D(_lightMap_Cloth_a);
            TEXTURE2D(_lightMap_Coat);
            TEXTURE2D(_lightMap_Coat_a);
            TEXTURE2D(_RampMap);
            TEXTURE2D(_HighLightMap_Cloth);
            TEXTURE2D(_HighLightMap_Coat);

            SAMPLER(sampler_MainTex);
            SAMPLER(sampler_SDFTex);
            SAMPLER(sampler_eyesMask);
            SAMPLER(sampler_lightMap_Hair);
            SAMPLER(sampler_lightMap_Cloth);
            SAMPLER(sampler_lightMap_Cloth_a);
            SAMPLER(sampler_lightMap_Coat);
            SAMPLER(sampler_lightMap_Coat_a);
            SAMPLER(sampler_RampMap);
            SAMPLER(sampler_HighLightMap_Cloth);
            SAMPLER(sampler_HighLightMap_Coat);


            //获取脸部阴影
            float GetFaceShadow(v2f i, float3 lightDirWS)
            {
                float3 forwardDirWS = normalize(TransformObjectToWorldDir(float3(0.0,0.0,1.0)));
                float3 rightDirWS = normalize(TransformObjectToWorldDir(float3(1.0,0.0,0.0)));

                float2 faceShadowUV = float2(1 - i.uv.x, i.uv.y);
                float faceShadow_right = SAMPLE_TEXTURE2D(_SDFTex, sampler_SDFTex, i.uv).r;
                float faceShadow_left = SAMPLE_TEXTURE2D(_SDFTex, sampler_SDFTex, faceShadowUV).r;

                float FdotL = dot(forwardDirWS, lightDirWS);
                float RdotL = dot(rightDirWS, lightDirWS);

                // 通过RdotL决定用哪张阴影图,当主光角度大于180选择右侧阴影图。
                float shadowTex = RdotL > 0 ? faceShadow_right : faceShadow_left;

                // 阈值
                float faceShadowThreshold = RdotL > 0 ? (1 - acos(RdotL) / PI * 2) : (acos(RdotL) / PI * 2 - 1);

                float shadowBehind = step(-0.1, FdotL);
                float shadowFront = step(faceShadowThreshold, shadowTex);//阴影在这一步就初步完成了

                // 如果光线在背后，则全是阴影，如果光线在前面，则按光线位置来决定阴影
                float shadow = mul(shadowBehind, shadowFront);

                // 矫正眼部阴影
                float eyeShadowMask = SAMPLE_TEXTURE2D(_eyesMask, sampler_eyesMask, faceShadowUV).g;
                float eyeMask = step(0.5, eyeShadowMask);
                shadow = lerp(shadow, 1.0, eyeMask);

                return shadow;
            }
            //获取整体阴影
            float getShadow(v2f i,float3 worLightDir)
            {
                float NdotL = saturate(dot(i.worNormal, worLightDir));
                float shadow = smoothstep(_shadowRange, _shadowRange + _shadowSmooth, NdotL);
                #ifdef SHADOW_FACE_ON
                    shadow = GetFaceShadow(i,worLightDir);
                #endif

                return shadow;
            }
            float smoothAO(float AO)
            {
                float AO_smooth = smoothstep(-0.1,0.2,AO);
                return AO_smooth;
            }
            float getAO(v2f i,float3 lightDirWS)
            {
                float AO = 1;
                float2 uv_test = float2(i.uv.x,1-i.uv.y);
                float AO_hair = SAMPLE_TEXTURE2D(_lightMap_Hair,sampler_lightMap_Hair,i.uv).r;
                float AO_cloth = SAMPLE_TEXTURE2D(_lightMap_Cloth,sampler_lightMap_Cloth,uv_test).r;
                float AO_coat = SAMPLE_TEXTURE2D(_lightMap_Coat,sampler_lightMap_Coat,uv_test).r;

                AO_hair = smoothAO(AO_hair);
                AO_cloth = smoothAO(AO_cloth);
                AO_coat = smoothAO(AO_coat);


                #ifdef SHADOW_FACE_ON
                    AO = 1;
                #endif
                #ifdef SHADOW_HAIR_ON
                    AO = AO_hair;
                #endif
                #ifdef SHADOW_CLOTH_ON
                    AO = AO_cloth;
                #endif
                #ifdef SHADOW_COAT_ON
                    AO = AO_coat;
                #endif
                
                return AO;
            }
            float3 getRampCol(v2f i,float shadow)
            {
                float3 RampCol;
                //这里原shadow的值主要分布在01，shadow的值没有问题，但是使用shadow对Ramp采样时，首尾的颜色值相近，无法凸显阴影
                //故这里将颜色值缩小值至0.1~0.9，效果比较明显，主要目的是规避01shadow的端点值。
                shadow = (shadow*0.8)+0.1;
                float2 uv_test = float2(i.uv.x,1-i.uv.y);
                float cloth_a = SAMPLE_TEXTURE2D(_lightMap_Cloth_a,sampler_lightMap_Cloth_a,uv_test).r;
                float coat_a = SAMPLE_TEXTURE2D(_lightMap_Coat_a,sampler_lightMap_Coat_a,uv_test).r;

                float2 RampUV_cloth = float2(shadow,cloth_a*0.45);
                float2 RampUV_coat = float2(shadow,coat_a*0.45);

                RampCol = SAMPLE_TEXTURE2D(_RampMap,sampler_RampMap,float2(shadow,0.1)).rgb;
                
                #ifdef SHADOW_CLOTH_ON
                    RampCol = SAMPLE_TEXTURE2D(_RampMap,sampler_RampMap,RampUV_cloth).rgb;
                #endif
                #ifdef SHADOW_COAT_ON
                    RampCol = SAMPLE_TEXTURE2D(_RampMap,sampler_RampMap,RampUV_coat).rgb;
                #endif
                #ifdef SHADOW_FACE_ON
                    RampCol = SAMPLE_TEXTURE2D(_RampMap,sampler_RampMap,float2(shadow,0.9)).rgb;
                #endif

                return RampCol;
            }
            float3 getHighLight_Anisotropy(v2f i)
            {
                float2 uv_test = float2(i.uv.x,1-i.uv.y);
                float HA_hair = SAMPLE_TEXTURE2D(_lightMap_Hair,sampler_lightMap_Hair,i.uv).b;
                float HA_cloth = SAMPLE_TEXTURE2D(_lightMap_Cloth,sampler_lightMap_Cloth,uv_test).b;
                float HA_coat = SAMPLE_TEXTURE2D(_lightMap_Coat,sampler_lightMap_Coat,uv_test).b;
                float HA = 0;
                //得到高光系数控制部分材质高光反射
                float NdotV = saturate(dot(i.worNormal,float3(_WorldSpaceCameraPos.xyz-i.worPos.xyz)));
                float HA_fresnel = pow(1.0-NdotV,_HAPow)*_FresnelIntensity;
                float NdotL = saturate(dot(i.worNormal,GetMainLight().direction));
                float halfLambert = 0.5*NdotL+0.5;
                float HA_Amount = halfLambert*(1-HA_fresnel);
                #ifdef SHADOW_FACE_ON
                    HA = 0;
                #endif
                #ifdef SHADOW_HAIR_ON
                    HA = HA_hair;
                #endif
                #ifdef SHADOW_CLOTH_ON
                    HA = HA_cloth;
                #endif
                #ifdef SHADOW_COAT_ON
                    HA = HA_coat;
                #endif

                return HA*HA_Amount*_baseColor;
            }
            float3 getHighLight(v2f i)
            {
                float3 HL = float3(0,0,0);
                float3 HL_cloth = SAMPLE_TEXTURE2D(_HighLightMap_Cloth,sampler_HighLightMap_Cloth,i.uv).rgb;
                float3 HL_coat = SAMPLE_TEXTURE2D(_HighLightMap_Coat,sampler_HighLightMap_Coat,i.uv).rgb;
                #ifdef SHADOW_CLOTH_ON
                    HL = HL_cloth;
                #endif
                #ifdef SHADOW_COAT_ON
                    HL = HL_coat;
                #endif
                #ifdef BLINK_ON
                    float time = _CosTime.w*0.5+0.5;
                    HL = HL*lerp(0,_emission,time);
                #endif
                HL = HL*_emission;
                return HL;
            }
            float3 reflection(v2f i)
            {
                float3 F0 = float3(0.04,0.04,0.04);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worPos);

                // 获取光源方向
                float3 lightDir = normalize(GetMainLight().direction);

                // 计算半程向量 (Half Vector)
                float3 halfDir = normalize(viewDir + lightDir);

                // 计算法线与半程向量的点积
                float NdotH = saturate(dot(i.worNormal, halfDir));

                // Fresnel 效应 (可选)
                float fresnel = pow(1.0 - NdotH, 5.0);
                float3 col = F0+(1-F0)*fresnel;

                // 最终高光反射值
                return col;
            }
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worNormal = TransformObjectToWorldNormal(v.normal);
                o.worPos = mul(unity_ObjectToWorld,v.vertex).xyz;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 baseTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, i.uv);
                float3 lightDir = GetMainLight().direction;
                //下3行设置阴影~~但是感觉好像没起效果
                float4 SHADOW_COORDS = TransformWorldToShadowCoord(i.worPos);
                Light mainLight = GetMainLight(SHADOW_COORDS);
                half shadow = mainLight.shadowAttenuation;
                
                float s = getShadow(i,lightDir);
                float AO = getAO(i,lightDir);
                float3 RampCol = getRampCol(i,s);
                float3 HA = getHighLight_Anisotropy(i);
                float3 HLCol = getHighLight(i);
                float3 HL_refl = reflection(i);
                // float3 sd = _baseColor.rgb*s;
                float3 finalCol = baseTex.xyz*RampCol+(HLCol+HA+HL_refl);//H开头为高光部分                
                return float4(finalCol,_TransparentAmount);
            }
            ENDHLSL
        }
    }
}
