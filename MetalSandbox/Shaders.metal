//
//  Shaders.metal
//  MetalSandbox
//
//  Created by Hina on 2018/08/05.
//  Copyright © 2018 Hina. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#define lightDirection float3(1, -4, -5)

// Basic Struct to match our Swift type
// This is what is passed into the Vertex Shader
struct VertexIn {
    float3      position    [[ attribute(0) ]];
    float3      normal      [[ attribute(1) ]];
    float2      texcoord    [[ attribute(2) ]];
};
// What is returned by the Vertex Shader
// This is what is passed into the Fragment Shader
struct VertexOut {
    float4      position    [[ position ]];
    float4      worldPosition;
    float3      normal;
    float2      texcoord;
    float4      color;
};

struct GBufferVertexUniforms {
    float4x4 viewProjectionMatrix;
    float4x4 modelMatrix;
    float3x3 normalMatrix;
};

struct GBufferOut {
    float4 albedo [[color(0)]];
    float4 normal [[color(1)]];
    float4 position  [[color(2)]];
    float4 depth [[color(3)]];
    float4 id [[color(4)]];
    float4 bw [[color(5)]];
};

struct VertexUniforms {
    float4x4 viewProjectionMatrix;
    float4x4 modelMatrix;
    float3x3 normalMatrix;
};

struct PanelVertexIn {
    float3      position    [[ attribute(0) ]];
    float4      color       [[ attribute(1) ]];
    float2      texcoord       [[ attribute(2) ]];
};

vertex VertexOut gBufferVert //(const device VertexIn *vertices[[buffer(0)]],
//                             const device VertexUniforms &uniforms [[buffer(1)]],
//                             unsigned int vid [[vertex_id]]) {
    (VertexIn vin [[ stage_in ]],
     constant GBufferVertexUniforms& uniforms [[ buffer(1) ]]) {

    VertexOut out;
//    VertexIn vin = vertices[vid];

//    float4 inPosition = float4(vin.position, 1.0);
//    out.position = uniforms.viewProjectionMatrix * inPosition;
//    float3 normal = vin.normal;
//    float3 eyeNormal = normalize(uniforms.normalMatrix * normal);
//
//    out.normal = eyeNormal;
//    out.texcoord = vin.texcoord;
//    out.worldPosition = uniforms.modelMatrix * inPosition;
//
//    return out;
    
    float4 worldPosition =  uniforms.modelMatrix * float4(vin.position, 1.0);
    out.worldPosition = worldPosition;
    out.position = uniforms.viewProjectionMatrix * worldPosition;
    out.normal = uniforms.normalMatrix * vin.normal;
    out.texcoord = vin.texcoord;
    return out;
}

fragment GBufferOut gBufferFrag(VertexOut in[[stage_in]], texture2d<float> albedo_texture [[texture(0)]]) {
    constexpr sampler linear_sampler(min_filter::linear, mag_filter::linear);
//    float4 albedo = albedo_texture.sample(linear_sampler, in.texcoord);
    GBufferOut output;
    
    output.albedo = float4(0.0, 0.0, 0.0, 1.0);
    output.normal = float4(in.normal, 1.0);
//    output.normal = float4(1.0, 1.0, 0.0, 1.0);
    output.position = in.worldPosition;
    
    //    bunny
    float dmax = 0.8;
    float dmin = 0.3;
    float depth = (in.position.z / in.position.w + 1.0) * 0.5;
    depth = max(min(depth, dmax), dmin);
    depth = (depth-dmin)/(dmax-dmin);
    output.depth = float4(float3(depth), 1.0);
    output.id = float4(0.64, 0.64, 0.63, 1.0);
    output.bw = float4(1.0, 1.0, 1.0, 1.0);
    
    return output;
}

vertex VertexOut lambertVertex(VertexIn vIn [[ stage_in ]],constant VertexUniforms& uniforms [[ buffer(1) ]]) {
    
    VertexOut vOut;
    float4 worldPosition = uniforms.modelMatrix * float4(vIn.position, 1);
    vOut.position = uniforms.viewProjectionMatrix * worldPosition;
    vOut.worldPosition = worldPosition;
    vOut.normal = uniforms.normalMatrix * vIn.normal;
    vOut.texcoord = float2(vIn.texcoord.xy);
    return vOut;

}

