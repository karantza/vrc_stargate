Shader "Unlit/TransitSpace"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RippleTex ("Ripple", 2D) = "white" {}
        _Color ("Distance Color", Color) = (1,1,1,1) 
        _Ripple( "Ripple mag", Range(0,1)) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _RippleTex;
            float4 _MainTex_ST;
            fixed4 _RippleTex_TextelSize;
            float4 _Color;
            float _Ripple;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Compute ripple normals
                float px = 0.01;//_RippleTex_TextelSize.x * 2;

                float3 norm = normalize(float3(
                tex2D(_RippleTex, i.uv + float2(px,0)).r - tex2D(_RippleTex, i.uv + float2(-px,0)).r,
                tex2D(_RippleTex, i.uv + float2(0,px)).r - tex2D(_RippleTex, i.uv + float2(0,-px)).r,
                .1
                ));

                // sample the texture
                float value = tex2D(_MainTex, i.uv).r;

                fixed4 col = lerp(_Color,tex2D(_MainTex, i.uv + norm.xy * _Ripple * value), pow(value,.5));

                return col;
            }
            ENDCG
        }
    }
}
