            float getRimLight(v2f i)
            {
                float3 worViewDir = normalize(float3(_WorldSpaceCameraPos-i.worPos));
                float NdotV =  step(0.1,dot(i.worNormal,worViewDir));
                Light mainLight = GetMainLight();
                float3 worLightDir = mainLight.direction;
                float NdotL = saturate(dot(i.worNormal,worLightDir));
                float rimIntensity = (1.0-NdotV)*NdotL;
                float rim = smoothstep(0.7-_rimSize,0.7+_rimSize,rimIntensity);
                return rim;
            }
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worNormal = normalize(TransformObjectToWorldNormal(v.normal));
                o.worPos = mul(unity_ObjectToWorld,v.vertex).xyz;
                return o;
            }