fragment float4 lambertFragment(VertexOut vIn [[ stage_in ]], texture2d<float> texture [[ texture(0) ]]) {
    //    float diffuseFactor = saturate(dot(vIn.normal, -lightDirection));
//    constexpr sampler colorSampler(address::repeat);
    constexpr sampler linear_sampler(min_filter::linear, mag_filter::linear);
    float4 color = texture.sample(linear_sampler, vIn.texcoord);
//    float gray = color.x * 0.29 + color.y * 0.58 + color.z * 0.11;
//    color = float4(gray, gray, gray, 1.0);
    
    return color;
}

vertex VertexOut basic_vertex_function(const device PanelVertexIn *vertices [[ buffer(0) ]],
                                       uint vertexID [[ vertex_id ]]) {
    VertexOut vOut;
    vOut.position = float4(vertices[vertexID].position, 1);
    vOut.color = vertices[vertexID].color;
    vOut.texcoord = vertices[vertexID].texcoord;
    return vOut;
}

fragment float4 basic_fragment_function(VertexOut vIn [[ stage_in ]],
                                        texture2d<float> inTexture [[ texture(0) ]],
                                        texture2d<float> idTexture [[ texture(1) ]],
                                        texture2d<float> nijimiTexture [[ texture(2) ]],
                                        texture2d<float> bwTexture [[ texture(3) ]]
                                        /*, constant TimeUnifrom &time [[buffer(0)]]*/) {
//    constexpr sampler colorSampler(address::repeat);
//    float4 color = texture.sample(linear_sampler, vIn.texcoord);
    float intensity = 0.4;
    constexpr sampler linear_sampler(min_filter::linear, mag_filter::linear);
    float4 incolor = inTexture.sample(linear_sampler, vIn.texcoord);
    float4 idcolor = idTexture.sample(linear_sampler, vIn.texcoord);
    float4 nijimicolor = nijimiTexture.sample(linear_sampler, vIn.texcoord);
    float4 bwcolor = bwTexture.sample(linear_sampler, vIn.texcoord);
    float4 resultColor = incolor;
    
//    if (bwcolor.r == 1.0 && incolor.r == 1.0) {
//        resultColor = float4(incolor.rgb, 1.0);
//    } else {
//        resultColor = float4(idcolor.rgb, 1.0);
//    }
    
    if (bwcolor.r == 1.0) {
        resultColor = intensity * nijimicolor + (1.0 - intensity) * resultColor;
    }

    return float4(resultColor.rgb, incolor.a);
//    return incolor;
}

