Shader "Stargate/GateAppear"
{
    Properties
    {
        _MainTex ("Displacement Texture", 2D) = "white" {}
        _NormRange ("Normal Range", Range(0, 3)) = 1
        _NormStr ("Normal Strength", Range(0, 10)) = 1
        _LightDist ("Light Distance", Range(0, 1)) = 1
        _Displacement ("Displacement", Range(0, 10)) = 1
        _LightTex ("Light Tex", 2D) = "white" {}

        _NoiseTex ("Noise Tex", 2D) = "white" {}
        _Color1 ("CenterColor", Color) = (1,1,1)
        _Color2 ("EdgeColor", Color) = (0.1,0.1,0.9)

        _Activation ("Activation", Range(0, 1)) = 1
        _Instability ("Instability", Range(0, 5)) = 0
        _Transparency ("Transparency", Range(0, 1)) = 1

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
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 viewT: TEXCOORD2;
            };

            sampler2D _MainTex;
            sampler2D _NoiseTex;
            float4 _MainTex_ST;
            fixed4 _MainTex_TexelSize;

            float _NormRange;
            float _NormStr;
            float _LightDist;
            float _Displacement;
            float _Activation;
            float _Transparency;
            float _Instability;
            sampler2D _LightTex;

            float3 _Color1;
            float3 _Color2;

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

                o.viewT = normalize(ObjSpaceViewDir(v.vertex));


                return o;
            }
            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture for gate surface height
                fixed h = tex2D(_MainTex, i.uv).r;

                float px = _MainTex_TexelSize.x * _NormRange;

                float3 norm = float3(
                tex2D(_MainTex, i.uv + float2(px,0)).r - tex2D(_MainTex, i.uv + float2(-px,0)).r,
                tex2D(_MainTex, i.uv + float2(0,px)).r - tex2D(_MainTex, i.uv + float2(0,-px)).r,
                0
                );
                norm *= _NormStr * (1-_Instability);
                norm.z = 1 - sqrt(norm.x*norm.x + norm.y*norm.y);

                // To get the stargate lighting effect, we imagine a point behind the surface,
                // and compare the normal to that.
                float2 lightuv = i.uv.xy + float2(1,-1) * reflect(i.viewT,  norm).xy * _LightDist;

                float light = tex2D(_LightTex, clamp(lightuv,0,1));

                float4 col = float4(
                light > 0.5 ? lerp(_Color1, float3(1,1,1), (light - 0.5)*2)
                : lerp(_Color2, _Color1, (light)*2), 1);


                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);


                // When the gate is turning on or off, we do this effect where it grows from the outside in,
                // and has a bright white glow as it does so. This is controlled by the _Activation param.
                float noise = getNoise(i.uv, 0);

                float clipActivation = length(i.uv.xy - 0.5) * 2 + noise - (1 - _Activation*2.1) - 1;
                
                col += float4(2,2,2,0) * (noise/2+.5) * _Instability;

                col.a = clamp(clipActivation * 10 ,0,_Transparency) * clamp(1-_Instability,0.9,_Transparency);
                if (clipActivation < 0) discard;

                return col;
            }
            ENDCG
        }
    }
}
