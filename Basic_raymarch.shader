Shader "basic_raymarch"
{
    Properties
    {
        _trans_x("transx", Range(0.0, 1000.0)) = 0
        _trans_y("transy", Range(0.0, 1000.0)) = 0
        _trans_z("transz", Range(0.0, 1000.0)) = 0
        _k("k", Range(0.0, 10.0)) = 1.8
        _sbunbo("sbunbo", Range(0.0, 10.0)) = 3.0
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque"  "LightMode" = "ForwardBase" }
        LOD 100
        Cull Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            float _Radius;
            float _trans_x;
            float _trans_y;
            float _trans_z;
            float _rotate_x;
            float _rotate_y;
            float _rotate_z;
            float _r;
            float _g;
            float _b;

            float2 rot(float2 p,float r) {//回転のための関数
                float2x2 m = float2x2(cos(r),sin(r),-sin(r),cos(r));
                return mul(p, m);
            }
            
            float cube4(float3 p, float s) {
                float3 m = float3(s,s,s) - abs(p);
                return min(min(-min(m.x, m.y), -min(m.z,m.y)),-min(m.x,m.z));
            }
            float _k;
            float _sbunbo;
            float menger(float3 p) {
                float d0 =0;
                float k = _k;
                float s = 1.0 / _sbunbo;
                for (int i = 0; i < 6; i++) {
                    d0 = max(d0,-cube4(abs(fmod(p - (k / 2.), k)) - 0.5 * k, s)),k /= 3.,s /= 3.;
                }
                return d0;
            }
            
            float2 pmod(float2 p,float n) {
                float np = 3.141592 * 2. / n;
                float r = atan2(p.x,p.y) - 0.5 * np;
                r = abs(fmod(r,np)) - 0.5 * np;
                return length(p) * float2(cos(r),sin(r));
            }


            float dist(float3 p) {//最終的な距離関数
                
                float3 trans = float3(_trans_x, _trans_y, _trans_z);
                
                float momo = 4.0;
                p *= momo;
                p.y -= 0.2;
                p.xy = pmod(p.xy,8.0);
                p.x -= -0.1;
                return  menger(p-trans)/momo;
            }

            float3 getnormal(float3 p)//法線を導出する関数
            {
                float d = 0.0001;
                return normalize(float3(
                dist(p + float3(d, 0.0, 0.0)) - dist(p + float3(-d, 0.0, 0.0)),
                dist(p + float3(0.0, d, 0.0)) - dist(p + float3(0.0, -d, 0.0)),
                dist(p + float3(0.0, 0.0, d)) - dist(p + float3(0.0, 0.0, -d))
                ));
            }



            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 pos : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            struct pout
            {
                fixed4 color : SV_Target;
                float depth : SV_Depth;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.pos = v.vertex.xyz;//メッシュのローカル座標を代入
                o.uv = v.uv;
                return o;
            }


            pout frag(v2f i)
            {
                //以下、ローカル座標
                float3 ro = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1)).xyz;//レイのスタート位置をカメラのローカル座標とする
                float3 rd = normalize(i.pos.xyz - ro);//メッシュのローカル座標の、視点のローカル座標からの方向を求めることでレイの方向を定義

                float d = 0;
                float t = 0;
                float accuracy = 0.00001;
                float t_max = 0.7;
                float MAX_ITERATIONS = 70;
                float3 p = float3(0, 0, 0);
                for (int i = 0; i < MAX_ITERATIONS; ++i) { //レイマーチングのループを実行
                    p = ro + rd * t;
                    d = dist(p);
                    t += d;
                    if (t>t_max)break;//レイが遠くに行き過ぎたか衝突した場合ループを終える
                }
                p = ro + rd * t;
                fixed4 col = float4(0,0,0,1);
                if (t >= t_max) { //レイが衝突していないと判断すれば描画しない
                    discard;
                }
                else {
                    float3 normal = getnormal(p);
                    float3 lightdir = normalize(mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz);//ローカル座標で計算しているので、ディレクショナルライトの角度もローカル座標にする
                    float NdotL = max(0, dot(normal, lightdir));//ランバート反射を計算
                    col = float4(float3(1, 1, 1) * NdotL, 1);//描画
                }

                pout o;
                o.color = col;
                float4 projectionPos = UnityObjectToClipPos(float4(p, 1.0));
                o.depth = projectionPos.z / projectionPos.w;
                return o;

            }
            ENDCG
        }

    }
}