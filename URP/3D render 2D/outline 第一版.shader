Shader "URP/OutLine"
{
    Properties
    {
        _MainColor ("Main Color", Color) = (1,1,1,1)
        _OutLineCol ("OutLine Color",Color) = (0,0,0,1)
        _offset ("Offset",Float) = 0.2
    }
    
    SubShader
    {   
        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

             CBUFFER_START(UnityPerMaterial)
                half _offset;
            CBUFFER_END

            half4 _MainColor;
            half4 _OutLineCol;
        ENDHLSL

        Pass
        {
            Cull Back
            Tags
            { 
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;

            };



            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half4 col = _MainColor;
                return col;
            }
            ENDHLSL
        }
        Pass
        {
            Cull Front
            Tags
            { 
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;

            };

            v2f vert (appdata v)
            {
                v2f o;

                float3 normal = normalize(v.normal);
                float4 pos = float4(v.vertex.xyz+normal*_offset,1);
                o.vertex = TransformObjectToHClip(pos);

                o.uv = v.uv;
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half4 col = _OutLineCol;
                return col;
            }
            ENDHLSL
 
        }
    }
}