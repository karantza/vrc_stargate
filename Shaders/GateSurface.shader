Shader "Unlit/GateSurface"
{
    Properties
    {
        // _Color ("Color", Color) = (1,1,1,1)
        _A("Gradient", Range(0,0.5)) = 0.1
        _Damp("Damping", Range(0.9,1)) = 0.99
        _noiseMag("Noise Mag", Range(0,.1)) = 0.01
        _impactMag("Impact Mag", Range(0,1)) = 0.2
        
        _DepthTex ("Depth Texture", 2D) = "white" {}
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _BoundsTex ("Boundary", 2D) = "white" {}
    }

    SubShader
    {
        Lighting Off
        Blend One Zero

        Pass
        {
            CGPROGRAM
            #include "UnityCustomRenderTexture.cginc"
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 3.0

            sampler2D   _NoiseTex;
            float4 _NoiseTex_ST;

            UNITY_DECLARE_DEPTH_TEXTURE( _DepthTex );


            sampler2D   _BoundsTex;
            float _A;
            float _Damp;
            float _noiseMag;
            float _impactMag;

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

            float4 frag(v2f_customrendertexture IN) : COLOR
            {

                float2 uv = IN.globalTexcoord.xy;
                float3 prev = tex2D(_SelfTexture2D, uv).rgb;

                // Get the depth from things around the plane
                
                float d = ( SAMPLE_DEPTH_TEXTURE( _DepthTex, uv) );

                float px = 1.0 / _CustomRenderTextureWidth;


                // calculate the new displacement
                float z = _A * (
                tex2D(_SelfTexture2D, uv + float2(px,0)).x +
                tex2D(_SelfTexture2D, uv - float2(px,0)).x +
                tex2D(_SelfTexture2D, uv + float2(0,px)).x +
                tex2D(_SelfTexture2D, uv - float2(0,px)).x) +
                (2.0 - 4.0 * _A) * prev.r -
                (prev.g);


                // we want to add a bit of noise to keep the ripples going.
                // Read it from a texture, cycling through RGB over time to
                // get changing patterns.
                float2 noiseUv = TRANSFORM_TEX(IN.globalTexcoord, _NoiseTex);
                float3 noise_full = tex2D(_NoiseTex, noiseUv + float2(_Time.r,0)).rgb;
                float noise = (dot(noise_full, hsv_to_rgb(float3(_Time.g, 1, 1))) - 0.5) * sin(_Time.g*10);

                // We clamp the displacement to the user-specified bounds, so we don't
                // get ripples due to the square boundary conditions when we usually
                // have a circular stargate.

                float boundary = tex2D(_BoundsTex, uv).r;

                return float4((z * _Damp + d * -_impactMag + noise * _noiseMag) * boundary, prev.r,prev.g,1);
            }
            ENDCG
        }
    }
}
