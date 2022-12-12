Shader "Unlit/LightCookieShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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
            // make fog work
            #pragma multi_compile_fog

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
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float radius = 1 - length(float2(0.5,0.5) - i.uv) * 2;
                
                if (radius <= 0.1) return float4(0,0,0,0);
                
                // sample the texture
                fixed4 col = sqrt(abs(tex2D(_MainTex, i.uv.yx)));

                float x = 1 - clamp(sqrt(abs(col.r)), 0, 1);

                return float4(x,x,x,x) * pow(radius,1);
            }
            ENDCG
        }
    }
}