kernel void kernel_laplacian_func(texture2d<half, access::read> inDepthTexture [[ texture(0) ]],
                                  texture2d<half, access::read> inNormalTexture [[ texture(1) ]],
                                  texture2d<half, access::read> inIdTexture [[ texture(2) ]],
                                  texture2d<half, access::write> outTexture [[ texture(3) ]],
                                  uint2 gid [[thread_position_in_grid]]) {
    
    matrix<half, 3, 3> weights;
    constexpr int size = 3;
    constexpr int radius = size / 2;
    weights[0][0] = 1;
    weights[0][1] = 1;
    weights[0][2] = 1;
    weights[1][0] = 1;
    weights[1][1] = -8;
    weights[1][2] = 1;
    weights[2][0] = 1;
    weights[2][1] = 1;
    weights[2][2] = 1;

    half4 accumDepthColor(0, 0, 0, 0);
    half4 accumNormalColor(0, 0, 0, 0);
    half4 accumIdColor(0, 0, 0, 0);
    for (int j = 0; j < size; ++j)
    {
        for (int i = 0; i < size; ++i)
        {
            uint2 textureIndex(gid.x + (i - radius), gid.y + (j - radius));
            half4 depth = inDepthTexture.read(textureIndex).rgba;
            half4 normal = inNormalTexture.read(textureIndex).rgba;
            half4 id = inIdTexture.read(textureIndex).rgba;
            half weight = weights[i][j];
            accumDepthColor += weight * depth;
            accumNormalColor += weight * normal;
            accumIdColor += weight * id;
        }
    }

    half depthValue = dot(accumDepthColor.rgb, half3(0.299, 0.587, 0.114));
    half normalValue = dot(accumNormalColor.rgb, half3(0.299, 0.587, 0.114));
    half idValue = dot(accumIdColor.rgb, half3(0.299, 0.587, 0.114));
    half silCreValue = depthValue/2 + normalValue/2;
    if (silCreValue < 0.0) silCreValue = 0.0;
    if (silCreValue > 1.0) silCreValue = 1.0;
    half creValue = silCreValue*2 - idValue*2;
    if (creValue < 0.0) creValue = 0.0;
    if (creValue > 1.0) creValue = 0.0;
    
//    half4 depthColor(depthValue, depthValue, depthValue, 1.0);
//    half4 normalColor(normalValue, normalValue, normalValue, 1.0);
//    half4 idColor(idValue, idValue, idValue, 1.0);
//    half4 silCreColor(silCreValue, silCreValue, silCreValue, 1.0);
    half4 creColor(creValue, creValue, creValue, 1.0);
    
    half ave = (creColor.r + creColor.g + creColor.b)/3;
    if (ave > 0.5) {
        creColor = half4(1.0, 1.0, 1.0, 1.0);
    } else {
        creColor = half4(0.0, 0.0, 0.0, 1.0);
    }

    half4 resultColor = creColor;
    resultColor = inIdTexture.read(gid).rgba;
    if (creColor.r == 1.0) {
        resultColor = half4(creColor.rgb, 1.0);
    }

    outTexture.write(resultColor, gid);

//    half4 inColor = inTexture.read(gid);
//    outTexture.write(inColor, gid);
}

kernel void kernel_dilation_func(texture2d<half, access::read> inTexture [[ texture(0) ]],
                                  texture2d<half, access::write> outTexture [[ texture(1) ]],
                                  texture2d<half, access::read> inIdTexture [[ texture(2) ]],
                                  uint2 gid [[thread_position_in_grid]]) {
    constexpr int size = 3;
    constexpr int radius = size / 2;
    half4 color = inTexture.read(gid);
    
    for (int j = 0; j < size; ++j)
    {
        for (int i = 0; i < size; ++i)
        {
            uint2 textureIndex(gid.x + (i - radius), gid.y + (j - radius));
            half4 in = inTexture.read(textureIndex).rgba;
            if (in.r == 1.0) {
                color = half4(1.0, 1.0, 1.0, 1.0);
            }
        }
    }
    
    half4 resultColor = color;
    resultColor = inIdTexture.read(gid).rgba;
    if (color.r == 1.0) {
        resultColor = half4(color.rgb, 1.0);
    }

    outTexture.write(resultColor, gid);
}

kernel void kernel_erosion_func(texture2d<half, access::read> inTexture [[ texture(0) ]],
                                texture2d<half, access::write> outTexture [[ texture(1) ]],
                                texture2d<half, access::read> inIdTexture [[ texture(2) ]],
                                uint2 gid [[thread_position_in_grid]]) {
    constexpr int size = 3;
    constexpr int radius = size / 2;
    half4 color = inTexture.read(gid);

    for (int j = 0; j < size; ++j)
    {
        for (int i = 0; i < size; ++i)
        {
            uint2 textureIndex(gid.x + (i - radius), gid.y + (j - radius));
            half4 in = inTexture.read(textureIndex).rgba;
            if (in.r == 0.0) {
                color = half4(0.0, 0.0, 0.0, 1.0);
            }
        }
    }
    
    half4 resultColor = color;
    resultColor = inIdTexture.read(gid).rgba;
    if (color.r == 1.0) {
        resultColor = half4(color.rgb, 1.0);
    }
    
    outTexture.write(resultColor, gid);
}

