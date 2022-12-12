// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Stargate/PoolAppearance"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        
        _MainTex ("Displacement Texture", 2D) = "white" {}
        _NormRange ("Normal Range", Range(0, 3)) = 1
        _NormStr ("Normal Strength", Range(0, 10)) = 1
        _Displacement ("Displacement", Range(0, 10)) = 1
        _Shininess ("Shininess", Range(0,10)) = 1
        _IOR ("Index of Refraction", Range(0,5)) = 1.333
        _Refract ("Refraction Amount", Range(0,0.1)) = 0.01
        _NoiseTex ("Noise Tex", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        GrabPass
        {
            "_BackgroundTexture"
        }
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
                float3 view: TEXCOORD2;
                float4 grabPos: TEXCOORD3;
            };

            sampler2D _MainTex;
            sampler2D _NoiseTex;
            sampler2D _BackgroundTexture;
            float4 _Color;
            float4 _MainTex_ST;
            fixed4 _MainTex_TexelSize;

            float _NormRange;
            float _NormStr;
            float _Displacement;
            float _Shininess;
            float _IOR;
            float _Refract;

            float3 hsv_to_rgb(float3 HSV)
            {
                float3 RGB = HSV.z;
                
                float var_h = HSV.x * 6;
                float var_i = floor(var_h);
                float var_1 = HSV.z * (1.0 - HSV.y);
                float var_2 = HSV.z * (1.0 - HSV.y * (var_h-var_i));
                float var_3 = HSV.z * (1.0 - HSV.y * (1-(var_h-var_i)));
                if      (var_i == 0) { RGB = float3(HSV.z, var_3, var_1); }
                else if (var_i == 1) { RGB = float3(var_2, HSV.z, var_1); }
                else if (var_i == 2) { RGB = float3(var_1, HSV.z, var_3); }
                else if (var_i == 3) { RGB = float3(var_1, var_2, HSV.z); }
                else if (var_i == 4) { RGB = float3(var_3, var_1, HSV.z); }
                else                 { RGB = float3(HSV.z, var_1, var_2); }
                
                return (RGB);
            }

            float getNoise(float2 uv, float h) {
                float3 noise_full = (tex2Dlod(_NoiseTex, float4(uv,0,0)/3).rgb + tex2Dlod(_NoiseTex, float4(uv,0,0)).rgb) / 2;
                float noise = (dot(noise_full, hsv_to_rgb(float3(h, 0.5, 0.5))));
                return noise;
            }

            v2f vert (appdata v)
            {
                v2f o;
                float h = tex2Dlod(_MainTex, float4(v.uv.xy,0,0)).r;

                float4 opos = v.vertex + float4(0,0,atan(h) * 0.0002 * _Displacement,0);

                o.vertex = UnityObjectToClipPos(opos);

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);

                o.view = normalize(WorldSpaceViewDir(opos));

                o.grabPos = ComputeGrabScreenPos(o.vertex);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture for surface height
                float px = _MainTex_TexelSize.x * _NormRange;

                float3 norm = float3(
                tex2D(_MainTex, i.uv + float2(px,0)).r - tex2D(_MainTex, i.uv + float2(-px,0)).r,
                tex2D(_MainTex, i.uv + float2(0,px)).r - tex2D(_MainTex, i.uv + float2(0,-px)).r,
                0
                );

                norm *= _NormStr;
                norm.z = 1 - sqrt(norm.x*norm.x + norm.y*norm.y);

                norm = normalize(mul( unity_ObjectToWorld, float4( norm, 0.0 ) ).xyz); // Convert to world space


                float3 refl = normalize(reflect(-i.view, norm));
                // return float4(refl,1);
                float3 refr = normalize(refract(i.view, norm, 1/_IOR));

                fixed4 col_refl = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, refl);
                fixed4 col_refr = tex2Dproj(_BackgroundTexture, i.grabPos + float4(refr * _Refract, 0) );

                col_refr = lerp(col_refr, _Color, _Color.a);

                float fresnel = pow(max(dot(-i.view, refl), 0.0), _Shininess);

                fixed4 col = lerp(col_refr, col_refl, fresnel);
                
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);

                return float4(col.rgb, 1);
            }
            ENDCG
        }
    }
}
