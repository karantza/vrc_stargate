// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unlit/Bubble"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _FoamTex ("Foam RGBA", 2D) = "white" {}
        _NormTex ("Foam Normal", 2D) = "bump" {}
        _BubTex ("Bubble RGBA", 2D) = "white" {}
        _BubNormTex ("Bubble Normal", 2D) = "bump" {}
        _Glow ("Glow", Range(0,3)) = 0
        _Transition ("Transistion override", Range(0,1)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off


        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 uv : TEXCOORD0;
            };

            struct v2f
            {
                float3 uv : TEXCOORD0;
                float3 pos : TEXCOORD1;
                float3 view : TEXCOORD2;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;

            };

            sampler2D _FoamTex;
            sampler2D _NormTex;
            sampler2D _BubTex;
            sampler2D _BubNormTex;
            float4 _FoamTex_ST;
            float4 _Color;
            
            float _Glow;
            float _Transition;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.pos = v.vertex;
                o.uv = float3(TRANSFORM_TEX(v.uv.xy, _FoamTex), v.uv.z);
                o.view = normalize(ObjSpaceViewDir(v.vertex));

                UNITY_TRANSFER_FOG(o,o.vertex);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float foam = clamp(i.uv.z + _Transition,0,1);
                // sample the texture
                fixed4 col = lerp(tex2D(_BubTex, i.uv.xy),tex2D(_FoamTex, i.uv.xy),foam);
                
                float3 norm = normalize(lerp(UnpackNormal(tex2D(_BubNormTex, i.uv.xy)), UnpackNormal(tex2D(_NormTex, i.uv.xy)), pow(foam,4)));

                // Calculate the actual up direction
                float2 duv = normalize(ddy(i.uv.xy));
                float r = atan2(duv.y, duv.x);
                float2 wnorm = float2( norm.x * sin(r) + norm.y * cos(r), -(norm.x * cos(r) - norm.y * sin(r)));
                
                float lighting = clamp((dot(float2(0,1), wnorm)+1)  + clamp(i.pos.y - 0.3,0.5,2),0,1.5);
                
                float fresnel = pow(1-norm.z,0.7)*2;


                // sample the default reflection cubemap, using the reflection vector
                half4 skyData = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, reflect(-i.view, float3(wnorm, 1-length(wnorm))));
                half3 skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR);

                float3 foamCol = (skyColor * (1 +_Color/2) ) * lighting ;

                float3 bubbleCol = lerp(_Color,skyColor, fresnel);
                // col=float4(bubbleCol,col.r/2);
                col = float4(lerp(bubbleCol, foamCol, foam) * (_Glow+1), col.r/2);

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
