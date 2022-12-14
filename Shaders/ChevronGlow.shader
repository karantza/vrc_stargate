Shader "Custom/ChevronGlow"
{
    Properties
    {
        _Color ("Off Color", Color) = (1,1,1,1)
        _GlowTex ("Glow (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _Lit ("Lit", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _GlowTex;

        struct Input
        {
            float2 uv_GlowTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
        float _Lit;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
            fixed4 emit = tex2D (_GlowTex, IN.uv_GlowTex);
            o.Albedo = _Color.rgb * emit;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = 1;
            o.Emission = emit * _Lit;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
